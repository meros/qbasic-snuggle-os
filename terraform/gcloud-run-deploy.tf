terraform {
  backend "gcs" {
    bucket = "snuggleos_cloudbuild"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "region" {
  default = "europe-north1"
}

variable "git_sha" {
}


variable "project_id" {
  default = "snuggleos"
}

resource "google_cloud_run_service" "default" {
  name     = "snuggleos"
  location = var.region


  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/snuggleos:${var.git_sha}"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.default.location
  project     = google_cloud_run_service.default.project
  service     = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
}