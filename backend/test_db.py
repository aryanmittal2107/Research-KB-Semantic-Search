import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

try:
    with psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "research_kb"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
        connect_timeout=5,
    ) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT current_database(), current_user, version();")
            database, user, version = cur.fetchone()

            print("Database connection successful!")
            print(f"Database: {database}")
            print(f"User: {user}")
            print(f"PostgreSQL: {version.split(',')[0]}")

except Exception as exc:
    print(f"Database connection failed: {exc.__class__.__name__}: {exc}")
