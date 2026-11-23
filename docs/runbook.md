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