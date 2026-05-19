module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1 # for alb controller to identify where to create alb
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1 # for alb controller to identify where to create internal alb
  }
  tags = {
    Name = "solo-devops-vpc"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access  = true
  endpoint_private_access = true

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  tags = {
    environment = var.environment
    project     = var.project
  }
}


module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name                              = "aws-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Route53 Zone
data "aws_route53_zone" "primary" {
  name = var.domain_name
}

# Generate SSL Cert using the standard module
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 5.0"

  domain_name = data.aws_route53_zone.primary.name
  zone_id     = data.aws_route53_zone.primary.zone_id

  # Validates the cert automatically via Route 53
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${data.aws_route53_zone.primary.name}",
  ]

  wait_for_validation = true
}

module "ecr" {
  source   = "terraform-aws-modules/ecr/aws"
  for_each = toset(var.ecr_names)

  repository_name = each.key

  repository_image_scan_on_push   = var.ecr_scan_on_push
  repository_lifecycle_policy     = var.ecr_lifecycle_policy
  repository_image_tag_mutability = "MUTABLE"

  tags = var.ecr_tags
}


resource "aws_security_group_rule" "ingress_load_balancer" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = module.eks.cluster_primary_security_group_id
  description       = "Allow ALB to talk to Pods on port 80"
}

resource "aws_security_group_rule" "ingress_load_balancer_api" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = module.eks.cluster_primary_security_group_id
  description       = "Allow ALB to talk to Pods on port 8080"
}
