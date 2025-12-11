resource "aws_security_group" "kthw_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for Kubernetes-the-Hard-Way nodes"
  vpc_id      = aws_vpc.kthw.id

  # Internal cluster communication (all traffic within VPC)
  ingress {
    description = "Cluster internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.kthw.cidr_block]
  }

  # SSH from your IP
  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # Kubernetes API server (6443) from your IP
  ingress {
    description = "Kubernetes API from your IP"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # NodePort range (for your test apps)
  ingress {
    description = "NodePort range from your IP"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # Optional: ping from your IP
  ingress {
    description = "ICMP ping from your IP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.your_ip_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Project     = var.project_name
    Environment = "lab"
  }
}
