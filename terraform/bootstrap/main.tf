## bootstrap/main.tf is intended to establish the Elastic Container Repositories and backend infrastructure a runtime teardown does not remove them.

resource "aws_s3_bucket" "terraform_state" {
  bucket = "devops-reliability-tfstate-670253275650"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "service" {
  name                 = "reliability-service"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true


  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "monitor" {
  name                 = "reliability-monitor"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true


  image_scanning_configuration {
    scan_on_push = true
  }
}