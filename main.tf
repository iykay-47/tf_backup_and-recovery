terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.primary_region
  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "backup"
  region = var.dr_region
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "Ops-Team"
  }
}

module "dlm_backup" {
  source = "./module/backup/"

  project_name             = var.project_name
  environment              = var.environment
  primary_region           = var.primary_region
  dr_region                = var.dr_region
  enable_cross_region_copy = var.enable_cross_region_copy
  retention_counts         = var.retention_counts
  backup_schedules         = var.backup_schedules
}

# EC2 Workload Module

module "ec2_workload" {
  source = "./module/ec2-workload"

  environment             = var.environment
  project_name            = var.project_name
  vpc_id                  = var.vpc_id
  subnet_ids              = var.subnet_ids
  common_tags             = local.common_tags
  my_ip                   = var.my_ip
  ssh_access = var.ssh_access
  instance_configs        = var.instance_configs
  public_sec_group_config = var.public_sec_group_config
}

# Recovery

module "disaster_recovery" {

  providers = {
    aws = aws.backup
  }

  source = "./module/recovery/"

  project_name       = var.project_name
  environment        = var.environment
  region             = var.dr_region
  enable_nat_gateway = var.enable_nat_gateway
  instance_configs   = var.dr_instance_configs
  my_ip              = var.my_ip
  kms_key_arn        = module.dlm_backup.dr_kms_arn # var.kms_key_arn
  availability_zones = data.aws_availability_zones.dr_zones.names # var.dr_availability_zones
  recovery_ami_ids = var.recovery_ami_ids

}

