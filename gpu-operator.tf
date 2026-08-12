resource "null_resource" "wait_for_rke2" {
  triggers = {
    server_id = aws_instance.rke2_server_init.id
    server_ip = aws_instance.rke2_server_init.public_ip
  }

  depends_on = [aws_instance.rke2_server_init]

  provisioner "remote-exec" {
    inline = [
      "echo '==> 1/3 Checking rke2-server service status...'",
      "until sudo systemctl is-active --quiet rke2-server; do echo 'Waiting for rke2-server...'; sleep 10; done",
      "echo '==> 2/3 Checking for rke2.yaml configuration...'",
      "until [ -f /etc/rancher/rke2/rke2.yaml ]; do echo 'Waiting for rke2.yaml...'; sleep 5; done",
      "echo '==> 3/3 Checking Kubernetes API readiness...'",
      "until sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes 2>/dev/null | grep -q ' Ready'; do echo 'Waiting for node to report Ready...'; sleep 10; done",
      "echo '==> RKE2 Control Plane successfully initialized!'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.rke2_key.private_key_pem
      host        = aws_instance.rke2_server_init.public_ip
      timeout     = "10m"
    }
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no -i ${var.cluster_name}-key.pem ubuntu@${aws_instance.rke2_server_init.public_ip} "sudo cat /etc/rancher/rke2/rke2.yaml" > ${path.module}/kubeconfig.yaml
      sed -i.bak 's/127.0.0.1/${aws_instance.rke2_server_init.public_ip}/g' ${path.module}/kubeconfig.yaml
    EOT
  }
}

resource "helm_release" "gpu_operator" {
  count            = var.gpu_node_count > 0 ? 1 : 0
  name             = "gpu-operator"
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  chart            = "gpu-operator"
  namespace        = "gpu-operator"
  create_namespace = true

  values = [
    file("${path.module}/cloud-init/gpu-operator-values.yaml")
  ]

  depends_on = [
    null_resource.wait_for_rke2
  ]
}
