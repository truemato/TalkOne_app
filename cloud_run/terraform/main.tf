# cloud_run/terraform/main.tf

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# 変数定義
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

# Cloud Run サービス
resource "google_cloud_run_service" "matching_service" {
  name     = "matching-service"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/matching-service"
        
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
        
        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }
        
        env {
          name  = "LOCATION"
          value = var.region
        }
        
        env {
          name  = "QUEUE_NAME"
          value = google_cloud_tasks_queue.matching_queue.name
        }
      }
      
      container_concurrency = 100
    }
    
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "10"
        "autoscaling.knative.dev/minScale" = "1"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Cloud Tasks キュー
resource "google_cloud_tasks_queue" "matching_queue" {
  name     = "matching-queue"
  location = var.region

  rate_limits {
    max_dispatches_per_second = 100
    max_concurrent_dispatches = 1000
  }

  retry_config {
    max_attempts       = 3
    min_backoff        = "10s"
    max_backoff        = "300s"
    max_doublings      = 3
  }

  stackdriver_logging_config {
    sampling_ratio = 0.1
  }
}

# IAM ポリシー (Cloud Run を公開)
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.matching_service.name
  location = google_cloud_run_service.matching_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Tasks サービスアカウント
resource "google_service_account" "cloud_tasks_sa" {
  account_id   = "cloud-tasks-matcher"
  display_name = "Cloud Tasks Matcher Service Account"
}

# Cloud Tasks から Cloud Run を呼び出す権限
resource "google_cloud_run_service_iam_member" "tasks_invoker" {
  service  = google_cloud_run_service.matching_service.name
  location = google_cloud_run_service.matching_service.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_tasks_sa.email}"
}

# Firestore インデックス
resource "google_firestore_index" "match_requests_status_rating" {
  project    = var.project_id
  collection = "matchRequests"

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }

  fields {
    field_path = "userRating"
    order      = "ASCENDING"
  }

  fields {
    field_path = "__name__"
    order      = "ASCENDING"
  }
}

# 出力
output "service_url" {
  value = google_cloud_run_service.matching_service.status[0].url
}