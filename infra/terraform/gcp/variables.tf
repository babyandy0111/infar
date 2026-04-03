variable "project_id" {
  description = "GCP Project ID (從環境變數 TF_VAR_project_id 讀取)"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-east1"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "infar-cloud-gke"
}

variable "db_user" {
  description = "Database Username (從環境變數 TF_VAR_db_user 讀取)"
  type        = string
}

variable "db_password" {
  description = "Database Password (從環境變數 TF_VAR_db_password 讀取)"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database Name (從環境變數 TF_VAR_db_name 讀取)"
  type        = string
}
