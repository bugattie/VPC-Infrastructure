variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_name" {
  type    = string
  default = "demo_vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  default = {
    "public_subnet_0" = 0
    "public_subnet_1" = 1
  }
}

variable "private_subnets" {
  default = {
    "private_subnet_0" = 0
    "private_subnet_1" = 1
  }
}
