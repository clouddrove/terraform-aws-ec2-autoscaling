provider "aws" {
  region = "eu-west-1"
}

module "keypair" {
  source  = "clouddrove/keypair/aws"
  version = "1.3.0"

  public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCmPuPTJ58AMvweGBuAqKX+tkb0ylYq5k6gPQnl6+ivQ8i/jsUJ+juI7q/7vSoTpd0k9Gv7DkjGWg1527I+LJeropVSaRqwDcrnuM1IfUCu0QdRoU8e0sW7kQGnwObJhnRcxiGPa1inwnneq9zdXK8BGgV2E4POKdwbEBlmjZmW8j4JMnCsLvZ4hxBjZB/3fnvHhn7UCqd2C6FhOz9k+aK2kxXHxdDdO9BzKqtvm5dSAxHhw6nDHSU+cHupjiiY/SvmFH0QpR5Fn1kyZH7DxV4D8R9wvP9jKZe/RRTEkB2HY7FpVNz/EqO/z5bv7japQ5LZY1fFOK47S5KVo20y12XwkBcHeL5Bc8MuKt552JSRH7KKxvr2KD9QN5lCc0sOnQnlOK0INGHeIY4WnUSBvlVd4aOAJa4xE2PP0/kbDMAZfO6ET5OIlZF+X7n5VCYyxNJLWbx4opFIcpWgINz4m/GkArB4p4KeF+pc84rX5GkM4fn5"
  key_name        = "devops"
  environment     = "test"
  enable_key_pair = true
}

module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "1.3.1"

  name        = "vpc"
  environment = "test"
  label_order = ["environment", "name"]

  cidr_block = "172.16.0.0/16"
}

module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "1.3.0"

  name               = "public-subnet"
  environment        = "test"
  label_order        = ["environment", "name"]
  availability_zones = ["eu-west-1b", "eu-west-1c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
}

module "http-https" {
  source  = "clouddrove/security-group/aws"
  version = "1.3.0"

  name        = "http-https"
  environment = "test"
  label_order = ["environment", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = ["0.0.0.0/0"]
  allowed_ports = [80, 443]
}

module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "1.3.0"

  name        = "ssh"
  environment = "test"
  label_order = ["environment", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block, "0.0.0.0/0"]
  allowed_ports = [22]
}

module "iam-role" {
  source  = "clouddrove/iam-role/aws"
  version = "1.3.0"

  name               = "clouddrove"
  environment        = "example"
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
  environment = "test1"
  label_order = ["environment", "name"]

  #Launch template
  image_id                  = "ami-08bac620dc84221eb"
  instance_profile_enabled  = true
  iam_instance_profile_name = module.iam-role.name
  user_data_base64          = ""

  instance_type = "t2.nano"


  # on_dimand
  on_demand_enabled = true
  min_size          = 1
  desired_capacity  = 1
  max_size          = 2

  # schedule_instance
  schedule_enabled = true

  # up
  scheduler_up     = "0 8 * * MON-FRI"
  min_size_scaleup = 2
  scale_up_desired = 2
  max_size_scaleup = 3


  # down
  scheduler_down     = "0 22 * * MON-FRI"
  min_size_scaledown = 1
  scale_down_desired = 1
  max_size_scaledown = 2


  #volumes
  volume_type    = "standard"
  ebs_encryption = false
  kms_key_arn    = ""
  volume_size    = 20

  #Network
  associate_public_ip_address = true
  key_name                    = module.keypair.name
  subnet_ids                  = tolist(module.public_subnets.public_subnet_id)
  load_balancers              = []
  security_group_ids          = [module.ssh.security_group_ids, module.http-https.security_group_ids]
  min_elb_capacity            = 0
  target_group_arns           = []
  health_check_type           = "EC2"


  instance_initiated_shutdown_behavior = "terminate"
  enable_monitoring                    = true
  default_cooldown                     = 150
  force_delete                         = false
  termination_policies                 = ["Default"]
  suspended_processes                  = []
  enabled_metrics                      = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  metrics_granularity                  = "1Minute"
  wait_for_capacity_timeout            = "15m"
  protect_from_scale_in                = false
  service_linked_role_arn              = ""


  scale_up_cooldown_seconds     = 150
  scale_up_scaling_adjustment   = 1
  scale_up_adjustment_type      = "ChangeInCapacity"
  scale_up_policy_type          = "SimpleScaling"
  scale_down_cooldown_seconds   = 300
  scale_down_scaling_adjustment = -1
  scale_down_adjustment_type    = "ChangeInCapacity"
  scale_down_policy_type        = "SimpleScaling"

  cpu_utilization_high_evaluation_periods = 2
  cpu_utilization_high_period_seconds     = 300
  cpu_utilization_high_threshold_percent  = 10
  cpu_utilization_high_statistic          = "Average"
  cpu_utilization_low_evaluation_periods  = 2
  cpu_utilization_low_period_seconds      = 180
  cpu_utilization_low_statistic           = "Average"
  cpu_utilization_low_threshold_percent   = 1
}
