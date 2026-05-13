terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.30"
    }
  }

  # Remote state lives in a pre-existing GCS bucket created by the bootstrap
  # script (scripts/bootstrap.sh).
  backend "gcs" {
    bucket = "REPLACE_ME-tfstate"
    prefix = "envs/prod"
  }
}

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}
