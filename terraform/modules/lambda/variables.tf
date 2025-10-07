variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda"
  type        = list(string)
}

variable "ivs_channel_arn" {
  description = "ARN of IVS channel"
  type        = string
}

variable "n8n_webhook_url" {
  description = "n8n webhook URL for sending frame data"
  type        = string
}

variable "frame_sample_rate" {
  description = "Frame sampling rate in seconds"
  type        = number
  default     = 5
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

