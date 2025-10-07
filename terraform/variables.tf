variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "n8n-streaming"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

# IVS Configuration
variable "ivs_channel_type" {
  description = "IVS channel type (STANDARD or BASIC)"
  type        = string
  default     = "BASIC" # BASIC is cheaper for dev
}

variable "ivs_recording_enabled" {
  description = "Enable IVS stream recording"
  type        = bool
  default     = false # Disabled for cost savings
}

# Lambda Configuration
variable "lambda_frame_sample_rate" {
  description = "Frame sampling rate in seconds"
  type        = number
  default     = 5
}

variable "lambda_memory_size" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

# EKS Configuration
variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 1
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 2
}

# RDS Configuration
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_database_name" {
  description = "Database name for n8n"
  type        = string
  default     = "n8n"
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
  default     = "n8nadmin"
}

# n8n Configuration
variable "n8n_min_replicas" {
  description = "Minimum number of n8n pods"
  type        = number
  default     = 1
}

variable "n8n_max_replicas" {
  description = "Maximum number of n8n pods"
  type        = number
  default     = 3
}

variable "n8n_cpu_target" {
  description = "Target CPU utilization percentage for HPA"
  type        = number
  default     = 70
}

variable "n8n_webhook_path" {
  description = "n8n webhook path for Lambda to send frames"
  type        = string
  default     = "/webhook/frame-analysis"
}

