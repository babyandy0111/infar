# 建立 Cloud SQL (PostgreSQL)
resource "google_sql_database_instance" "postgres" {
  name             = "infar-db-instance"
  database_version = "POSTGRES_16"
  region           = var.region
  project          = var.project_id
  
  settings {
    # 🚀 將版本設定放在 settings 內部，才能成功套用 db-f1-micro
    edition = "ENTERPRISE"
    tier    = "db-f1-micro" 
    
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = module.gcp_network.network_id
      enable_private_path_for_google_cloud_services = true
    }

    location_preference {
      zone = "${var.region}-a"
    }

    disk_size = 10
    disk_type = "PD_HDD"
  }

  deletion_protection = false

  # 必須等待網路隧道 (Service Networking) 建立完畢
  depends_on = [google_service_networking_connection.default]
}

# 建立 Redis (Memorystore)
resource "google_redis_instance" "redis" {
  name           = "infar-redis"
  tier           = "BASIC"
  memory_size_gb = 1
  region         = var.region
  project        = var.project_id
  authorized_network = module.gcp_network.network_id
  location_id    = "${var.region}-a"
}
