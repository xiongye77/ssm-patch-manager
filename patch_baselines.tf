resource "aws_ssm_patch_baseline" "prod-baseline" {
  name             = "prod-amazon-linux2"
  description      = "Approves all Amazon Linux 2 operating system patches that are classified as Security, Bugfix or Recommended"
  operating_system = "AMAZON_LINUX_2"

  global_filter {
    key = "CLASSIFICATION"
    values = [
      "Security",
      "Bugfix",
      "Recommended"
    ]
  }

  approval_rule {
    approve_after_days = 7

    patch_filter {
      key = "CLASSIFICATION"
      values = [
        "Security",
        "Bugfix",
        "Recommended"
      ]
    }
  }
}


resource "aws_ssm_patch_group" "prod-patchgroup" {
  baseline_id = aws_ssm_patch_baseline.prod-baseline.id
  patch_group = "prod-amazon-linux2"
}
