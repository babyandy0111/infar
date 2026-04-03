module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-public-cluster"
  version = "~> 33.0"

  project_id                 = var.project_id
  name                       = var.cluster_name
  region                     = var.region
  network                    = module.gcp_network.network_name
  subnetwork                 = module.gcp_network.subnets_names[0]
  
  # IP 池綁定
  ip_range_pods              = "gke-pods"
  ip_range_services          = "gke-services"

  # 定義這個叢集專屬的服務帳號 (Service Account)
  grant_registry_access      = true
  create_service_account     = true
  service_account_name       = "infar-gke-sa"

  # 防呆機制：關閉叢集刪除保護，讓您在練習 Terraform 時能順利 `terraform destroy`
  deletion_protection        = false

  depends_on = [module.gcp_network]
}
