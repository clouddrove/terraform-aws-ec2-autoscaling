provider "aws" {
  region = local.region
}

locals {
  name                  = "ec2-autoscaling"
  region                = "eu-west-1"
  vpc_cidr_block        = module.vpc.vpc_cidr_block
  additional_cidr_block = "172.16.0.0/16"
  environment           = "test"
}

module "keypair" {
  source  = "clouddrove/keypair/aws"
  version = "1.3.1"

  name        = "${local.name}-key"
  environment = local.environment
  label_order = ["environment", "name"]

  public_key                 = ""
  create_private_key_enabled = true
  enable_key_pair            = true

}

module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "2.0.0"

  name        = "${local.name}-vpc"
  environment = local.environment
  label_order = ["environment", "name"]
  cidr_block  = "10.0.0.0/16"
}

module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "2.0.0"

  name               = "${local.name}-subnet"
  environment        = local.environment
  availability_zones = ["eu-west-1b", "eu-west-1c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
}

# ################################################################################
# Security Groups module call
################################################################################

module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.0"

  name        = "${local.name}-ssh"
  environment = local.environment
  vpc_id      = module.vpc.vpc_id
  new_sg_ingress_rules_with_cidr_blocks = [{
    rule_count  = 1
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = [local.vpc_cidr_block, local.additional_cidr_block]
    description = "Allow ssh traffic."
    }
  ]

  ## EGRESS Rules
  new_sg_egress_rules_with_cidr_blocks = [{
    rule_count  = 1
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = [local.vpc_cidr_block, local.additional_cidr_block]
    description = "Allow ssh outbound traffic."
    }
  ]
}

#tfsec:ignore:aws-ec2-no-public-egress-sgr
module "http_https" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.0"

  name        = "${local.name}-http-https"
  environment = local.environment
  vpc_id      = module.vpc.vpc_id
  ## INGRESS Rules
  new_sg_ingress_rules_with_cidr_blocks = [{
    rule_count  = 1
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = [local.vpc_cidr_block]
    description = "Allow ssh traffic."
    },
    {
      rule_count  = 2
      from_port   = 80
      protocol    = "tcp"
      to_port     = 80
      cidr_blocks = [local.vpc_cidr_block]
      description = "Allow http traffic."
    },
    {
      rule_count  = 3
      from_port   = 443
      protocol    = "tcp"
      to_port     = 443
      cidr_blocks = [local.vpc_cidr_block]
      description = "Allow https traffic."
    }
  ]

  ## EGRESS Rules
  new_sg_egress_rules_with_cidr_blocks = [{
    rule_count       = 1
    from_port        = 0
    protocol         = "-1"
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow all traffic."
    }
  ]
}

module "iam-role" {
  source  = "clouddrove/iam-role/aws"
  version = "1.3.0"

  name               = "${local.name}-iam-role"
  environment        = local.environment
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

  enabled                   = true
  name                      = "${local.name}-test"
  environment               = local.environment
  image_id                  = "ami-0ab040d0c6b04cf83"
  instance_profile_enabled  = true
  iam_instance_profile_name = module.iam-role.name

  security_group_ids = [module.ssh.security_group_id, module.http_https.security_group_id]
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
