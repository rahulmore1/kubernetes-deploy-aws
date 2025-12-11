output "server_public_ip" {
  value = aws_instance.server.public_ip
}

output "server_private_ip" {
  value = aws_instance.server.private_ip
}

output "worker_public_ips" {
  value = [
    for name in sort(keys(aws_instance.worker)) :
    aws_instance.worker[name].public_ip
  ]
}

output "worker_private_ips" {
  value = [
    for name in sort(keys(aws_instance.worker)) :
    aws_instance.worker[name].private_ip
  ]
}
