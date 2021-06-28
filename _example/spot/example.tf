provider "aws" {
  region = "eu-west-1"
}

module "keypair" {
  source  = "clouddrove/keypair/aws"
  version = "0.15.0"

  public_key      = "ssh-rsaDT+0gYmv60AJc+btcl+ehTSSO//YbWDnrLpcTDx8nu4d0sLz/40JS2YB7zJkeBL3/Fd+YxeC8j0ZyIedhuQAgQEuS6sccV2yv2Htj0pWBJeLbEvdU8BsuDijW7TzrKa81pjVwnmd22m1DWnPqUKZcOgr5e01Rwr4ot2c+ZjoTuR9OcpWYyvG/3jsyNL34kZZGOwwhB9sDYu5YTcaJdgrZq8mZSvYP9R3WUpjyu64ad9692/8/fNWkXc9Z1ScwRI6jH922rOGTycH8kaFUhh/WcAJeWe91B9YT2Prs5ZjNcSOx8xMa8XsUHw0quTLFq9THu4OjZwgUena2P6CRo08qdt4W+M20Wiz5tBg1vXRtLg7PqJJM2fvrAGuBvZesx6AUlnUxnpKiW2oaCWgO1eu7yxTNkGxtbLkjTL9q56Zn5MepgRBadg/ECSRlA2fpWd5VlS5nM+ddFdc64s+65WbJBAPqnetL624/MY7yRi0HIv0EbGJSI8SwSoPwHV2ZYSXUb/g0lURE4woGROXLCHJ/CUAhWU0xhbhwyBAvvJ/7KD57S6su4k/lzbxW9TDoBrNiSlZAbH5sV+UEg/xQSkBbvZ+mNLCGwDvTYJvu/b6MGWu4YYo1qa1eMcJBbuYbg2SuEyctHXXGH6ul7sn3SauFzvbuDx0ZM2GE+TIQ1/BdfvNiUjedKVnvl8BcswghWyk8nsHmYA4AcjD+kLfeF6FJh2cpHDVHjtiO0YPg1xS9gQqiiZIAWqR3vl9twoAj4QOwcA+tW+zyu2vwusjfkRbytuGJxJL3UksJy1Wn3/T9m2ZeXhpatvFCwpxkxRxN4Xezlpielyu+fxsjUv64nouZvsitQM4JnctQmPzS6s2od3Vw5PQZUShwQAoGT5rvgpFoVnXUa8hw0fGd+RdfAsnJ34ZlObXXaQheNSybkm/kkHIBxUFJuWkxuWc62yBpnVTbrGo6jOoyzGnbAo1KmYIRszVlmJhMK6p6q3rP5hWJRgb+lqf8nCBEDjLi0fglPf meitner"
  key_name        = "devops"
  enable_key_pair = true
  environment     = "test"

}

module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "0.15.0"

  name        = "vpc"
  environment = "test"
  label_order = ["environment", "name"]

  cidr_block = "172.16.0.0/16"
}

module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "0.15.0"

  name        = "public-subnet"
  environment = "test"
  label_order = ["environment", "name"]

  availability_zones = ["eu-west-1b", "eu-west-1c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
}

module "http-https" {
  source  = "clouddrove/security-group/aws"
  version = "0.15.0"

  name        = "http-https"
  environment = "test"
  label_order = ["environment", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = ["0.0.0.0/0"]
  allowed_ports = [80, 443]
}

module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "0.15.0"

  name        = "ssh"
  environment = "test"
  label_order = ["environment", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block, "0.0.0.0/0"]
  allowed_ports = [22]
}

module "iam-role" {
  source  = "clouddrove/iam-role/aws"
  version = "0.15.0"

  name               = "clouddrove"
  environment        = "test"
  label_order        = ["name", "environment"]
  assume_role_policy = data.aws_iam_policy_document.default.json

  policy_enabled = true
  policy         = data.aws_iam_policy_document.iam-policy.json
}

data "aws_iam_policy_document" "default" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "iam-policy" {
  statement {
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
    "ssmmessages:OpenDataChannel"]
    effect    = "Allow"
    resources = ["*"]
  }
}

module "ec2-autoscale" {
  source = "../../"

  enabled     = true
  name        = "ec2"
  environment = "test"
  label_order = ["environment", "name"]

  image_id                  = "ami-0ceab0713d94f9276"
  instance_profile_enabled  = true
  iam_instance_profile_name = module.iam-role.name

  security_group_ids = [module.ssh.security_group_ids, module.http-https.security_group_ids]
  user_data_base64   = ""

  subnet_ids                              = tolist(module.public_subnets.public_subnet_id)
  spot_max_size                           = 3
  spot_min_size                           = 1
  spot_desired_capacity                   = 1
  spot_enabled                            = true
  on_demand_enabled                       = false
  scheduler_down                          = "0 19 * * MON-FRI"
  scheduler_up                            = "0 6 * * MON-FRI"
  spot_min_size_scaledown                 = 1
  spot_max_size_scaledown                 = 1
  spot_schedule_enabled                   = false
  spot_scale_down_desired                 = 1
  spot_scale_up_desired                   = 2
  max_price                               = "0.20"
  volume_size                             = 20
  ebs_encryption                          = false
  kms_key_arn                             = ""
  volume_type                             = "standard"
  spot_instance_type                      = "m5.large"
  associate_public_ip_address             = true
  instance_initiated_shutdown_behavior    = "terminate"
  key_name                                = module.keypair.name
  enable_monitoring                       = true
  load_balancers                          = []
  health_check_type                       = "EC2"
  target_group_arns                       = []
  default_cooldown                        = 150
  force_delete                            = false
  termination_policies                    = ["Default"]
  suspended_processes                     = []
  enabled_metrics                         = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  metrics_granularity                     = "1Minute"
  wait_for_capacity_timeout               = "5m"
  protect_from_scale_in                   = false
  service_linked_role_arn                 = ""
  scale_up_cooldown_seconds               = 150
  scale_up_scaling_adjustment             = 1
  scale_up_adjustment_type                = "ChangeInCapacity"
  scale_up_policy_type                    = "SimpleScaling"
  scale_down_cooldown_seconds             = 300
  scale_down_scaling_adjustment           = -1
  scale_down_adjustment_type              = "ChangeInCapacity"
  scale_down_policy_type                  = "SimpleScaling"
  cpu_utilization_high_evaluation_periods = 2
  cpu_utilization_high_period_seconds     = 300
  cpu_utilization_high_threshold_percent  = 10
  cpu_utilization_high_statistic          = "Average"
  cpu_utilization_low_evaluation_periods  = 2
  cpu_utilization_low_period_seconds      = 180
  cpu_utilization_low_statistic           = "Average"
  cpu_utilization_low_threshold_percent   = 1
}
