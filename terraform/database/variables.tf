variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "The GCP Region"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the custom VPC network"
}

variable "vpc_name" {
  type        = string
  description = "The name of the custom VPC network"
}

variable "db_instance_name" {
  type        = string
  default     = "uat-postgres"
  description = "Name of the SQL Database Instance"
}

variable "db_name" {
  type        = string
  default     = "ai_email_manager"
  description = "Database name"
}

variable "db_user" {
  type        = string
  default     = "postgres"
  description = "Database username"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database password"
}
