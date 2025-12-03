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

variable "ubuntu_ami" {
  description = "Ubuntu 22.04 AMI ID by region"
  type        = map(string)
  default = {
    "us-east-1"      = "ami-0c55b159cbfafe1f0"  # N. Virginia
    "us-east-2"      = "ami-0fb653ca2d3203ac1"  # Ohio
    "us-west-1"      = "ami-0dd655843c87b6930"  # California
    "us-west-2"      = "ami-0c65adc9a5c1b5d7c"  # Oregon
    "eu-west-1"      = "ami-0f29c8402f8cce65c"  # Ireland
    "eu-west-2"      = "ami-0eb260c4d5475b901"  # London
    "eu-west-3"      = "ami-0d3c032d595e18c36"  # Paris - IMPORTANT
    "eu-central-1"   = "ami-0d1f3d6c8b8c5b5f5"  # Frankfurt
    "ap-southeast-1" = "ami-0fa377108253bf620"  # Singapore
    "ap-northeast-1" = "ami-0d52744d6551d851e"  # Tokyo
    "sa-east-1"      = "ami-0e66f5495b4efdd0f"  # São Paulo
  }
}


