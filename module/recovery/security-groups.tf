# Security group for DR instances (mirrors primary)
resource "aws_security_group" "dr_instances" {
  name_prefix = "${var.project_name}-${var.environment}-dr-instance-sg"
  description = "Security group for DR EC2 instances"
  vpc_id      = aws_vpc.dr.id

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-dr-instance-sg"
      Purpose = "DisasterRecovery"
    }
  )
}

# locals

resource "aws_vpc_security_group_ingress_rule" "dr_instance_ingress" {
  for_each = var.dr_sec_group_config

  security_group_id = aws_security_group.dr_instances.id
  from_port         = each.value.port
  to_port           = each.value.port
  description       = each.value.description
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_ingress_rule" "dr_instance_ssh" {
  count             = var.ssh_access ? 1 : 0
  security_group_id = aws_security_group.dr_instances.id
  from_port         = 22
  to_port           = 22
  description       = "SSH Access"
  ip_protocol       = "tcp"
  cidr_ipv4         = var.my_ip
}

resource "aws_vpc_security_group_egress_rule" "dr_instance_egress" {
  description = "Egress for DR-Instances"

  security_group_id = aws_security_group.dr_instances.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}