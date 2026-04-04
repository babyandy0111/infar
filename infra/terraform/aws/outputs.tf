output "kubernetes_cluster_name" {
  value = var.cluster_name
}

output "configure_kubectl" {
  description = "設定 K8s 本機連線的方法"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}"
}

output "db_endpoint" {
  # RDS 產出的 endpoint 格式通常是 host:port，我們只需要 host
  value = split(":", aws_db_instance.postgres.endpoint)[0]
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}
