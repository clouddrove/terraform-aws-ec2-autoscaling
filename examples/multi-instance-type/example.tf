provider "aws" {
  region = local.region
}

locals {
  name                  = "ec2-autoscaling-multi-type"
  region                = "eu-west-1"
  azs                   = ["${local.region}b", "${local.region}c"]
  additional_cidr_block = "172.16.0.0/16"
  environment           = "test"
  label_order           = ["environment", "name"]
}

module "keypair" {
  source  = "clouddrove/keypair/aws"
  version = "1.3.4"

  name               = "${local.name}-key"
  environment        = local.environment
  label_order        = local.label_order
  public_key         = ""
  enable_private_key = true
  enable_key_pair    = true
}

module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "2.0.5"

  name        = "${local.name}-vpc"
  environment = local.environment
  label_order = local.label_order
  cidr_block  = "10.0.0.0/16"
}

#tfsec:ignore:aws-ec2-no-public-ingress-acl
module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "2.0.3"

  name               = "${local.name}-subnet"
  environment        = local.environment
  label_order        = local.label_order
  availability_zones = local.azs
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block

  public_inbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_block  = module.vpc.vpc_cidr_block
    },
    {
      rule_number = 110
      rule_action = "allow"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
    },
    {
      rule_number = 120
      rule_action = "allow"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
    },
    {
      rule_number = 130
      rule_action = "allow"
      from_port   = 1024
      to_port     = 65535
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
      description = "Ephemeral ports for return traffic"
    },
  ]

  public_outbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
    },
    {
      rule_number = 110
      rule_action = "allow"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
    },
    {
      rule_number = 120
      rule_action = "allow"
      from_port   = 1024
      to_port     = 65535
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
      description = "Ephemeral ports for replies to inbound connections"
    },
  ]
}

################################################################################
# Security Groups module call
################################################################################

module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.3"

  name           = "${local.name}-ssh"
  environment    = local.environment
  label_order    = local.label_order
  vpc_id         = module.vpc.vpc_id
  sg_description = "Allows SSH access from the VPC and an additional trusted CIDR block."
  new_sg_ingress_rules = [
    {
      key         = "ssh-vpc"
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = module.vpc.vpc_cidr_block
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
      cidr_ipv4   = module.vpc.vpc_cidr_block
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

  name           = "${local.name}-http-https"
  label_order    = local.label_order
  environment    = local.environment
  sg_description = "Allows inbound SSH/HTTP/HTTPS from the VPC and unrestricted outbound traffic."

  vpc_id = module.vpc.vpc_id
  new_sg_ingress_rules = [
    {
      key         = "ssh"
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = module.vpc.vpc_cidr_block
      description = "Allow ssh traffic."
    },
    {
      key         = "http"
      ip_protocol = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = module.vpc.vpc_cidr_block
      description = "Allow http traffic."
    },
    {
      key         = "https"
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = module.vpc.vpc_cidr_block
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

module "iam_role" {
  source  = "clouddrove/iam-role/aws"
  version = "1.4.0"

  name               = "${local.name}-iam-role"
  environment        = local.environment
  label_order        = local.label_order
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

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.18-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "ec2_autoscale" {
  source = "../../"

  enabled     = true
  name        = local.name
  environment = local.environment
  label_order = local.label_order

  #Launch template
  image_id                  = data.aws_ami.ami.id
  instance_profile_enabled  = true
  iam_instance_profile_name = module.iam_role.name
  user_data_base64          = ""

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
  security_group_ids          = [module.ssh.security_group_id, module.http_https.security_group_id]
  min_elb_capacity            = 0

  #monitoring
  enable_monitoring = false

}
