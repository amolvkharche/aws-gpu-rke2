resource "random_password" "rke2_token" {
  length  = 32
  special = false
}

resource "tls_private_key" "rke2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "rke2_aws_key" {
  key_name   = "rke2-auto-generated-key"
  public_key = tls_private_key.rke2_key.public_key_openssh
  tags       = { Name = "${var.cluster_name}-key" }
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.rke2_key.private_key_pem
  filename        = "${path.module}/${var.cluster_name}-key.pem"
  file_permission = "0400"
}
resource "aws_instance" "rke2_server_init" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.server_instance_type
  key_name               = aws_key_pair.rke2_aws_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.rke2_sg.id]

  root_block_device {
    volume_size           = 40
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
    PUBLIC_IP=$(curl -s -f -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

    mkdir -p /etc/rancher/rke2
    mkdir -p /var/lib/rancher/rke2/server/manifests
  

    cat <<C_EOF > /etc/rancher/rke2/config.yaml
    token: "${random_password.rke2_token.result}"
    node-external-ip:
      - "$PUBLIC_IP"
    tls-san:
      - "$PUBLIC_IP"
      - "$PRIVATE_IP"
    disable:
      - rke2-ingress-nginx
    ingress-controller: traefik
    cni:
      - canal
    C_EOF


    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="${var.rke2_version}" INSTALL_RKE2_TYPE="server" sh -
    systemctl enable rke2-server.service
    systemctl start rke2-server.service
    sudo ln -sf /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

  EOF

  tags = {
    Name = "${var.cluster_name}-cp-1"
    Role = "control-plane-primary"
  }
}

# 7. Additional RKE2 Server Nodes
resource "aws_instance" "rke2_server_join" {
  count                  = max(0, var.server_node_count - 1)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.server_instance_type
  key_name               = aws_key_pair.rke2_aws_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.rke2_sg.id]

  root_block_device {
    volume_size           = 40
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex

    mkdir -p /etc/rancher/rke2

    cat <<C_EOF > /etc/rancher/rke2/config.yaml
    server: https://${aws_instance.rke2_server_init.private_ip}:9345
    token: "${random_password.rke2_token.result}"
    cni:
      - canal
    C_EOF

    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="${var.rke2_version}" INSTALL_RKE2_TYPE="server" sh -
    systemctl enable rke2-server.service
    systemctl start rke2-server.service
  EOF

  depends_on = [aws_instance.rke2_server_init]

  tags = {
    Name = "${var.cluster_name}-cp-${count.index + 2}"
    Role = "control-plane-secondary"
  }
}

# RKE2 GPU Worker Nodes
resource "aws_instance" "gpu_nodes" {
  count                  = var.gpu_node_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.gpu_instance_type
  key_name               = aws_key_pair.rke2_aws_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.rke2_sg.id]

  root_block_device {
    volume_size           = 80
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex

    apt-get update -y
    apt-get install -y build-essential linux-headers-$(uname -r) curl

    mkdir -p /etc/rancher/rke2

    cat <<C_EOF > /etc/rancher/rke2/config.yaml
    server: https://${aws_instance.rke2_server_init.private_ip}:9345
    token: "${random_password.rke2_token.result}"
    node-label:
      - "node.kubernetes.io/instance-type=gpu"
      - "accelerator=nvidia-gpu"
    C_EOF

    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="${var.rke2_version}" INSTALL_RKE2_TYPE="agent" sh -
    systemctl enable rke2-agent.service
    systemctl start rke2-agent.service
  EOF

  depends_on = [aws_instance.rke2_server_init]

  tags = {
    Name = "${var.cluster_name}-gpu-nodes-${count.index + 1}"
    Role = "gpu-worker"
  }
}

resource "aws_instance" "worker_nodes" {
  ami                    = data.aws_ami.ubuntu.id
  count                  = var.worker_node_count
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.rke2_aws_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.rke2_sg.id]

  root_block_device {
    volume_size           = 80
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex

    apt-get update -y
    apt-get install -y build-essential linux-headers-$(uname -r) curl

    mkdir -p /etc/rancher/rke2

    cat <<C_EOF > /etc/rancher/rke2/config.yaml
    server: https://${aws_instance.rke2_server_init.private_ip}:9345
    token: "${random_password.rke2_token.result}"
    C_EOF

    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="${var.rke2_version}" INSTALL_RKE2_TYPE="agent" sh -
    systemctl enable rke2-agent.service
    systemctl start rke2-agent.service
  EOF

  depends_on = [aws_instance.rke2_server_init]

  tags = {
    Name = "${var.cluster_name}-wk-${count.index + 1}"
    Role = "worker-nodes"
  }
}
