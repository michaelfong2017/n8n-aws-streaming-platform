# Main Terraform configuration
# This orchestrates all modules to create the streaming platform

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  
  tags = local.common_tags
}

# AWS IVS Channel
module "ivs" {
  source = "./modules/ivs"

  aws_region        = var.aws_region
  project_name      = var.project_name
  environment       = var.environment
  channel_type      = var.ivs_channel_type
  recording_enabled = var.ivs_recording_enabled
  
  tags = local.common_tags
}

# RDS PostgreSQL for n8n
module "rds" {
  source = "./modules/rds"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  instance_class      = var.rds_instance_class
  allocated_storage   = var.rds_allocated_storage
  database_name       = var.rds_database_name
  master_username     = var.rds_username
  
  # Security group for EKS access
  allowed_security_group_ids = [module.eks.node_security_group_id]
  
  tags = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  
  cluster_version     = var.eks_cluster_version
  node_instance_type  = var.eks_node_instance_type
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  
  tags = local.common_tags
}

# Lambda Frame Sampler
module "lambda" {
  source = "./modules/lambda"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  ivs_channel_arn    = module.ivs.channel_arn
  n8n_webhook_url    = "http://${module.eks.n8n_service_endpoint}${var.n8n_webhook_path}"
  
  frame_sample_rate  = var.lambda_frame_sample_rate
  memory_size        = var.lambda_memory_size
  timeout            = var.lambda_timeout
  
  tags = local.common_tags
  
  depends_on = [module.vpc, module.ivs]
}

