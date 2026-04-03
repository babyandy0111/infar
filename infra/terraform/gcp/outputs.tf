output "kubernetes_endpoint" {
  description = "GKE Cluster Endpoint"
  value       = module.gke.endpoint
}

output "kubernetes_cluster_name" {
  description = "GKE Cluster Name"
  value       = module.gke.name
}

output "configure_kubectl" {
  description = "設定 K8s 本機連線的方法"
  value       = "gcloud container clusters get-credentials ${module.gke.name} --region ${var.region} --project ${var.project_id}"
}
