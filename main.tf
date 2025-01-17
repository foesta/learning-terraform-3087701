data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

module "web_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]


  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


module "web_sg" {
  source = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  name = "web_new"

  vpc_id = module.web_vpc.vpc_id
  
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}


module "web_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = "web-alb"

  load_balancer_type = "application"

  vpc_id             = module.web_vpc.vpc_id
  subnets            = module.web_vpc.public_subnets
  security_groups    = [module.web_sg.security_group_id]


  target_groups = [
    {
      name_prefix      = "web"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "dev"
  }
}

module "autoscaling" {
  source = "terraform-aws-modules/autoscaling/aws"
  version = "6.5.2"

  name = "web"
  min_size = 1
  max_size = 2

  vpc_zone_identifier = module.web_vpc.public_subnets
  target_group_arns = module.web_alb.target_group_arns
  security_groups     = [module.web_sg.security_group_id]
  instance_type       = var.instance_type
  image_id            = data.aws_ami.app_ami.id
}
