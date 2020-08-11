provider "aws" {
  region = "eu-west-1"
}

module "keypair" {
  source = "git::https://github.com/clouddrove/terraform-aws-keypair.git?ref=tags/0.12.2"

  key_path        = "~/.ssh/id_rsa.pub"
  key_name        = "devops"
  enable_key_pair = true
}

module "vpc" {
  source = "git::https://github.com/clouddrove/terraform-aws-vpc.git?ref=tags/0.12.4"

  name        = "vpc"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  cidr_block = "172.16.0.0/16"
}

module "public_subnets" {
  source = "git::https://github.com/clouddrove/terraform-aws-subnet.git?ref=tags/0.12.4"

  name        = "public-subnet"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  availability_zones = ["eu-west-1b", "eu-west-1c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
}

module "http-https" {
  source = "git::https://github.com/clouddrove/terraform-aws-security-group.git?ref=tags/0.12.3"

  name        = "http-https"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = ["0.0.0.0/0"]
  allowed_ports = [80, 443]
}

module "ssh" {
  source = "git::https://github.com/clouddrove/terraform-aws-security-group.git?ref=tags/0.12.3"

  name        = "ssh"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block, "0.0.0.0/0"]
  allowed_ports = [22]
}

module "ec2-autoscale" {
  source = "../../"

  enabled     = true
  name        = "ec2"
  application = "clouddrove"
  environment = "test"
  label_order = ["application", "environment", "name"]

  #Launch template
  image_id                  = "ami-0ceab0713d94f9276"
  iam_instance_profile_name = "test-moneyceo-ec2-instance-instance-profile"
  user_data_base64          = ""

  instance_type                           = "t2.nano"


  # on_dimand
  on_demand_enabled                       = true
  min_size                                = 1
  desired_capacity                        = 1
  max_size                                = 2

  # schedule_instance
  schedule_enabled                        = true

    # up
  scheduler_up                            = "0 8 * * MON-FRI"
  min_size_scaleup                        = 2
  scale_up_desired                        = 2
  max_size_scaleup                        = 3


  # down
  scheduler_down                          = "0 22 * * MON-FRI"
  min_size_scaledown                      = 1
  scale_down_desired                      = 1
  max_size_scaledown                      = 2


  #volumes
  volume_type                             = "standard"
  ebs_encryption                          = false
  kms_key_arn                             = ""
  volume_size                             = 20

  #Network
  associate_public_ip_address             = true
  key_name                                = module.keypair.name
  subnet_ids                              = tolist(module.public_subnets.public_subnet_id)
  load_balancers                          = []
  security_group_ids                      = [module.ssh.security_group_ids, module.http-https.security_group_ids]
  min_elb_capacity                        = 0
  target_group_arns                       = []
  health_check_type                       = "EC2"


  instance_initiated_shutdown_behavior    = "terminate"
  enable_monitoring                       = true
  default_cooldown                        = 150
  force_delete                            = false
  termination_policies                    = ["Default"]
  suspended_processes                     = []
  enabled_metrics                         = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  metrics_granularity                     = "1Minute"
  wait_for_capacity_timeout               = "15m"
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