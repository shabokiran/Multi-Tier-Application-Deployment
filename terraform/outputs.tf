output "instance_public_ip" {
  value = aws_eip.k8s.public_ip
}

output "cluster_endpoint" {
  value = aws_instance.k8s_server.private_dns
}
