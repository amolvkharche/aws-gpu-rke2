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

  user_data = templatefile(
    "${path.module}/cloud-init/server.yaml",
    {
      rke2_token   = random_password.rke2_token.result
      rke2_version = var.rke2_version
    }
  )
  tags = {
    Name = "${var.cluster_name}-cp-1"
    Role = "control-plane-primary"
  }
}

# Additional RKE2 Server Nodes
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

  user_data = templatefile(
    "${path.module}/cloud-init/server-join.yaml",
    {
      rke2_token        = random_password.rke2_token.result
      rke2_version      = var.rke2_version
      server_private_ip = aws_instance.rke2_server_init.private_ip
    }
  )

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

  user_data = templatefile(
    "${path.module}/cloud-init/agent.yaml",
    {
      rke2_token        = random_password.rke2_token.result
      rke2_version      = var.rke2_version
      server_private_ip = aws_instance.rke2_server_init.private_ip
    }
  )

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

  user_data = templatefile(
    "${path.module}/cloud-init/agent.yaml",
    {
      rke2_token        = random_password.rke2_token.result
      rke2_version      = var.rke2_version
      server_private_ip = aws_instance.rke2_server_init.private_ip
    }
  )

  depends_on = [aws_instance.rke2_server_init]

  tags = {
    Name = "${var.cluster_name}-wk-${count.index + 1}"
    Role = "worker-nodes"
  }
}
