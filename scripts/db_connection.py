import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def connect_database():
    load_dotenv(PROJECT_ROOT / ".env")

    required = (
        "DB_HOST",
        "DB_PORT",
        "POSTGRES_DB",
        "POSTGRES_USER",
        "POSTGRES_PASSWORD",
    )
    missing = [name for name in required if not os.getenv(name)]
    if missing:
        raise ValueError(f"Missing configuration: {', '.join(missing)}")

    return psycopg.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ["DB_PORT"]),
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        connect_timeout=10,
        options="-c timezone=UTC",
        autocommit=True,
    )