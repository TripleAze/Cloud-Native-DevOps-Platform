output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = module.acm.acm_certificate_arn
}

output "route53_zone_name" {
  description = "Route53 zone name"
  value       = data.aws_route53_zone.primary.name
}

