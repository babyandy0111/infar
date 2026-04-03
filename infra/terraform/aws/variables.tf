variable "region" {
  description = "AWS Region (從環境變數 TF_VAR_region 讀取)"
  type        = string
}

variable "cluster_name" {
  description = "EKS Cluster Name (從環境變數 TF_VAR_cluster_name 讀取)"
  type        = string
}
