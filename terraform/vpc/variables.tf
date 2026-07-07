variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "The GCP Region"
}

variable "vpc_name" {
  type        = string
  default     = "prod-vpc"
  description = "Name of the VPC network"
}

variable "web_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR range for Web Tier private subnet"
}

variable "app_subnet_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "CIDR range for App Tier private subnet"
}

variable "db_subnet_cidr" {
  type        = string
  default     = "10.0.3.0/24"
  description = "CIDR range for DB Tier private subnet"
}
