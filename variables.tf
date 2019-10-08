

variable "id" {
  type    = number
  default = 0
}

variable "name" {
  type    = string
  default = "demo"
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

variable "subnets" {
  type    = list(string)
  default = ["private", "public", "nat", "cni"]
}

variable "k8s_version" {
  type    = string
  default = "1.14"
}

variable "control_plane_log_enabled" {
  type    = bool
  default = false
}

variable "control_plane_log_types" {
  type    = list(string)
  default = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]
}


variable "instance_type" {
  type    = string
  default = "m5.large"
}

variable "enable_network_acls" {
  type    = bool
  default = true
}

variable "enable_flow_logs" {
  type    = bool
  default = false
}

variable "flow_log_traffic_type" {
  type    = string
  default = "ALL"
}

variable "cluster_autoscaler_enabled" {
  type    = bool
  default = false
}

variable "cluster_autoscaler_namespace" {
  type    = string
  default = "kube-system"
}

variable "cluster_autoscaler_service_account" {
  type    = string
  default = "cluster-autoscaler"
}

variable "external_dns_enabled" {
  type    = bool
  default = false
}

variable "cni_genie_enabled" {
  type    = bool
  default = false
}

variable "cni_genie_networks" {
  type    = list(string)
  default = ["weave", "calico"]
}

variable "calico_network_policy_enabled" {
  type    = bool
  default = false
}


variable "helm_enabled" {
  type    = bool
  default = false
}

variable "flux_enabled" {
  type    = bool
  default = false
}
