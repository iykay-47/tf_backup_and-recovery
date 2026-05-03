data "aws_availability_zones" "dr_zones" {
  region = var.dr_region
  state  = "available"
}