provider "aws" {
  region = "eu-west-1"
}

module "keypair" {
  source  = "clouddrove/keypair/aws"
  version = "0.15.0"

  public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDMw9taDn3K84VTc8hA4Sm+tCmh6pg53eSeIvHpJoH5VN917JHNcDf/C8rA0bl6RrRpmDXieA5313Br3UP5qXZSebyRA+WcXtxB8zk9xntliwXU+GpX4WCMcCPLgDkUbbmKInESoH2DFnqgfxyWQaOYZJ2W7/6Aa17qTtrT04FdQel2jdNGjp7BwjHFJxAiSUbDuJPFjZUoEATpryUyT4opAQh7lo/ZwSxrH6wPSGAC0npp/hiJ8/PN2zpFbVJBlHXX96bCGfYQUC013xN54z4HmElGTCtC45SGQ766lmGiIRfxUh/EprjrCQ/u0yOidz1l/eed/CruKss2Vzgd9CnA4tB/3UhsAnEZoTz2Qb4NnWIdHZC8kKIlAumQxLEb/yukofdO0JEGi07LsgwRx1gDcESFzcfnHHNXMybrPU3YrOPI9x22QHt5ufmeZTw3zqIsm7plxhUlhwaIEOzKLjZC9Y9L6FAulz0uMKsOdDqXKAkrujI6/cgxHqUZ8oq8t8E= prashant@prashant"
  key_name        = "devops1"
  environment     = "test"
  enable_key_pair = true
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

  name               = "clouddrove1"
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
