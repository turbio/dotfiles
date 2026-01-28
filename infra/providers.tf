terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = "us-central1"
}

provider "oci" {
  config_file_profile = "DEFAULT"
  region              = var.oci_region
}
