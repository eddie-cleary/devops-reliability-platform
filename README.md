# DevOps Reliability Platform

A small monitored web service deployed to AWS through a CI/CD pipeline. I'm building it to practice shipping, running, monitoring, and fixing a real service end to end.

**Status:** Work in progress. Currently building out automated deploys to AWS ECS.

## Overview

The project has two parts:

- **Service:** a FastAPI app with endpoints that simulate healthy, failing, slow, and flaky behavior.
- **Monitor:** a Python script that checks the service's health endpoint on an interval and records the status and latency of each check.

Both run as separate containers in one ECS task on an EC2 instance. The infrastructure is defined in Terraform.

## Pipeline

- **Pull request into `main`:** runs the test suite.
- **Merge to `main`:** runs tests, builds and pushes SHA-tagged images to ECR, then runs the deploy job in the `dev` environment.
- GitHub Actions authenticates to AWS with OIDC, avoiding stored access keys to follow secure authentication practices.
- `main` is protected: changes require a pull request that passes testing.

## Tech

- AWS (ECS on EC2, ECR, CloudWatch, SNS)
- Terraform
- GitHub Actions
- Docker
- Python (FastAPI, pytest)