locals {
  name                  = "clouddrove"
  region                = "eu-west-1"
  azs                   = ["${local.region}b", "${local.region}c"]
  additional_cidr_block = "172.16.0.0/16"
  environment           = "test"
  label_order           = ["environment", "name"]
  cidr_block_allow_all  = "0.0.0.0/0"
  protocol_tcp          = "tcp"
}