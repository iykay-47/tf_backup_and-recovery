# IAM role for EC2 instances (CloudWatch, SSM)
resource "aws_iam_role" "instance_role" {
  name_prefix = "${var.project_name}-${var.environment}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "${var.project_name}-${var.environment}-instance-profile"
  role        = aws_iam_role.instance_role.name

  tags = var.common_tags
}

# Security group for instances
resource "aws_security_group" "public_instances" {
  name_prefix = "${var.project_name}-${var.environment}-public-instance-sg"
  description = "Public Security group for EC2 instances"
  vpc_id      = local.resolved_vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-instance-sg"
    }
  )
}

resource "aws_security_group" "private_instances" {
  name_prefix = "${var.project_name}-${var.environment}-private-instance-sg"
  description = "Private Security group for EC2 instances"
  vpc_id      = local.resolved_vpc_id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-instance-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "public_instance_ingress" {
  for_each = var.public_sec_group_config

  security_group_id = aws_security_group.public_instances.id
  from_port         = each.value.port
  to_port           = each.value.port
  description       = each.value.description
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_ingress_rule" "public_instance_ssh" {
  count             = var.ssh_access ? 1 : 0
  security_group_id = aws_security_group.public_instances.id
  from_port         = 22
  to_port           = 22
  description       = "SSH Access"
  ip_protocol       = "tcp"
  cidr_ipv4         = var.my_ip
}

resource "aws_vpc_security_group_egress_rule" "public_instance_egress" {
  description = "Egress for DR-Instances"

  security_group_id = aws_security_group.public_instances.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}