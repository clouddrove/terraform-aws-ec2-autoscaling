provider "aws" {
  region = "eu-west-1"
}

module "keypair" {
  source  = "clouddrove/keypair/aws"
  version = "0.14.0"

  key_path        = "~/.ssh/id_rsa.pub"
  repository      = "git::https://github.com/clouddrove/terraform-aws-keypair.git?ref=tags/0.14.0"
  key_name        = "devops"
  enable_key_pair = true
  environment     = "test"

}

module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "0.14.0"

  name        = "vpc"
  repository  = "git::https://github.com/clouddrove/terraform-aws-vpc.git?ref=tags/0.14.0"
  environment = "test"
  label_order = ["environment", "name"]

  cidr_block = "172.16.0.0/16"
}

module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "0.14.0"

  name        = "public-subnet"
  repository  = "https://registry.terraform.io/modules/clouddrove/subnet/aws/0.14.0"
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
  version = "0.14.0"

  name        = "http-https"
  repository  = "git::https://github.com/clouddrove/terraform-aws-security-group.git?ref=tags/0.14.0"
  environment = "test"
  label_order = ["environment", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = ["0.0.0.0/0"]
  allowed_ports = [80, 443]
}

module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "0.14.0"

  name        = "ssh"
  repository  = "git::https://github.com/clouddrove/terraform-aws-security-group.git?ref=tags/0.14.0"
  environment = "test"
  label_order = ["environment", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block, "0.0.0.0/0"]
  allowed_ports = [22]
}

module "ec2-autoscale" {
  source = "../../"

  enabled     = true
  name        = "ec2"
  environment = "test"
  label_order = ["environment", "name"]

  image_id = "ami-0ceab0713d94f9276"
  iam_instance_profile_name = ""
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
  wait_for_capacity_timeout               = "10m"
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