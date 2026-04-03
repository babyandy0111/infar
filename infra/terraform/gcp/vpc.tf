module "gcp_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = "infar-gcp-vpc"

  subnets = [
    {
      subnet_name   = "infar-gke-subnet"
      subnet_ip     = "10.10.0.0/16"
      subnet_region = var.region
      # 開啟私人 Google 存取權（無需 NAT Gateway 即可存取 Google 服務，節省大量成本）
      subnet_private_access = "true" 
    }
  ]

  secondary_ranges = {
    "infar-gke-subnet" = [
      {
        range_name    = "gke-pods"
        ip_cidr_range = "10.20.0.0/14" # Pod 的 IP 池 (必須夠大)
      },
      {
        range_name    = "gke-services"
        ip_cidr_range = "10.30.0.0/20" # Service 的 IP 池
      }
    ]
  }
}
