variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "channel_type" {
  description = "IVS channel type (STANDARD or BASIC)"
  type        = string
  default     = "BASIC"
  
  validation {
    condition     = contains(["STANDARD", "BASIC"], var.channel_type)
    error_message = "Channel type must be either STANDARD or BASIC"
  }
}

variable "recording_enabled" {
  description = "Enable stream recording to S3"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

