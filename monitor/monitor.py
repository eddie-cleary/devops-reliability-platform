import time
import requests
from database import initialize_database, save_check, get_recent_checks
import argparse
from datetime import datetime

def check_endpoint(url, latency_warning, latency_critical, timeout):
    start_time = time.perf_counter()

    try:
        response = requests.get(url, timeout=timeout)

        latency_ms = round(
            (time.perf_counter() - start_time) * 1000,
            2
        )

        if 200 <= response.status_code < 300:
            if latency_ms >= latency_critical:
                result = "UNHEALTHY"
            elif latency_ms >= latency_warning:
                result = "DEGRADED"
            else:
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

    parser.add_argument(
        "--latency-warning",
        type=int,
        default=1000,
        help="Warning latency threshold in milliseconds"
    )

    parser.add_argument(
        "--timeout",
        type=int,
        default=10,
        help="HTTP request timeout in seconds (default: 10)"
    )

    parser.add_argument(
        "--latency-critical",
        type=int,
        default=3000,
        help="Critical latency threshold in milliseconds"
    )

    return parser.parse_args()

def validate_arguments(args):
    if args.interval <= 0:
        raise ValueError("--interval must be greater than 0")

    if args.timeout <= 0:
        raise ValueError("--timeout must be greater than 0")

    if args.latency_warning < 0:
        raise ValueError("--latency-warning cannot be negative")

    if args.latency_critical <= args.latency_warning:
        raise ValueError(
            "--latency-critical must be greater than --latency-warning"
        )

def print_check_result(result):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print(f"\n[{timestamp}]")
    print(f"URL:     {result['url']}")
    print(f"Status:  {result['status_code']}")
    print(f"Latency: {result['latency_ms']} ms")
    print(f"Result:  {result['result']}")
    print(f"Failure: {result.get('failure_reason')}")

def print_recent_checks(checks):
    print("\nRecent checks:")

    for check in checks:
        timestamp, url, status_code, latency_ms, result, failure_reason = check

        print(
            f"{timestamp} | "
            f"{result:<8} | "
            f"status={status_code} | "
            f"latency={latency_ms} ms"
        )

if __name__ == "__main__":
    initialize_database()

    args = parse_arguments()
    validate_arguments(args)

    while True:
        result = check_endpoint(
            args.url,
            args.latency_warning,
            args.latency_critical,
            args.timeout
        )

        save_check(result)

        print_check_result(result)
        print_recent_checks(get_recent_checks(5))

        print(f"\nWaiting {args.interval} seconds...\n")
        time.sleep(args.interval)