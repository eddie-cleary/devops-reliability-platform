import time
import requests
from database import initialize_database, save_check, get_recent_checks
import argparse

def check_endpoint(url):
    start_time = time.perf_counter()

    try:
        response = requests.get(url, timeout=5)

        latency_ms = round(
            (time.perf_counter() - start_time) * 1000,
            2
        )

        if 200 <= response.status_code < 300:
            result = "HEALTHY"
        else:
            result = "UNHEALTHY"

        return {
            "url": url,
            "status_code": response.status_code,
            "latency_ms": latency_ms,
            "result": result,
            "failure_reason": None
        }

    except requests.exceptions.Timeout:
        return {
            "url": url,
            "status_code": None,
            "latency_ms": None,
            "result": "UNHEALTHY",
            "failure_reason": "Request timed out"
        }

    except requests.exceptions.RequestException as error:
        return {
            "url": url,
            "status_code": None,
            "latency_ms": None,
            "result": "UNHEALTHY",
            "failure_reason": str(error)
        }

def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Monitor an HTTP endpoint and record health checks"
    )

    parser.add_argument(
        "--url",
        required=True,
        help="URL to monitor"
    )

    parser.add_argument(
        "--interval",
        type=int,
        default=30,
        help="Seconds between checks (default: 30)"
    )

    return parser.parse_args()

if __name__ == "__main__":
    initialize_database()

    args = parse_arguments()

    while True:
        result = check_endpoint(args.url)
        save_check(result)

        print(result)

        print("\nRecent checks:")
        for check in get_recent_checks(5):
            print(check)

        print(f"\nWaiting {args.interval} seconds...\n")
        time.sleep(args.interval)