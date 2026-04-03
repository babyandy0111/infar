# 建立 Cloud SQL (PostgreSQL)
resource "google_sql_database_instance" "postgres" {
  name             = "infar-db-instance"
  database_version = "POSTGRES_16"
  region           = var.region
  project          = var.project_id
  
  edition = "ENTERPRISE"
  
  settings {
    tier = "db-f1-micro" 
    
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
  depends_on = [google_service_networking_connection.default]
}

# 🚀 新增：自動建立資料庫 (Database)
resource "google_sql_database" "infar_db" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

# 🚀 新增：自動建立使用者 (User) 並賦予密碼
resource "google_sql_user" "infar_user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
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
