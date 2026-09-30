import sqlite3
from datetime import datetime

DB_FILE = "checks.db"


def initialize_database():
    connection = sqlite3.connect(DB_FILE)
    cursor = connection.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS checks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            url TEXT NOT NULL,
            status_code INTEGER,
            latency_ms REAL,
            result TEXT NOT NULL,
            failure_reason TEXT
        )
    """)

    connection.commit()
    connection.close()


def save_check(check_result):
    connection = sqlite3.connect(DB_FILE)
    cursor = connection.cursor()

    cursor.execute("""
        INSERT INTO checks (
            timestamp,
            url,
            status_code,
            latency_ms,
            result,
            failure_reason
        )
        VALUES (?, ?, ?, ?, ?, ?)
    """, (
        datetime.now().isoformat(),
        check_result["url"],
        check_result["status_code"],
        check_result["latency_ms"],
        check_result["result"],
        check_result.get("failure_reason")
    ))

    connection.commit()
    connection.close()

def get_recent_checks(limit=10):
    connection = sqlite3.connect(DB_FILE)
    cursor = connection.cursor()

    cursor.execute("""
        SELECT timestamp, url, status_code, latency_ms, result, failure_reason
        FROM checks
        ORDER BY id DESC
        LIMIT ?
    """, (limit,))

    rows = cursor.fetchall()

    connection.close()

    return rows