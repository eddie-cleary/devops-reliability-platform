from unittest.mock import Mock, patch
from monitor.monitor import check_endpoint
import requests

@patch("monitor.monitor.requests.get")
def test_healthy_response(mock_get):
    response = Mock()
    response.status_code = 200
    mock_get.return_value = response

    result = check_endpoint(
        "http://example.com",
        latency_warning=1000,
        latency_critical=3000,
        timeout=10
    )

    assert result["status_code"] == 200
    assert result["result"] == "HEALTHY"
    assert result["failure_reason"] is None


@patch("monitor.monitor.requests.get")
def test_error_response(mock_get):
    response = Mock()
    response.status_code = 500
    mock_get.return_value = response

    result = check_endpoint(
        "http://example.com",
        latency_warning=1000,
        latency_critical=3000,
        timeout=10
    )

    assert result["status_code"] == 500
    assert result["result"] == "UNHEALTHY"

@patch("monitor.monitor.time.perf_counter")
@patch("monitor.monitor.requests.get")
def test_degraded_response(mock_get, mock_perf_counter):
    response = Mock()
    response.status_code = 200
    mock_get.return_value = response

    mock_perf_counter.side_effect = [0, 2]

    result = check_endpoint(
        "http://example.com",
        latency_warning=1000,
        latency_critical=3000,
        timeout=10
    )

    assert result["status_code"] == 200
    assert result["latency_ms"] == 2000
    assert result["result"] == "DEGRADED"

@patch("monitor.monitor.requests.get")
def test_timeout_response(mock_get):
    mock_get.side_effect = requests.exceptions.Timeout

    result = check_endpoint(
        "http://example.com",
        latency_warning=1000,
        latency_critical=3000,
        timeout=10
    )

    assert result["status_code"] is None
    assert result["latency_ms"] is None
    assert result["result"] == "UNHEALTHY"
    assert result["failure_reason"] == "Request timed out"

@patch("monitor.monitor.time.perf_counter")
@patch("monitor.monitor.requests.get")
def test_critical_latency_response(mock_get, mock_perf_counter):
    response = Mock()
    response.status_code = 200
    mock_get.return_value = response

    mock_perf_counter.side_effect = [0, 4]

    result = check_endpoint(
        "http://example.com",
        latency_warning=1000,
        latency_critical=3000,
        timeout=10
    )

    assert result["status_code"] == 200
    assert result["latency_ms"] == 4000
    assert result["result"] == "UNHEALTHY"