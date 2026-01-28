variable "gcp_project" {
  description = "GCP project ID"
  type        = string
  default     = "personal-214003"
}

variable "oci_tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
  default     = "ocid1.tenancy.oc1..aaaaaaaa4egjff3d4wetmquuvpxcoa7dbguxjs2drnwnxgbt37azbn26bl7a"
}

variable "oci_region" {
  description = "OCI region"
  type        = string
  default     = "us-sanjose-1"
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n turbio@itoh"
}
