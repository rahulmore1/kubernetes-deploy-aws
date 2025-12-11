variable "project_name" {
    description = "Name prefix for all KTHW resources."
    type        = string
    default = "kthw"
}

variable "aws_region" {
    description = "AWS region to deploy."
    type        = string
    default     = "us-east-1"
}

variable "your_ip_cidr" {
    description = "Your public IP with /32, used for SSH/API/NodePortaccess"
    type        = string  
}

variable "instance_type"{
    description = "EC2 instance type for worker/server nodes"
    type        = string
    default     = "t4g.small"
}

variable "debian_ami_arm64"{
    description = "Debian 11 ARM64 AMI in us-east-1"
    type        = string
} 

variable "public_key_path"{
    description = "Path to your public key for SSH access to instances"
    type        = string
    default = "~/.ssh/id_ed25519_kthw.pub"
}

variable "worker_count"{
    description = "Number of worker nodes to create"
    type        = number
    default     = 2
}
