terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # The state of the earlier deploys is here; one workspace per branch.
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
  type    = string
  default = "europe-north1"
}

variable "git_sha" {
  type        = string
  description = "The tag of the image to run: the commit it was built from."
}

variable "project_id" {
  type    = string
  default = "snuggleos"
}

resource "google_cloud_run_service" "default" {
  name     = "snuggleos"
  location = var.region

  template {
    metadata {
      annotations = {
        # The chat hub lives in the process: one instance, so every visitor
        # shares the same rooms. A restart empties them.
        "autoscaling.knative.dev/maxScale" = "1"
      }
    }

    spec {
      container_concurrency = 80

      containers {
        image = "gcr.io/${var.project_id}/snuggleos:${var.git_sha}"

        ports {
          container_port = 8080
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "256Mi"
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_member" "public" {
  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  service  = google_cloud_run_service.default.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "url" {
  value = google_cloud_run_service.default.status[0].url
}
