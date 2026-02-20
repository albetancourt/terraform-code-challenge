terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.50"
    }
  }
  required_version = ">= 1.8.0"
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# ------------------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------------------

resource "google_compute_network" "main" {
  name                    = "${local.project_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "app" {
  name          = "${local.project_name}-app-subnet"
  ip_cidr_range = local.app_subnet_cidr
  region        = local.region
  network       = google_compute_network.main.id
}

resource "google_compute_subnetwork" "db" {
  name          = "${local.project_name}-db-subnet"
  ip_cidr_range = local.db_subnet_cidr
  region        = local.region
  network       = google_compute_network.main.id
}

# ------------------------------------------------------------------------------
# GKE Cluster
# ------------------------------------------------------------------------------

resource "google_container_cluster" "primary" {
  name     = "${local.project_name}-gke-cluster"
  location = local.region

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.app.id

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false
}

resource "google_container_node_pool" "app_nodes" {
  name       = "${local.project_name}-node-pool"
  location   = local.region
  cluster    = google_container_cluster.primary.name

  node_count = 2

  node_config {
    machine_type    = local.machine_type
    service_account = google_service_account.gke.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = local.environment
      app         = $local.project_name-nodes
    }
  }
}

# ------------------------------------------------------------------------------
# Zonal Node Pools
# ------------------------------------------------------------------------------

resource "google_container_node_pool" "extra_pools" {
  for_each = local.zones

  name       = "${local.project_name}-pool-${each.key}"
  location   = each.key
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type    = "e2-small"
    service_account = google_service_account.gke.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# ------------------------------------------------------------------------------
# Service Accounts
# ------------------------------------------------------------------------------

resource "google_service_account" "gke" {
  account_id   = "${local.project_name}-gke-sa"
  display_name = "GKE Node Pool Service Account"
}

resource "google_service_account" "api" {
  account_id   = "${local.project_name}-api-sa"
  display_name = "API Service Account"
}

resource "google_service_account" "frontend" {
  account_id   = "${local.project_name}-frontend-sa"
  display_name = "Frontend Service Account"
}

resource "google_service_account" "scheduler" {
  account_id   = "${local.project_name}-scheduler-sa"
  display_name = "Scheduler Service Account"
}

resource "google_project_iam_member" "gke_log_writer" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.gke.member
}

resource "google_project_iam_member" "gke_metric_writer" {
  project = local.project_id
  role    = "roles/monitoring.metricWriter"
  member  = google_service_account.gke.member
}

resource "google_project_iam_member" "api_log_writer" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.api.member
}

resource "google_project_iam_member" "api_cloudsql_client" {
  project = local.project_id
  role    = "roles/cloudsql.client"
  member  = google_service_account.api.member
}

resource "google_project_iam_member" "api_storage_writer" {
  project = local.project_id
  role    = "roles/storage.objectCreator"
  member  = google_service_account.api.member
}

resource "google_project_iam_member" "frontend_log_writer" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.frontend.member
}

# ------------------------------------------------------------------------------
# Cloud Run Services
# ------------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "api" {
  name     = "${local.project_name}-api"
  location = local.region

  template {
    containers {
      image = "${local.region}-docker.pkg.dev/${local.project_id}/${local.project_name}/${local.project_name}-api:latest"

      env {
        name  = "DB_CONNECTION"
        value = google_sql_database_instance.main.connection_name
      }

      env {
        name  = "DB_PASSWORD"
        value = "changeme123"
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }
    }

    service_account = google_service_account.api.email
  }
}

resource "google_cloud_run_v2_service" "frontend" {
  name     = "${local.project_name}-frontend"
  location = local.region

  template {
    containers {
      image = "${local.region}-docker.pkg.dev/${local.project_id}/${local.project_name}/${local.project_name}-frontend:latest"

      env {
        name  = "API_URL"
        value = google_cloud_run_v2_service.api.uri
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "256Mi"
        }
      }
    }

    service_account = google_service_account.frontend.email
  }
}

resource "google_cloud_run_v2_service_iam_member" "frontend_public" {
  name     = google_cloud_run_v2_service.frontend.name
  location = local.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "scheduler_invoker" {
  name     = google_cloud_run_v2_service.api.name
  location = local.region
  role     = "roles/run.invoker"
  member   = google_service_account.scheduler.member
}

# ------------------------------------------------------------------------------
# Cloud Scheduler
# ------------------------------------------------------------------------------

resource "google_cloud_scheduler_job" "report_generation" {
  name     = "${local.project_name}-report"
  region   = local.region
  schedule = "0 2 * * *"

  http_target {
    uri         = "${google_cloud_run_v2_service.api.uri}/reports/generate"
    http_method = "POST"

    oidc_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}

# ------------------------------------------------------------------------------
# Cloud SQL
# ------------------------------------------------------------------------------

resource "google_sql_database_instance" "main" {
  name   = "${local.project_name}-db-instance"
  region = local.region

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
    }

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }
  }

  deletion_protection = false
}

resource "google_sql_database" "app" {
  name     = "${local.project_name}-database"
  instance = google_sql_database_instance.main.name
}

# ------------------------------------------------------------------------------
# Cloud Storage
# ------------------------------------------------------------------------------

resource "google_storage_bucket" "assets" {
  name          = "${local.project_id}-${local.project_name}-assets"
  location      = local.region
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
}
