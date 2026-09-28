import time
import requests
from database import initialize_database, save_check


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


if __name__ == "__main__":
    initialize_database()

    target = "http://127.0.0.1:8000/healthy"

    result = check_endpoint(target)

    save_check(result)

    print(result)