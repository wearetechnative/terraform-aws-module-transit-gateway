# TFLint requires both blocks. Shipping them here stops every new module from
# starting with the same two findings.
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
