provider "aws" {
  region = local.region
}

locals {
  name                  = "clouddrove"
  region                = "eu-west-1"
  azs                   = ["${local.region}b", "${local.region}c"]
  vpc_cidr_block        = module.vpc.vpc_cidr_block
  additional_cidr_block = "172.16.0.0/16"
  environment           = "test"
  label_order           = ["environment", "name"]
  protocol_tcp          = "tcp"

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
  cidr_block  = "10.0.0.0/16"
  label_order = local.label_order

}

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
}

# ################################################################################
# Security Groups module call
# ################################################################################

module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.3"

  name        = "${local.name}-ssh"
  environment = local.environment
  label_order = local.label_order
  vpc_id      = module.vpc.vpc_id
  new_sg_ingress_rules = [
    {
      key         = "ssh-vpc"
      ip_protocol = local.protocol_tcp
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow ssh traffic."
    },
    {
      key         = "ssh-additional"
      ip_protocol = local.protocol_tcp
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = local.additional_cidr_block
      description = "Allow ssh traffic."
    },
  ]

  ## EGRESS Rules
  #
  # Each 2.x rule takes exactly one source, so one CIDR per entry.
  new_sg_egress_rules = [
    {
      key         = "ssh-out-vpc"
      ip_protocol = local.protocol_tcp
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow ssh outbound traffic."
    },
    {
      key         = "ssh-out-additional"
      ip_protocol = local.protocol_tcp
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
  label_order = local.label_order

  vpc_id = module.vpc.vpc_id
  ## INGRESS Rules
  new_sg_ingress_rules = [
    {
      key         = "ssh"
      ip_protocol = local.protocol_tcp
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow ssh traffic."
    },
    {
      key         = "http"
      ip_protocol = local.protocol_tcp
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow http traffic."
    },
    {
      key         = "https"
      ip_protocol = local.protocol_tcp
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = local.vpc_cidr_block
      description = "Allow https traffic."
    },
  ]

  ## EGRESS Rules
  #
  # 2.x builds one aws_vpc_security_group_egress_rule per entry, and each rule
  # takes exactly one source, so IPv4 and IPv6 are separate entries.
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
  label_order        = local.label_order
  assume_role_policy = data.aws_iam_policy_document.default.json
  policy_enabled     = true
  policy             = data.aws_iam_policy_document.iam-policy.json
}

# https://registry.terraform.io/modules/clouddrove/ec2-autoscaling/aws/latest
module "ec2-autoscale" {
  source = "../../"

  enabled     = true
  name        = local.name
  environment = local.environment

  #Launch template
  image_id                  = "ami-08bac620dc84221eb"
  instance_profile_enabled  = true
  iam_instance_profile_name = module.iam-role.name
  user_data_base64          = ""
  instance_type             = "t2.nano"

  #on_demand
  on_demand_enabled = true
  min_size          = 1
  desired_capacity  = 1
  max_size          = 2
  min_elb_capacity  = 0

  #volumes
  volume_size = 20

  #Network
  associate_public_ip_address = true
  key_name                    = module.keypair.name
  subnet_ids                  = tolist(module.public_subnets.public_subnet_id)
  security_group_ids          = [module.ssh.security_group_id, module.http_https.security_group_id]

}
