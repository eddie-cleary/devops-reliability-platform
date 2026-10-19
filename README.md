# DevOps Reliability Platform

A small monitored web service deployed to AWS through a CI/CD pipeline. I'm building it to practice shipping, running, monitoring, and fixing a real service end to end.

**Status:** Work in progress. Automated deploys to AWS ECS work in dev, and a deliberately broken release rolls back on its own. Next feature to implement is smoke tests.

## Overview

The project has two parts:

- **Service:** a FastAPI app with endpoints that simulate healthy, failing, slow, and flaky behavior.
- **Monitor:** a Python script that checks the service's health endpoint on an interval and records the status and latency of each check.

Both run as separate containers in one ECS task on an EC2 instance. The infrastructure is defined in Terraform.

## Pipeline

- **Pull request into `main`:** runs the test suite.
- **Merge to `main`:** runs tests, builds and pushes SHA-tagged images to ECR, then deploys to the `dev` environment. The deploy job registers a new ECS task definition with the new images, updates the service, and waits for it to stabilize.
- **Automatic rollback:** the ECS service has the deployment circuit breaker enabled. If new tasks keep failing, ECS rolls back to the last good revision.
- GitHub Actions authenticates to AWS with OIDC, so no long-lived access keys are stored.
- `main` is protected: changes require a pull request and a passing `tests` check.

## Proof

- [Successful merge-to-deploy run](https://github.com/eddie-cleary/devops-reliability-platform/actions/runs/38459962322): tests, build, push, and ECS deploy, with no manual steps
- [Deploy job log showing the rollout verified](docs/images/ecs-deployment.png)
- [Deliberately broken release, resulted in an automated rollback](docs/images/ecs-rollback.png): the circuit breaker stopped after three failed tasks and restored the previous revision. The [pipeline run](https://github.com/eddie-cleary/devops-reliability-platform/actions/runs/38602956975) reported the failed deploy.

The dev stack is torn down when not in use to lower cost, so it's expected for the `deploy` job on `main` to fail unless the infrastructure is up and running.

## Tech

- AWS (ECS on EC2, ECR, CloudWatch, SNS)
- Terraform
- GitHub Actions
- Docker
- Python (FastAPI, pytest)