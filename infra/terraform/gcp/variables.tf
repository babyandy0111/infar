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
