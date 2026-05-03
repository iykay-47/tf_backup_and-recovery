#Aws role for DLM service (Snapshots and AMI)
resource "aws_iam_role" "dlm_lifecycle_role" {
  name_prefix = "${var.project_name}-${var.environment}-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-${var.environment}-dlm-lifecycle-role"
    ManagedBy = "Terraform"
  }
}

#Custom Policy for dlm 
resource "aws_iam_policy" "dlm_lifecycle_policy" {
  name_prefix = "${var.project_name}-${var.environment}-dlm-lifecycle-policy"
  description = "Policy for DLM lifecycle management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:EnableFastSnapshotRestores",
          "ec2:DescribeFastSnapshotRestores",
          "ec2:DisableFastSnapshotRestores",
          "ec2:CopySnapshot",
          "ec2:ModifySnapshotAttribute",
          "ec2:DescribeSnapshotAttribute",
          "ec2:ModifySnapshotTier",
          "ec2:DescribeSnapshotTierStatus",
          "ec2:DescribeAvailabilityZones"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateTags",
          "events:PutRule",
          "events:DeleteRule",
          "events:DescribeRule",
          "events:EnableRule",
          "events:DisableRule",
          "events:ListTargetsByRule",
          "events:PutTargets",
          "events:RemoveTargets"
        ],
        Resource = "arn:aws:events:*:*:rule/AwsDataLifecycleRule.managed-cwe.*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:snapshot/*",
          "arn:aws:ec2:*:*:image/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:ResetImageAttribute",
          "ec2:DeregisterImage",
          "ec2:CreateImage",
          "ec2:CopyImage",
          "ec2:ModifyImageAttribute",
          "ec2:DescribeImages",
          "ec2:DescribeImageAttribute"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:EnableImageDeprecation",
          "ec2:DisableImageDeprecation"
        ],
        Resource = "arn:aws:ec2:*::image/*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.project_name}-${var.environment}-dlm-lifecycle-policy"
    ManagedBy = "Terraform"
  })
}

resource "aws_iam_role_policy_attachment" "dlm_lifecycle_policy" {
  role       = aws_iam_role.dlm_lifecycle_role.name
  policy_arn = aws_iam_policy.dlm_lifecycle_policy.arn
}
