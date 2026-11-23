# DevOps Reliability Platform

A small monitored web service deployed to AWS through a CI/CD pipeline. I'm building it to practice shipping, running, monitoring, and fixing a real service end to end.

**Status:** Work in progress. Automated deploys to AWS ECS work in dev, and a deliberately broken release rolls back on its own.

## Overview

The project has two parts:

- **Service:** a FastAPI app with endpoints that simulate healthy, failing, slow, and flaky behavior.
- **Monitor:** a Python script that checks the service's health endpoint on an interval and records the status and latency of each check.

Both run as separate containers in one ECS task on an EC2 instance. The infrastructure is defined in Terraform. An ALB is the public entry point, forwarding requests to the service task and health-checking /healthy.

## Pipeline

- **Pull request into `main`:** runs Python tests and checks Terraform formatting and configuration validity for both runtime and bootstrap.
- **Merge to `main`:** runs tests, builds and pushes SHA-tagged images to ECR, then deploys to the `dev` environment. The deploy job registers a new ECS task definition with the new images, updates the service, and waits for it to stabilize.
- **Automatic rollback:** the ECS service has the deployment circuit breaker enabled. If new tasks keep failing, ECS rolls back to the last good revision.
- GitHub Actions authenticates to AWS with OIDC, so no long-lived access keys are stored.
- `main` is protected: changes require a pull request and a passing `tests` check.
- **Smoke Test:** after a successful deploy, the `smoke-test` job looks up the ALB's address, requests /healthy from the GitHub runner, and requires a 200 with the expected body response. A failed test does not roll back the release.

## Proof

- [Successful merge-to-deploy run](https://github.com/eddie-cleary/devops-reliability-platform/actions/runs/38459962322): tests, build, push, and ECS deploy, with no manual steps [Screenshot](docs/images/ecs-deployment.png)
- [Deliberately broken release results in automated rollback](https://github.com/eddie-cleary/devops-reliability-platform/actions/runs/38602956975): the circuit breaker stopped after three failed tasks and restored the previous revision. The pipeline run reported the failed deploy. [Screenshot](docs/images/ecs-rollback.png)
- [Automated smoke test passes after a deploy](https://github.com/eddie-cleary/devops-reliability-platform/actions/runs/39294723616): After the deploy, the automated smoke-test job requests the /healthy endpoint from outside of AWS and requires a specific response. [Screenshot](docs/images/smoke-test-pass.png)
- [Automated smoke test catches a bad release](https://github.com/eddie-cleary/devops-reliability-platform/actions/runs/39299865959): A release that returns a bad response was properly detected with a failed smoke-test. The failed response was simulated by changing the response body to simulate a bad deploy. [Screenshot](docs/images/smoke-test-fail.png)

The dev stack is torn down when not in use to lower cost, so it's expected for the `deploy` job on `main` to fail unless the infrastructure is up and running.

## Tech

- AWS (ALB, ECS on EC2, ECR, CloudWatch, SNS)
- Terraform
- GitHub Actions
- Docker
- Python (FastAPI, pytest)

## Local setup and tests

Requires Git and Python 3.14. AWS credentials are not required for local testing.

```bash
git clone https://github.com/eddie-cleary/devops-reliability-platform.git
cd devops-reliability-platform

python3.14 -m venv .venv
source .venv/bin/activate

python -m pip install -r requirements-dev.txt
python -m pip check
python -m pytest -v tests
```

The tests cover health classification, SQLite storage, API responses, and the monitor checking a local HTTP service. Two integration tests briefly start local servers on ports 8001 and 8002.

## Run locally

From the repository root, start the API in one terminal:

```bash
source .venv/bin/activate
python -m uvicorn service.app:app --host 127.0.0.1 --port 8000
```

In a second terminal, also from the repository root:

```bash
source .venv/bin/activate

curl http://127.0.0.1:8000/healthy

python -m monitor.monitor \
  --url http://127.0.0.1:8000/healthy \
  --interval 10
```

The API should return `{"status":"ok"}`. The monitor checks it every ten seconds, prints the health result, and saves check history to a local SQLite file named `checks.db`.

To exercise failure detection, stop the monitor and rerun it with the URL ending in `/error`. The monitor should report `UNHEALTHY`.

## AWS operations

See the [operations runbook](docs/runbook.md) for starting, verifying, testing, troubleshooting, and shutting down the AWS environment.