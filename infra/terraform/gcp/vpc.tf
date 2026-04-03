module "gcp_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = "infar-gcp-vpc"

  subnets = [
    {
      subnet_name           = "infar-gke-subnet"
      subnet_ip             = "10.10.0.0/16"
      subnet_region         = var.region
      subnet_private_access = "true" 
    }
  ]

  secondary_ranges = {
    "infar-gke-subnet" = [
      { range_name = "gke-pods", ip_cidr_range = "10.20.0.0/14" },
      { range_name = "gke-services", ip_cidr_range = "10.30.0.0/20" }
    ]
  }
}

# 🚀 關鍵修復：建立私有服務存取 (Private Service Access) 讓 VPC 能連上 Cloud SQL
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "infar-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.gcp_network.network_id
}

resource "google_service_networking_connection" "default" {
  network                 = module.gcp_network.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}
