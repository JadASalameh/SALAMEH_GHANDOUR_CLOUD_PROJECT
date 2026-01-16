variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "europe-west6"
}

variable "zone" {
  type        = string
  default     = "europe-west6-a"
}

variable "vm_name" {
  type        = string
  default     = "loadgen-vm"
}
