# AWS Backup & Disaster Recovery — Terraform

A production-style, modular Terraform project that provisions an automated backup and cross-region disaster recovery system on AWS. EC2 workloads are continuously backed up via AWS Data Lifecycle Manager (DLM) with tag-driven policies, encrypted with customer-managed KMS keys, and replicated to a DR region. A pre-provisioned recovery environment stands ready to receive restored AMIs and spin up instances at short notice.

---

## Architecture Overview

```
Primary Region (us-east-2)                   DR Region (us-west-1)
─────────────────────────────                ─────────────────────────────
  EC2 Workload                                 Recovery Module
  ├── web-server  (public, critical)            ├── DR VPC (public + private subnets)
  ├── app-server  (private, daily)              ├── Launch Templates (per instance)
  └── db-server   (private, critical)           └── IAM role + SSM/CloudWatch access
        │
        │  EBS Volumes (gp3, encrypted)
        │
  DLM Backup Module
  ├── Snapshot policy     → daily, 21-day retention
  ├── AMI policy (daily)  → tag: BackupPolicy=daily
  ├── AMI policy (weekly) → tag: BackupPolicy=weekly
  ├── AMI policy (monthly)→ tag: BackupPolicy=monthly
  └── AMI policy (critical)→ tag: BackupPolicy=critical (every 12h)
        │
        │  Cross-region copy (optional)
        ▼
  KMS (Primary CMK)  ──────────────────────► KMS (DR CMK)
                                               └── Encrypted AMI copies
                                               └── 30-day DR retention
```

Backup targets are determined entirely by instance tags (`BackupPolicy`, `BackupEnabled`), meaning no changes to Terraform are required when adding new instances — tag the resource and DLM picks it up automatically.

---

## Design Decisions

**Tag-driven backup selection** rather than explicit resource references keeps the backup module decoupled from the workload module. Instances opt in by tag, making the system extensible without infrastructure changes.

**Customer-managed KMS keys (CMK) in both regions** rather than AWS-managed keys gives full control over key policy, rotation schedule (90 days), and access auditing via CloudTrail. The DR KMS key explicitly grants access to the DR instance role by name, so recovered instances can decrypt volumes without manual intervention.

**DLM over AWS Backup** was chosen for this use case because the workload is EC2/EBS-centric and DLM provides native, low-overhead lifecycle management with cron-level scheduling precision and direct cross-region copy support — without the additional abstraction layer of AWS Backup.

**Launch Templates in the DR module** (rather than live instances) keep DR costs near zero at rest. Templates are pre-configured with the DR KMS key, security groups, IAM profile, and user-data validation script. Recovery is a matter of launching from the template with the restored AMI ID passed in via `recovery_ami_ids`.

**IMDSv2 enforced** on all instances (`http_tokens = required`, hop limit = 1) to prevent SSRF-based metadata credential theft.

**Provider aliasing** is used so the DR module deploys into `us-west-1` while the primary workload and backup module deploy into `us-east-2` — all managed from a single root configuration with no workspace gymnastics.

**S3 remote state** with native S3 locking (`use_lockfile = true`) and server-side encryption keeps state secure and consistent across collaborators without requiring a DynamoDB lock table.

---

## Project Structure

```
backup-and-recovery/
├── main.tf                  # Providers, locals, module calls
├── variable.tf              # Root variable declarations
├── terraform.tfvars         # Environment-specific values
├── vpc.tf                   # DR availability zone data source
├── backend.tf               # S3 remote state configuration
│
├── s3_state/
│   └── s3_backend.tf        # State bucket (versioning, encryption, public access block)
│
└── module/
    ├── backup/              # DLM lifecycle policies + KMS keys
    │   ├── backup-main.tf
    │   ├── iam.tf
    │   ├── kms.tf
    │   ├── snapshots.tf
    │   ├── ami-backup.tf
    │   ├── ami-critical.tf
    │   ├── ami-weekly.tf
    │   ├── ami-monthly.tf
    │   ├── variables.tf
    │   └── output.tf
    │
    ├── ec2-workload/        # EC2 instances, EBS volumes, SG, IAM
    │   ├── ec2-main.tf
    │   ├── iam_SG.tf
    │   ├── vpc.tf
    │   ├── variables.tf
    │   ├── output.tf
    │   └── user-data.tftpl
    │
    └── recovery/            # DR VPC, launch templates, security groups
        ├── main.tf
        ├── vpc.tf
        ├── security-groups.tf
        ├── launch-template.tf
        ├── variables.tf
        ├── outputs.tf
        └── recovery-user-data.tftpl
```

---

## Backup Policies

| Policy | Trigger Tag | Frequency | Retention | Cross-Region Copy |
|--------|------------|-----------|-----------|-------------------|
| Snapshot | `BackupEnabled=true` | Daily (01:30 UTC) | 21 days | 30 days (if enabled) |
| Daily AMI | `BackupPolicy=daily` | Every 24h | 7 AMIs | 30 days (if enabled) |
| Weekly AMI | `BackupPolicy=weekly` | Weekly (Sunday 03:00 UTC) | 4 AMIs | 30 days (if enabled) |
| Monthly AMI | `BackupPolicy=monthly` | Monthly (1st, 04:00 UTC) | 12 AMIs | 90 days (if enabled) |
| Critical AMI | `BackupPolicy=critical` | Every 12h | 14 AMIs (7 days) | 30 days (if enabled) |

