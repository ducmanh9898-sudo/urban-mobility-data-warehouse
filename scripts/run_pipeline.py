import argparse
import fcntl
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID

from collect_raw import main as collect_raw


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def log(message):
    timestamp = datetime.now(timezone.utc).isoformat()
    print(f"[{timestamp}] {message}", flush=True)


def run_stage(script_name, *arguments):
    log(f"Starting: {script_name}")

    subprocess.run(
        [
            sys.executable,
            "-u",
            str(PROJECT_ROOT / "scripts" / script_name),
            *arguments,
        ],
        cwd=PROJECT_ROOT,
        check=True,
    )

    log(f"Completed: {script_name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--manifest",
        type=Path,
        help="Replay an existing raw collection instead of calling the API",
    )
    args = parser.parse_args()

    log_directory = PROJECT_ROOT / "logs"
    log_directory.mkdir(parents=True, exist_ok=True)
    lock_path = log_directory / "pipeline.lock"

    with lock_path.open("a") as lock_file:
        try:
            fcntl.flock(
                lock_file.fileno(),
                fcntl.LOCK_EX | fcntl.LOCK_NB,
            )
        except BlockingIOError:
            log("SKIPPED: another pipeline execution holds the lock")
            return

        try:
            log("Pipeline started")

            if args.manifest is None:
                log("Collecting new raw data")
                manifest_path = collect_raw()

                if manifest_path is None:
                    raise RuntimeError(
                        "collect_raw.main() must return the manifest path"
                    )

                manifest_path = Path(manifest_path).resolve()
            else:
                manifest_path = args.manifest.expanduser().resolve()
                log("Replay mode: using existing raw data")

            log(f"Manifest: {manifest_path}")

            manifest = json.loads(
                manifest_path.read_text(encoding="utf-8")
            )

            if manifest.get("status") != "collected":
                raise ValueError("Raw collection is not complete")

            raw_run_id = str(UUID(manifest["run_id"]))
            log(f"Raw run ID: {raw_run_id}")

            run_stage(
                "load_staging.py",
                "--manifest",
                str(manifest_path),
            )

            run_stage(
                "load_dim_station.py",
                "--raw-run-id",
                raw_run_id,
            )

            run_stage(
                "load_fact_snapshot.py",
                "--raw-run-id",
                raw_run_id,
            )

            log(f"Pipeline completed successfully: {raw_run_id}")

        except Exception as error:
            log(f"Pipeline FAILED: {type(error).__name__}: {error}")
            raise

        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)


if __name__ == "__main__":
    main()