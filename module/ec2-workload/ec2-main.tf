# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(local.resolved_subnet_ids)
  id       = each.value
}

# Local for distributing instances across AZs
locals {
  instance_list = [
    for instance_name, config in var.instance_configs : {
      name      = instance_name
      config    = config
      subnet_id = local.resolved_subnet_ids[index(keys(var.instance_configs), instance_name) % length(local.resolved_subnet_ids)]
      az_index  = index(keys(var.instance_configs), instance_name) % length(local.resolved_subnet_ids)
    }
  ]
}

# EC2 Instances
resource "aws_instance" "workload" {
  for_each = { for inst in local.instance_list : inst.name => inst }

  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = each.value.config.instance_type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = each.value.config.public_ip ? [aws_security_group.public_instances.id] : [aws_security_group.private_instances.id]
  key_name                    = each.value.config.key_name
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  associate_public_ip_address = each.value.config.public_ip

  user_data = templatefile("${path.module}/user-data.tftpl", {
    instance_name = each.key
    environment   = var.environment
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true

    tags = merge(
      var.common_tags,
      {
        Name          = "${var.environment}-${each.key}-root"
        BackupEnabled = "true"
        BackupPolicy  = each.value.config.backup_policy
      }
    )
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.common_tags,
    {
      Name          = "${var.environment}-${each.key}"
      BackupEnabled = "true"
      BackupPolicy  = each.value.config.backup_policy
      Application   = each.key
      Environment   = var.environment
      InstanceName  = each.key
    }
  )
}

# Additional EBS volumes
resource "aws_ebs_volume" "additional" {
  for_each = {
    for item in flatten([
      for inst_name, inst in local.instance_list : [
        for vol_idx, vol in inst.config.additional_volumes : {
          key           = "${inst.name}-vol-${vol_idx}"
          instance_name = inst.name
          az            = data.aws_subnet.selected[inst.subnet_id].availability_zone
          size          = vol.size
          type          = vol.type
          fast_restore  = vol.fast_restore
          backup_policy = inst.config.backup_policy
          vol_idx       = vol_idx
        }
      ]
    ]) : item.key => item
  }

  availability_zone = each.value.az
  size              = each.value.size
  type              = each.value.type
  encrypted         = true

  tags = merge(
    var.common_tags,
    {
      Name          = "${var.environment}-${each.value.key}"
      BackupEnabled = "true"
      BackupPolicy  = each.value.backup_policy
      QuickRestore  = each.value.fast_restore ? "true" : "false"
      InstanceName  = each.value.instance_name
      VolIndex      = tostring(each.value.vol_idx)
    }
  )
}


resource "aws_volume_attachment" "additional" {
  for_each    = aws_ebs_volume.additional
  device_name = "/dev/sd${substr("fghijklmnop", tonumber(each.value.tags["VolIndex"]), 1)}"
  volume_id   = each.value.id
  instance_id = aws_instance.workload[each.value.tags["InstanceName"]].id
}