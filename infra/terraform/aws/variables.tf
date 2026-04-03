variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-1" # 東京區域，延遲較低
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "infar-cloud-eks"
}
