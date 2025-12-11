resource "aws_key_pair" "kthw" {
    key_name   = "${var.project_name}-key"
    public_key = file(var.public_key_path)
}

resource "aws_instance" "server" {
    ami           = var.debian_ami_arm64
    instance_type = var.instance_type
    subnet_id     = aws_subnet.kthw_public.id
    vpc_security_group_ids = [aws_security_group.kthw_sg.id]
    key_name      = aws_key_pair.kthw.key_name
    associate_public_ip_address = true

    tags = {
        Name = "${var.project_name}-server"
    }
  
}

locals {
 worker_names =[
    for i in range(var.worker_count) : "node-${i}"
 ] 
}

resource "aws_instance" "worker" {
    for_each     = toset(local.worker_names)
    ami           = var.debian_ami_arm64
    instance_type = var.instance_type
    subnet_id     = aws_subnet.kthw_public.id
    vpc_security_group_ids = [aws_security_group.kthw_sg.id]
    key_name      = aws_key_pair.kthw.key_name
    associate_public_ip_address = true
  
    tags = {
        Name = "${var.project_name}-${each.key}"
    }
}