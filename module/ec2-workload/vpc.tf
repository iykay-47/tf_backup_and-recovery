# Default VPC — only fetched when vpc_id is not provided
data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

# Default subnets — only fetched when subnet_ids are not provided
data "aws_subnets" "default" {
  count = var.subnet_ids == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.resolved_vpc_id]
  }

  filter {
    name   = "defaultForAz"
    values = ["true"]
  }
}

locals {
  resolved_vpc_id    = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
  resolved_subnet_ids = var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.default[0].ids
}

# One thing to be aware of: data.aws_subnets.default[0].ids returns subnets in non-deterministic order.
# This is fine for instance distribution, but if order matters for anything else downstream, sort it:
# resolved_subnet_ids = var.subnet_ids != null ? var.subnet_ids : sort(data.aws_subnets.default[0].ids)