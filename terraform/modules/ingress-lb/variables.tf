variable "name" {
  description = "Name prefix for the load balancer resources."
  type        = string
}

variable "region" {
  type = string
}

variable "worker_instance_group" {
  description = "Self link of the unmanaged instance group containing the workers."
  type        = string
}
