provider "aws" {
  region = local.region
}

locals {
  name                  = "ec2-autoscaling-multi-type"
  region                = "eu-west-1"
  vpc_cidr_block        = module.vpc.vpc_cidr_block
  additional_cidr_block = "172.16.0.0/16"
  environment           = "test"
}

module "keypair" {
  source  = "clouddrove/keypair/aws"
  version = "1.3.4"

  name               = "${local.name}-key"
  environment        = local.environment
  public_key         = ""
  enable_private_key = true
  enable_key_pair    = true
}

module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "2.0.5"

  name        = "${local.name}-vpc"
  environment = local.environment
  cidr_block  = "10.0.0.0/16"
}

module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "2.0.3"

  name               = "${local.name}-subnet"
  environment        = local.environment
  availability_zones = ["eu-west-1b", "eu-west-1c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
}

################################################################################
# Security Groups module call
################################################################################

module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.3"

  name        = "${local.name}-ssh"
  environment = local.environment
  vpc_id      = module.vpc.vpc_id
  new_sg_ingress_rules = [
    {
      key         = "ssh-vpc"
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow ssh traffic."
    },
    {
      key         = "ssh-additional"
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = local.additional_cidr_block
      description = "Allow ssh traffic."
    },
  ]

  new_sg_egress_rules = [
    {
      key         = "ssh-out-vpc"
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow ssh outbound traffic."
    },
    {
      key         = "ssh-out-additional"
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = local.additional_cidr_block
      description = "Allow ssh outbound traffic."
    },
  ]
}

#tfsec:ignore:aws-ec2-no-public-egress-sgr
module "http_https" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.3"

  name        = "${local.name}-http-https"
  environment = local.environment

  vpc_id = module.vpc.vpc_id
  new_sg_ingress_rules = [
    {
      key         = "ssh"
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow ssh traffic."
    },
    {
      key         = "http"
      ip_protocol = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow http traffic."
    },
    {
      key         = "https"
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow https traffic."
    },
  ]

  new_sg_egress_rules = [
    {
      key         = "all-ipv4"
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all ipv4 traffic."
    },
    {
      key         = "all-ipv6"
      ip_protocol = "-1"
      cidr_ipv6   = "::/0"
      description = "Allow all ipv6 traffic."
    },
  ]
}

module "iam-role" {
  source  = "clouddrove/iam-role/aws"
  version = "1.4.0"

  name               = "${local.name}-iam-role"
  environment        = local.environment
  assume_role_policy = data.aws_iam_policy_document.default.json
  policy_enabled     = true
  policy             = data.aws_iam_policy_document.iam-policy.json
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
  name        = "${local.name}-test"
  environment = local.environment

  #Launch template
  image_id                  = "ami-08bac620dc84221eb"
  instance_profile_enabled  = true
  iam_instance_profile_name = module.iam-role.name
  user_data_base64          = ""

  instance_type = "t3.micro"

  # on_demand
  on_demand_enabled = true
  min_size          = 1
  desired_capacity  = 2
  max_size          = 4

  #Multiple instance types
  mixed_instances_policy_enabled = true

  mixed_instances_overrides = [
    { instance_type = "t3.micro", weighted_capacity = "1" },
    { instance_type = "t3a.micro", weighted_capacity = "1" },
    { instance_type = "t2.micro", weighted_capacity = "1" },
  ]

  mixed_instances_distribution = {
    on_demand_base_capacity                  = 1
    on_demand_percentage_above_base_capacity = 25
    on_demand_allocation_strategy            = "lowest-price"
    spot_allocation_strategy                 = "price-capacity-optimized"
  }

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
  security_group_ids          = [module.ssh.security_group_id, module.http_https.security_group_id]
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
