provider "aws" {
  region = local.region
}


locals {
  name        = "ec2-autoscaling"
  region      = "us-east-1"
  environment = "test"
  label_order = ["environment", "name"]

  vpc_cidr_block        = module.vpc.vpc_cidr_block
  additional_cidr_block = "172.16.0.0/16"
  os_name               = "ubuntu"
  architecture_type     = "x86_64"
}

data "aws_ami" "any" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["*${local.os_name}*"]
  }
  filter {
    name   = "architecture"
    values = [local.architecture_type]
  }
}

##----------------------------------------------------
## AWS Security Group Module 
##----------------------------------------------------
module "ec2-autoscale" {
  source = "../../../"

  enabled     = true
  name        = "${local.name}-test"
  environment = local.environment
  label_order = local.label_order

  #Launch template
  instance_profile_enabled  = true
  iam_instance_profile_name = module.iam-role.name
  image_id                  = data.aws_ami.any.id
  instance_type             = "t2.nano"


  # on_dimand
  on_demand_enabled = true
  min_size          = 1
  desired_capacity  = 1
  max_size          = 1

  #volumes
  volume_type = "standard"
  volume_size = 30

  #Network
  associate_public_ip_address = true
  key_name                    = module.keypair.name
  subnet_ids                  = tolist(module.public_subnets.public_subnet_id)
  security_group_ids          = [module.ssh.security_group_id, module.http_https.security_group_id]
}

##----------------------------------------------------
## AWS KeyPair Module 
##----------------------------------------------------

module "keypair" {
  source  = "clouddrove/keypair/aws"
  version = "1.3.1"

  name        = "${local.name}-key"
  environment = local.environment
  label_order = local.label_order

  public_key                 = ""
  create_private_key_enabled = true
  enable_key_pair            = true
}

##----------------------------------------------------
## AWS VPC Module 
##----------------------------------------------------

module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "2.0.0"

  name        = "${local.name}-vpc"
  environment = local.environment
  label_order = local.label_order
  cidr_block  = "10.0.0.0/16"
}

##----------------------------------------------------
## AWS Subnet Module 
##----------------------------------------------------
#tfsec:ignore:aws-ec2-no-excessive-port-access 
#tfsec:ignore:aws-ec2-no-public-ingress-acl
module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "2.0.1"

  name        = "${local.name}-subnet"
  environment = local.environment
  label_order = local.label_order

  nat_gateway_enabled = true
  single_nat_gateway  = true
  availability_zones  = ["${local.region}a", "${local.region}b", "${local.region}c"]
  vpc_id              = module.vpc.vpc_id
  cidr_block          = module.vpc.vpc_cidr_block
  type                = "public-private"
  igw_id              = module.vpc.igw_id
  ipv6_cidr_block     = module.vpc.ipv6_cidr_block

  private_inbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = module.vpc.vpc_cidr_block
    }
  ]
  private_outbound_acl_rules = [
    {
      rule_number = 100
      rule_action = "allow"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_block  = module.vpc.vpc_cidr_block
    }
  ]
}

##----------------------------------------------------
## AWS Security Group Module 
##----------------------------------------------------

module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.0"

  name        = "${local.name}-ssh"
  environment = local.environment
  label_order = local.label_order

  vpc_id = module.vpc.vpc_id
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
  }]
}

#tfsec:ignore:aws-ec2-no-public-egress-sgr
module "http_https" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.0"

  name        = "${local.name}-http-https"
  environment = local.environment
  label_order = local.label_order

  vpc_id = module.vpc.vpc_id
  ## INGRESS Rules
  new_sg_ingress_rules_with_cidr_blocks = [{
    rule_count  = 1
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = [module.vpc.vpc_cidr_block]
    description = "Allow ssh traffic."
    }
  ]

  ## EGRESS Rules
  new_sg_egress_rules_with_cidr_blocks = [{
    rule_count  = 1
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = [module.vpc.vpc_cidr_block]
    description = "Allow all traffic."
    }
  ]
}

##----------------------------------------------------
## AWS IAM Role Module 
##----------------------------------------------------

module "iam-role" {
  source  = "clouddrove/iam-role/aws"
  version = "1.3.3"

  name        = "${local.name}-iam-role"
  environment = local.environment
  label_order = local.label_order

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


