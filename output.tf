output "rke2_server_public_ips" {
  description = "Public IPs of RKE2 Server nodes"
  value = concat(
    [aws_instance.rke2_server_init.public_ip],
    aws_instance.rke2_server_join[*].public_ip
  )
}

output "rke2_gpu_agent_public_ips" {
  description = "Public IPs of GPU Agent nodes"
  value       = aws_instance.gpu_nodes[*].public_ip
}

output "rke2_workers_public_ips" {
  description = "Public IPs of GPU Agent nodes"
  value       = aws_instance.worker_nodes[*].public_ip
}

output "ssh_command_server" {
  description = "Command to SSH into primary control plane node"
  value       = "ssh -i ${var.cluster_name}-key.pem ubuntu@${aws_instance.rke2_server_init.public_ip}"
}

output "kubeconfig_fetch_command" {
  description = "Command to download and configure kubeconfig locally"
  value       = "ssh -o StrictHostKeyChecking=no -i ${var.cluster_name}-key.pem ubuntu@${aws_instance.rke2_server_init.public_ip} 'sudo cat /etc/rancher/rke2/rke2.yaml' | sed 's/127.0.0.1/${aws_instance.rke2_server_init.public_ip}/g' > kubeconfig.yaml"
}
