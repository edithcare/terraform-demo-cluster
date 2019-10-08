
output "kubeconfig" {
  value = local.kubeconfig
}

output "name_servers" {
  value = aws_route53_zone.this.name_servers
}
