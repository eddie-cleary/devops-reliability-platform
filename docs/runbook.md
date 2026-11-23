# AWS operations runbook

Use this guide to start, verify, troubleshoot, and shut down the AWS development environment.

Run commands from the repository root.

## Before you begin

You need:

- Terraform and the AWS CLI.
- AWS credentials with permission to manage the project resources.
- The project's bootstrap resources.
- Container images in both ECR repositories.
- GitHub OIDC roles and workflow variables if using automated deployment.

### Using your own AWS account

The repository currently contains configuration for the author's AWS environment. Before deploying into another account, review and update:

- `terraform/backend.tf`: state bucket, state key, region, and AWS profile.
- `terraform/variables.tf`: default AWS region and profile.
- `terraform/bootstrap/`: provider settings, state bucket name, and other account-specific values.
- GitHub Actions variables and IAM roles: configure these for your account and repository.

S3 bucket names must be globally unique. Choose your own Terraform state bucket name.

Do not use another environment's Terraform state. A new account requires its own bootstrap resources and runtime state.

This runbook covers operating an environment after that initial setup.

### Set your environment

Replace these example values with your configuration:

```bash
export AWS_PROFILE="your-aws-profile"
export AWS_REGION="us-east-1"

export ECS_CLUSTER="devops-reliability-cluster"
export ECS_SERVICE="reliability-platform"

export SERVICE_REPOSITORY="reliability-service"
export MONITOR_REPOSITORY="reliability-monitor"

export LOG_GROUP="/ecs/devops-reliability"
export ALARM_NAME="devops-reliability-ecs-running-task-count"
export SNS_TOPIC_NAME="devops-reliability-alarm-notifications"
```

The resource names above match the repository defaults. Change them if you rename the corresponding Terraform resources.

For an IAM Identity Center profile, sign in:

```bash
aws login --profile "$AWS_PROFILE"
```

If you use another authentication method, authenticate through that method instead.

Verify your AWS identity:

```bash
aws sts get-caller-identity \
  --profile "$AWS_PROFILE" \
  --output json
```

Confirm this is the account you intend to use.

Retrieve its account ID and construct the SNS topic ARN:

```bash
export AWS_ACCOUNT_ID=$(
  aws sts get-caller-identity \
    --profile "$AWS_PROFILE" \
    --query Account \
    --output text
)

export SNS_TOPIC_ARN="arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${SNS_TOPIC_NAME}"
```

The topic ARN above assumes the standard commercial AWS partition.

Pass your settings to the Terraform AWS provider:

```bash
export TF_VAR_aws_profile="$AWS_PROFILE"
export TF_VAR_aws_region="$AWS_REGION"
```

Terraform's S3 backend has separate authentication settings. Ensure `terraform/backend.tf` matches your environment before running `terraform init`.


## 1. Start the runtime

Choose a release tag that exists in both ECR repositories. Images built by GitHub Actions use the full Git commit SHA.

List recent service images:

```bash
aws ecr describe-images \
  --repository-name "$SERVICE_REPOSITORY" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'reverse(sort_by(imageDetails[?imageTags != `null`], &imagePushedAt))[:5].{Tags:imageTags,Pushed:imagePushedAt}' \
  --output json
```

Set the tag you want to deploy:

```bash
export IMAGE_TAG="<existing-commit-sha>"
```

Confirm the tag exists in both repositories:

```bash
for REPOSITORY in "$SERVICE_REPOSITORY" "$MONITOR_REPOSITORY"; do
  aws ecr describe-images \
    --repository-name "$REPOSITORY" \
    --image-ids imageTag="$IMAGE_TAG" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --query 'imageDetails[].{Tags:imageTags,Digest:imageDigest}' \
    --output json
done
```

Both requests should return image details. If either fails, choose a tag available in both repositories before continuing.

Initialize Terraform and preview the changes:

```bash
terraform -chdir=terraform init

terraform -chdir=terraform plan \
  -var="service_image_tag=$IMAGE_TAG" \
  -var="monitor_image_tag=$IMAGE_TAG"
```

Review the plan, then create the runtime:

```bash
terraform -chdir=terraform apply \
  -var="service_image_tag=$IMAGE_TAG" \
  -var="monitor_image_tag=$IMAGE_TAG"
```

Review the proposed changes and enter `yes`.

The application may need additional startup time after Terraform finishes.

## 2. Verify the application

### Public HTTP endpoint

```bash
ALB_DNS=$(terraform -chdir=terraform output -raw alb_dns_name)

curl -i --max-time 15 "http://$ALB_DNS/healthy"
```

Expect HTTP `200` and:

```json
{"status":"ok"}
```

### ECS service

```bash
aws ecs describe-services \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'services[].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}' \
  --output table
```

For the default single-task configuration, expect:

