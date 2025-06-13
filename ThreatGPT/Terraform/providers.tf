# ----------------------------------------------------------------
# providers.tf
# ----------------------------------------------------------------

# ---------------------------------------------------------------- Local variables
locals {
    env         = "staging"
    region      = "eu-north-1"
    zone1       = "eu-north-1a"
    zone2       = "eu-north-1b"
    eks_name    = "eks_demo"
    eks_version     = "1.33"
}

# ---------------------------------------------------------------- Providers

provider "aws" {
    region      = local.region
}

terraform {
    required_version = ">=1.0"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.49"
        }
    }
}
