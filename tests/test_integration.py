from fastapi.testclient import TestClient

from service.app import app

import threading
import time

import uvicorn

from monitor.monitor import check_endpoint


client = TestClient(app)


def test_demo_service_healthy_endpoint():
    response = client.get("/healthy")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_demo_service_error_endpoint():
    response = client.get("/error")

    assert response.status_code == 500
    assert response.json() == {"status": "error"}

def run_test_server(server):
    server.run()

def test_monitor_against_live_healthy_endpoint():
    config = uvicorn.Config(
        app,
        host="127.0.0.1",
        port=8001,
        log_level="error"
    )

    server = uvicorn.Server(config)

    server_thread = threading.Thread(
        target=run_test_server,
        args=(server,),
        daemon=True
    )

    server_thread.start()

    time.sleep(1)

    try:
        result = check_endpoint(
            "http://127.0.0.1:8001/healthy",
            latency_warning=1000,
            latency_critical=3000,
            timeout=5
        )

        assert result["status_code"] == 200
        assert result["result"] == "HEALTHY"

    finally:
        server.should_exit = True
        server_thread.join(timeout=5)

def test_monitor_against_live_error_endpoint():
    config = uvicorn.Config(
        app,
        host="127.0.0.1",
        port=8002,
        log_level="error"
    )

    server = uvicorn.Server(config)

    server_thread = threading.Thread(
        target=run_test_server,
        args=(server,),
        daemon=True
    )

    server_thread.start()

    time.sleep(1)

    try:
        result = check_endpoint(
            "http://127.0.0.1:8002/error",
            latency_warning=1000,
            latency_critical=3000,
            timeout=5
        )

        assert result["status_code"] == 500
        assert result["result"] == "UNHEALTHY"

    finally:
        server.should_exit = True
        server_thread.join(timeout=5)