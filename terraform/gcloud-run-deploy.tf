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
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "1"
      }
    }
    spec {
      # one instance: the chat hub lives in the process, so rooms are shared
      # by the visitors of that instance only
      container_concurrency = 80
      containers {
        image = "gcr.io/${var.project_id}/snuggleos:${var.git_sha}"
        ports {
          container_port = 8080
        }
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