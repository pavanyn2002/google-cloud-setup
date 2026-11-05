variable "project_id" {
  description = "Your Google Cloud project ID (not the name), e.g. pavan-gcp-dev."
  type        = string
}

variable "region" {
  description = "Region for the state bucket. asia-south1 is Mumbai."
  type        = string
  default     = "asia-south1"
}
