variable "project_id" {
  description = "GCP Project ID"
  type        = string
  # 請在此填入您的 GCP 專案 ID
  default     = "your-gcp-project-id" 
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-east1" # 台灣彰化機房
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "infar-cloud-gke"
}
