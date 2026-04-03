module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-public-cluster"
  version = "~> 33.0"

  project_id                 = var.project_id
  name                       = var.cluster_name
  region                     = var.region
  network                    = module.gcp_network.network_name
  subnetwork                 = module.gcp_network.subnets_names[0]
  
  # IP 池綁定 (我們剛在 vpc.tf 裡設定的)
  ip_range_pods              = "gke-pods"
  ip_range_services          = "gke-services"

  # 開啟這行，整個叢集就是 100% 的 Serverless (無需管理 Node)
  enable_autopilot           = true
  
  # 允許叢集擁有 Public Endpoint 以便我們本機用 kubectl 操作
  # 在極高機密的專案中，這裡會設為 false 並透過跳板機 (Bastion Host) 連線
  enable_private_endpoint    = false
  enable_private_nodes       = true
  master_ipv4_cidr_block     = "172.16.0.0/28" # 這是給 Google Control Plane 用的 IP

  # 定義這個叢集專屬的服務帳號 (Service Account)
  # GCP 推薦這種作法，以便未來的微服務可以綁定特定的 GCP 權限 (如存取 Cloud SQL 或 Pub/Sub)
  create_service_account     = true
  service_account_name       = "infar-gke-sa"

  # 防呆機制：關閉叢集刪除保護，讓您在練習 Terraform 時能順利 `terraform destroy`
  deletion_protection        = false

  depends_on = [module.gcp_network]
}
