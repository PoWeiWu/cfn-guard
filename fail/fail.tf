provider "aws" {
  region = "us-east-1"
}

resource "random_id" "random_bucket_name" {
  byte_length = 4
}

data "aws_ssm_parameter" "amz_linux" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid       = "AllowFullS3Access"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "paul-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["ap-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    createBy = "terraform"
    env      = "dev"
  }

}

module "web-sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "web-server-sg"
  description = "sg for web server"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "for http connect"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "for ssh connect"
    }
  ]
}

module "s3_iam_policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "s3-policy"
  path        = "/"
  description = "for s3 policy"

  policy = data.aws_iam_policy_document.bucket_policy.json

  tags = {
    createBy    = "Terraform"
    Env         = "dev"
    policy-desc = "Policy created using example from data source"
  }

}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "dev-cathay-app-${random_id.random_bucket_name.hex}"
  acl    = "private"

  versioning = {
    enabled = true
  }

  tags = {
    createBy = "Terraform"
  }

}

module "web-server" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name                   = "dev-web"
  ami                    = data.aws_ssm_parameter.amz_linux.value
  vpc_security_group_ids = [module.web-sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  instance_type          = "t2.micro"
  tags = {
    createBy = "terraform"
    Env      = "dev"
  }
}

module "ap-server" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name                   = "dev-ap"
  ami                    = data.aws_ssm_parameter.amz_linux.value
  vpc_security_group_ids = [module.web-sg.security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  instance_type          = "t2.large"
  tags = {
    createBy = "terraform"
    Env      = "dev"
  }
}