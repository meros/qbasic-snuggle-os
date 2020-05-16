terraform {
  backend "gcs" {
    bucket  = "snuggleos_cloudbuild"
    prefix  = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "region" {
  default = "eu-north1"
}

variable "git_sha" {
}


variable "project_id" {
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
