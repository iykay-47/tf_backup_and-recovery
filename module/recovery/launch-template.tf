# Placeholder Holder AMI until recovery AMI's are passed
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# IAM role for DR instances
resource "aws_iam_role" "dr_instance_role" {
  name = "${var.project_name}-${var.environment}-dr-inst-role"

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

resource "aws_iam_role_policy_attachment" "dr_cloudwatch" {
  role       = aws_iam_role.dr_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "dr_ssm" {
  role       = aws_iam_role.dr_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "dr_instance_profile" {
  name_prefix = "${var.project_name}-${var.environment}-dr-instance-profile"
  role        = aws_iam_role.dr_instance_role.name

  tags = var.common_tags
}

resource "aws_launch_template" "dr_recovery" {
  for_each = var.instance_configs

  name_prefix   = "${var.project_name}-${var.environment}-dr-${each.key}"
  description   = "Launch template for DR recovery of ${each.key}"
  instance_type = each.value.instance_type

  # Placeholder AMI for template creation

  image_id = lookup(var.recovery_ami_ids, each.key, data.aws_ami.amazon_linux_2.id)

  vpc_security_group_ids = [aws_security_group.dr_instances.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.dr_instance_profile.arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.common_tags,
      {
        Name             = "${var.project_name}-${var.environment}-dr-${each.key}"
        Environment      = "${var.project_name}-${var.environment}-DR"
        RecoveryInstance = "true"
        SourceInstance   = each.key
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.common_tags,
      {
        Name = "${var.environment}-dr-${each.key}-volume"
      }
    )
  }

  user_data = templatefile("${path.module}/recovery-user-data.tftpl", {
    instance_name = each.key
    environment   = "${var.environment}-DR"
  })

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-dr-${each.key}-lt"
      Purpose = "DisasterRecovery"
    }
  )
}