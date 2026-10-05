terraform {
  backend "s3" {
    bucket       = "devops-reliability-tfstate-670253275650"
    key          = "devops-reliability/terraform.tfstate"
    region       = "us-east-1"
    profile      = "devops-reliability"
    encrypt      = true
    use_lockfile = true
  }
}
