# Terraform Outputs

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# IVS Outputs
output "ivs_channel_arn" {
  description = "IVS Channel ARN"
  value       = module.ivs.channel_arn
}

output "ivs_ingest_endpoint" {
  description = "IVS Ingest Endpoint for OBS"
  value       = module.ivs.ingest_endpoint
}

output "ivs_stream_key" {
  description = "IVS Stream Key for OBS (SENSITIVE)"
  value       = module.ivs.stream_key
  sensitive   = true
}

output "ivs_playback_url" {
  description = "IVS Playback URL"
  value       = module.ivs.playback_url
}

# EKS Outputs
output "eks_cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster Endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS Cluster Security Group ID"
  value       = module.eks.cluster_security_group_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS Endpoint"
  value       = module.rds.endpoint
}

output "rds_database_name" {
  description = "RDS Database Name"
  value       = module.rds.database_name
}

output "rds_password_secret_arn" {
  description = "ARN of Secrets Manager secret containing RDS password"
  value       = module.rds.password_secret_arn
}

# Lambda Outputs
output "lambda_function_name" {
  description = "Lambda Function Name"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "Lambda Function ARN"
  value       = module.lambda.function_arn
}

# Setup Instructions
output "setup_instructions" {
  description = "Setup instructions"
  value = <<-EOT
  
  ╔════════════════════════════════════════════════════════════════════╗
  ║         n8n AWS Streaming Platform - Setup Complete! 🎉           ║
  ╚════════════════════════════════════════════════════════════════════╝
  
  📡 OBS STREAMING SETUP:
  ─────────────────────────────────────────────────────────────────────
  Server URL: ${module.ivs.ingest_endpoint}
  Stream Key: Run 'terraform output -raw ivs_stream_key' to get key
  
  🎬 PLAYBACK URL:
  ─────────────────────────────────────────────────────────────────────
  ${module.ivs.playback_url}
  
  ☸️  KUBERNETES SETUP:
  ─────────────────────────────────────────────────────────────────────
  1. Configure kubectl:
     aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
  
  2. Get RDS password:
     aws secretsmanager get-secret-value --region ${var.aws_region} --secret-id ${module.rds.password_secret_arn} --query SecretString --output text
  
  3. Deploy n8n:
     cd kubernetes
     kubectl apply -f n8n-namespace.yaml
     kubectl apply -f n8n-secret.yaml    # Update with RDS password first!
     kubectl apply -f n8n-deployment.yaml
     kubectl apply -f n8n-service.yaml
     kubectl apply -f n8n-hpa.yaml
  
  4. Get n8n Load Balancer URL:
     kubectl get svc n8n-service -n n8n
  
  💰 COST ESTIMATE (ap-southeast-1):
  ─────────────────────────────────────────────────────────────────────
  - IVS BASIC: ~$1.50/hour when streaming
  - EKS Control Plane: ~$73/month
  - t3.medium node: ~$33/month
  - RDS t4g.micro: ~$12/month
  - Lambda + NAT: ~$5-10/month
  Total: ~$123-128/month + streaming hours
  
  EOT
}


output "eks_alb_controller_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  value       = module.eks.aws_load_balancer_controller_role_arn
}
