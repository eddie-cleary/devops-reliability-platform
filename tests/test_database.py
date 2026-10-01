import tempfile
from pathlib import Path

from monitor import database


def test_save_and_read_check():
    with tempfile.TemporaryDirectory() as temp_dir:
        test_db = Path(temp_dir) / "test_checks.db"

        original_db = database.DB_FILE
        database.DB_FILE = test_db

        try:
            database.initialize_database()

            check_result = {
                "url": "http://example.com",
                "status_code": 200,
                "latency_ms": 125.5,
                "result": "HEALTHY",
                "failure_reason": None,
            }

            database.save_check(check_result)

            checks = database.get_recent_checks(5)

            assert len(checks) == 1

            timestamp, url, status_code, latency_ms, result, failure_reason = checks[0]

            assert url == "http://example.com"
            assert status_code == 200
            assert latency_ms == 125.5
            assert result == "HEALTHY"
            assert failure_reason is None

        finally:
            database.DB_FILE = original_db

def test_recent_checks_respects_limit_and_order():
    with tempfile.TemporaryDirectory() as temp_dir:
        test_db = Path(temp_dir) / "test_checks.db"

        original_db = database.DB_FILE
        database.DB_FILE = test_db

        try:
            database.initialize_database()

            for latency in [100, 200, 300]:
                database.save_check({
                    "url": "http://example.com",
                    "status_code": 200,
                    "latency_ms": latency,
                    "result": "HEALTHY",
                    "failure_reason": None,
                })

            checks = database.get_recent_checks(2)

            assert len(checks) == 2

            # Newest records should come first.
            assert checks[0][3] == 300
            assert checks[1][3] == 200

        finally:
            database.DB_FILE = original_db