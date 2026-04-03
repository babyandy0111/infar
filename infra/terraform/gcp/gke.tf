resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # 🚀 直接開啟 Autopilot
  enable_autopilot = true

  network    = module.gcp_network.network_id
  subnetwork = module.gcp_network.subnets_names[0]

  # 設定釋放頻道，穩定性較高
  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # 移除預設節點池的保護
  deletion_protection = false

  depends_on = [module.gcp_network]
}

# 建立服務帳號給叢集使用
resource "google_service_account" "infar_sa" {
  account_id   = "infar-gke-sa"
  display_name = "Infar GKE Service Account"
  project      = var.project_id
}
