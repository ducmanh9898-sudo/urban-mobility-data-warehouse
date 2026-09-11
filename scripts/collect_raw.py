import gzip
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen
from uuid import uuid4


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def utc_now():
    return datetime.now(timezone.utc)


def download(url, timeout):
    request = Request(
        url,
        headers={
            "User-Agent": "urban-mobility-data-warehouse/0.1",
            "Accept": "application/json",
        },
    )

    with urlopen(request, timeout=timeout) as response:
        body = response.read()

    return body, utc_now().isoformat()


def main():
    config_path = PROJECT_ROOT / "config" / "source.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))

    started_at = utc_now()
    run_id = str(uuid4())

    output_dir = (
        PROJECT_ROOT
        / "data"
        / "raw"
        / started_at.strftime("%Y-%m-%d")
        / run_id
    )
    output_dir.mkdir(parents=True, exist_ok=False)

    print(f"Run ID: {run_id}", flush=True)
    print(f"Output directory: {output_dir}", flush=True)

    discovery_body, _ = download(
        config["discovery_url"],
        config["timeout_seconds"],
    )
    discovery = json.loads(discovery_body)

    if discovery.get("version") != config["expected_version"]:
        raise ValueError("Unexpected discovery feed version")

    feed_urls = {
        feed["name"]: feed["url"]
        for feed in discovery["data"][config["language"]]["feeds"]
    }

    manifest = {
        "run_id": run_id,
        "started_at": started_at.isoformat(),
        "discovery_url": config["discovery_url"],
        "feeds": [],
    }

    for feed_name in config["feeds"]:
        url = feed_urls[feed_name]
        body, collected_at = download(url, config["timeout_seconds"])

        filename = f"{feed_name}.json.gz"

        # Preserve the downloaded response before validating its structure.
        with gzip.open(output_dir / filename, "xb") as file:
            file.write(body)

        payload = json.loads(body)

        if payload.get("version") != config["expected_version"]:
            raise ValueError(f"Unexpected version in {feed_name}")

        stations = payload["data"]["stations"]
        if not isinstance(stations, list) or not stations:
            raise ValueError(f"Empty or invalid station list: {feed_name}")

        source_time = payload["last_updated"]
        if type(source_time) is not int or source_time <= 0:
            raise ValueError(f"Invalid last_updated: {feed_name}")

        manifest["feeds"].append({
            "name": feed_name,
            "url": url,
            "file": filename,
            "version": payload["version"],
            "collected_at": collected_at,
            "source_last_updated": source_time,
            "record_count": len(stations),
            "sha256": hashlib.sha256(body).hexdigest(),
        })

        print(f"Saved {feed_name}: {len(stations)} stations", flush=True)

    manifest["completed_at"] = utc_now().isoformat()
    manifest["status"] = "collected"

    temporary_path = output_dir / "manifest.json.tmp"
    temporary_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    temporary_path.replace(output_dir / "manifest.json")

    print("Collection completed.", flush=True)
    return output_dir / "manifest.json"


if __name__ == "__main__":
    main()