- Desired: `1`
- Running: `1`
- Pending: `0`

### CloudWatch alarm

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'MetricAlarms[].{State:StateValue,Reason:StateReason}' \
  --output json
```

Expect `OK` after CloudWatch receives healthy task-count data. Temporary alarm transitions can occur during startup.

This alarm checks running task count. The separate HTTP check confirms the application responds.

## 3. Deploy changes

With the runtime available, merge an approved pull request into `main`.

GitHub Actions runs tests and Terraform checks, builds and pushes both images, deploys to ECS, and checks the public endpoint.

Review the workflow result and repeat the application verification checks.

Before a later Terraform apply, update `IMAGE_TAG` to the intended release's commit SHA. Applying with an older tag can restore older images.

## 4. Test outage and recovery notifications

This procedure intentionally interrupts the application. Use it only when downtime is acceptable.

It assumes the default service configuration of one desired task. Begin with the application responding successfully and the alarm in `OK`.

### Stop the task

```bash
aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --desired-count 0 \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'service.{Desired:desiredCount,Running:runningCount}' \
  --output json
```

Allow time for the task to stop and CloudWatch to evaluate the metric. Expect an `ALARM` email.

### Restore the task

```bash
aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --desired-count 1 \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'service.{Desired:desiredCount,Running:runningCount}' \
  --output json
```

Repeat the verification checks. Confirm:

- One task is running.
- The alarm returns to `OK`.
- The recovery email arrives.
- `/healthy` returns HTTP `200`.

Always restore the service after the test, including if email delivery fails.

### Review alarm transitions

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type StateUpdate \
  --max-records 10 \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'AlarmHistoryItems[].{Time:Timestamp,Summary:HistorySummary}' \
  --output json
```

Save any evidence you need before destroying the runtime alarm.

## 5. Troubleshoot

### Credentials have expired

Authenticate again using your configured AWS login method, then retry the failed command.

### The application does not respond

Check the ECS service count using the verification command above.

Inspect recent ECS events:

```bash
aws ecs describe-services \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'services[0].events[:10].{Time:createdAt,Message:message}' \
  --output table
```

Read recent container logs:

```bash
aws logs tail "$LOG_GROUP" \
  --since 15m \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION"
```

Use the events to identify task startup or load balancer problems, and the logs to investigate application errors.

### A deployment fails

Open the failed GitHub Actions job and inspect its first failing step.

- For image push failures, check the ECR error and the build role's permissions.
- For ECS deployment failures, check service events and container logs.
- For smoke-test failures, check the HTTP status and response body.

The ECS deployment circuit breaker can roll back a failed ECS deployment. A failed smoke test does not automatically trigger rollback.

The runtime must exist before the pipeline can deploy to it.

### An alarm changes state but no email arrives

Check the SNS subscription:

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'Subscriptions[].{Protocol:Protocol,Subscription:SubscriptionArn}' \
  --output table
```

A confirmed subscription has a full ARN. If it shows `PendingConfirmation`, accept the confirmation email.

If already confirmed, check spam folders and verify the alarm's notification actions point to the expected topic.

## 6. Shut down the runtime

The runtime and bootstrap configurations have different lifecycles:

| Configuration | Purpose |
|---|---|
| `terraform/` | Runtime networking, load balancer, compute, alarm, and alarm-related SNS topic policy |
| `terraform/bootstrap/` | Retained state bucket, image repositories, log group, SNS topic, and email subscription |

Save useful evidence first. CloudWatch log retention is seven days in the default configuration.

If using a new terminal, restore the environment variables from the beginning of this guide and set `IMAGE_TAG` again.

### Preview deletion

```bash
terraform -chdir=terraform plan -destroy \
  -var="service_image_tag=$IMAGE_TAG" \
  -var="monitor_image_tag=$IMAGE_TAG"
```

Confirm the plan targets the runtime resources.

### Destroy the runtime

```bash
terraform -chdir=terraform destroy \
  -var="service_image_tag=$IMAGE_TAG" \
  -var="monitor_image_tag=$IMAGE_TAG"
```

Review the plan and enter `yes`.

Do not run destroy in `terraform/bootstrap` during routine shutdown. Keep its local state file safe and out of Git.

The public endpoint becomes unavailable after teardown. Retained resources may still incur storage and observability charges.

### Confirm logs remain

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --order-by LastEventTime \
  --descending \
  --max-items 3 \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'logStreams[].{Stream:logStreamName,LastEvent:lastEventTimestamp}' \
  --output table
```

Expect existing service and monitor log streams if the application has run and the logs have not expired.

### Confirm the email subscription remains

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'Subscriptions[].{Protocol:Protocol,Subscription:SubscriptionArn}' \
  --output table
```

Expect the same confirmed subscription ARN as before teardown.