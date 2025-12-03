variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "devops-portfolio-cluster"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium" # Gratuit dans les limites free tier
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "devops-portfolio-key"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}
