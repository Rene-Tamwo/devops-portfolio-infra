output "master_public_ip" {
  description = "Public IP of the Kubernetes master node"
  value       = aws_instance.master.public_ip
}

output "worker_public_ips" {
  description = "Public IPs of the Kubernetes worker nodes"
  value       = aws_instance.workers[*].public_ip
}

output "ssh_private_key" {
  description = "Private key for SSH access"
  value       = tls_private_key.kubernetes.private_key_pem
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig file content"
  value       = local_file.kubeconfig.content
  sensitive   = true
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}
