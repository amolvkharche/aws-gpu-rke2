
resource "aws_vpc" "rke2_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.cluster_name}-vpc" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.rke2_vpc.id
  tags   = { Name = "${var.cluster_name}-gq" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.rke2_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = { Name = "${var.cluster_name}-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.rke2_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = { Name = "${var.cluster_name}-rtß" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 4. Security Group for RKE2 Cluster Communication
resource "aws_security_group" "rke2_sg" {
  name        = "rke2-cluster-sg"
  description = "Security Group for RKE2 cluster nodes"
  vpc_id      = aws_vpc.rke2_vpc.id

  # SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RKE2 Server Node Registration / Supervisor Port
  ingress {
    from_port   = 9345
    to_port     = 9345
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Kubelet Metrics / Internal Communication
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Canal/Flannel CNI Overlay Network (VXLAN)
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all internal inter-node traffic
  ingress {
    from_port = 0
    to_port   = 0 
    protocol  = "-1"
    self      = true
  }

  # Outbound Access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-sg" }
}
