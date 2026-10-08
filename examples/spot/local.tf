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