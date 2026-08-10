variable "cluster_name" {
  type        = string
  default     = "rke2-gpu-cluster"
  description = "Prefix applied to all created AWS resources and cluster identification tags"
}
variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy resources"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "server_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type for the RKE2 Server node"
}

variable "gpu_instance_type" {
  type        = string
  default     = "g4dn.xlarge"
  description = "EC2 instance type for the RKE2 GPU  node"
}

variable "rke2_version" {
  type        = string
  default     = "v1.34.2+rke2r1"
  description = "RKE2 version tag to install"
}
variable "server_node_count" {
  type        = number
  default     = 1
  description = "Number of RKE2 Server (Control Plane) nodes (recommended: 1 or 3)"

  validation {
    condition     = contains([1, 3], var.server_node_count)
    error_message = "Server count must be either 1 (standalone) or 3 (high availability etcd)."
  }
}

variable "gpu_node_count" {
  type        = number
  default     = 1
  description = "Number of RKE2 GPU Worker nodes (e.g., 1, 2, or more)"
}

variable "worker_node_count" {
  type        = number
  default     = 1
  description = "Number of RKE2 Worker nodes (e.g., 1, 2, or more)"
}
variable "worker_instance_type" {
  type        = string
  default     = "t2.medium"
  description = "EC2 instance type for the RKE2 worker node"
}
