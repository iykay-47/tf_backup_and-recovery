terraform {
  backend "s3" {
    bucket       = "backup-s3-remote-1576320"
    key          = "backup-and-recovery/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true #enable s3 native locking
  }
}