output "cluster_id" {
  description = "EKS cluster ID - only available for local Amazon EKS cluster on the AWS Outpost. Not available for an AWS EKS cluster on AWS cloud"
  value       = module.eks.cluster_id
}

output "host" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "ca_certificate" {
  description = "Cluster certificate"
  value       = module.eks.cluster_certificate_authority_data
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluser_name
}