All AMI backups are encrypted with the primary region CMK. Cross-region copies are re-encrypted with the DR region CMK automatically by DLM.

---

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- An existing EC2 key pair if SSH access is required
- The S3 state bucket must be provisioned before the root module is applied

---

## Getting Started

### 1. Provision the state bucket

The state bucket is managed as a separate Terraform configuration to avoid a bootstrapping circular dependency.

```bash
cd s3_state/
terraform init
terraform apply
cd ..
```

### 2. Configure your variables

Rename `terraform.tfvars.example` to `terraform.tfvars`

Edit `terraform.tfvars` with your values:


```hcl
project_name   = "backup-and-recovery"
environment    = "dev"
primary_region = "us-east-2"
dr_region      = "us-west-1"
my_ip          = "YOUR_IP/32"   # Replace with your actual IP
ssh_access     = false          # Set to true only if needed
```

### 3. Initialise and apply

```bash
terraform init
terraform plan
terraform apply
```

### 4. Disaster Recovery — launching recovered instances

When a recovery event occurs, identify the AMI IDs from the DR region and pass them in:

```hcl
# terraform.tfvars
recovery_ami_ids = {
  "web-server" = "ami-0abc123456789"
  "db-server"  = "ami-0def987654321"
}

dr_instance_configs = {
  "web-server" = { instance_type = "t2.micro" }
  "db-server"  = { instance_type = "t2.micro" }
}
```

Then re-apply. The recovery module will launch instances from the pre-configured launch templates using the restored AMIs, decrypting volumes automatically using the DR KMS key.

---

## Module Reference

### `module/backup`

Provisions all DLM lifecycle policies and KMS keys. Designed to be applied in the primary region with optional cross-region replication.

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `project_name` | string | Project identifier | `"backup-and-recovery"` |
| `environment` | string | `dev`, `staging`, or `prod` | — |
| `primary_region` | string | Region for primary KMS key | — |
| `dr_region` | string | Region for DR KMS key and AMI copies | — |
| `enable_cross_region_copy` | bool | Enable cross-region AMI/snapshot replication | — |
| `retention_counts` | object | Per-policy retention counts | See variables.tf |
| `backup_schedules` | object | Schedule config (daily time, weekly day, monthly day) | See variables.tf |

**Outputs:** `daily_ami_policy_id`, `weekly_ami_policy_id`, `monthly_ami_policy_id`, `critical_ami_policy_id`, `daily_snapshot_policy_id`, `kms_arn`, `dr_kms_arn`

---

### `module/ec2-workload`

Provisions EC2 instances, additional EBS volumes, and security groups. Instances are distributed across AZs automatically. Falls back to the default VPC and subnets if none are provided.

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `instance_configs` | map(object) | Per-instance type, backup policy, volumes | — |
| `vpc_id` | string | VPC ID; uses default VPC if null | `null` |
| `subnet_ids` | list(string) | Subnet IDs; uses default subnets if null | `null` |
| `ssh_access` | bool | Add SSH ingress rule to public SG | `false` |
| `my_ip` | string | CIDR for SSH access (e.g. `1.2.3.4/32`) | — |

**Outputs:** `instance_ids`, `instance_arns`, `volume_ids`, `security_group_id`, `instance_details`, `public_ips`

---

### `module/recovery`

Provisions a self-contained DR environment in the target region. Resources are cost-optimised at rest — instances are only launched when recovery AMI IDs are provided.

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `region` | string | DR region | — |
| `vpc_cidr` | string | CIDR for DR VPC | `"10.1.0.0/16"` |
| `availability_zones` | list(string) | AZs to deploy subnets into | — |
| `kms_key_arn` | string | DR region KMS key ARN (from backup module output) | — |
| `enable_nat_gateway` | bool | NAT gateway for private subnets | `false` |
| `recovery_ami_ids` | map(string) | Instance name → AMI ID for recovery launch | `{}` |
| `dr_instance_configs` | map(object) | Instance types for DR instances | `{}` |

**Outputs:** `launch_template_ids`, `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `security_group_id`

---

## Security Posture

- All EBS volumes and AMIs encrypted with customer-managed KMS keys
- KMS keys rotate every 90 days with a 30-day deletion window
- IMDSv2 enforced on all instances (hop limit = 1)
- EC2 instances use IAM instance profiles with least-privilege policies (SSM + CloudWatch only — no static credentials)
- SSH disabled by default; when enabled, restricted to a single CIDR via `my_ip`
- S3 state bucket has public access fully blocked and versioning enabled
- DLM IAM policy scoped to tagged resources where possible

---

## Teardown

```bash
# Destroy primary infrastructure
terraform destroy

# Destroy state bucket (requires setting prevent_destroy = false first)
cd s3_state/
terraform destroy
```

> **Note:** The state bucket has `prevent_destroy = true` set as a safeguard. Update this before attempting to destroy it.