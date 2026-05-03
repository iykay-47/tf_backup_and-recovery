data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "dlm_primary_region_key" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow Dlm-role to use key"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.dlm_lifecycle_role.arn]
    }
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow ec2 to make use of key to decrypt volume and create ami/ebs vol"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "dlm_cross_region_key" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow Dlm-role to use key"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.dlm_lifecycle_role.arn]
    }
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow ec2 to make use of key to decrypt volume and create ami/ebs vol"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow DR instance-role to decrypt data"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-dr-inst-role"]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "dlm_cross_region_copy" {
  region                  = var.dr_region
  description             = "Disaster-Recovery Region KMS Key"
  policy                  = data.aws_iam_policy_document.dlm_cross_region_key.json
  enable_key_rotation     = true
  rotation_period_in_days = 90
  deletion_window_in_days = 30

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-dr-kms-key"
      Purpose = "DREncryption"
      Region  = var.dr_region

  })
}

resource "aws_kms_key" "dlm_primary_copy" {
  description             = "Primary KMS key for backup encryption"
  policy                  = data.aws_iam_policy_document.dlm_primary_region_key.json
  enable_key_rotation     = true
  rotation_period_in_days = 90
  deletion_window_in_days = 30

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-primary-kms-key"
      Purpose = "DREncryption"
      Region  = var.primary_region

  })
}

resource "aws_kms_alias" "dlm_cross_region" {
  region        = var.dr_region
  name          = "alias/${var.project_name}-${var.environment}-dlm-backup-region"
  target_key_id = aws_kms_key.dlm_cross_region_copy.id
}

resource "aws_kms_alias" "dlm_primary_region" {
  name          = "alias/${var.project_name}-${var.environment}-dlm-primary-region"
  target_key_id = aws_kms_key.dlm_primary_copy.id
}