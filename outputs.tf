# Output the URL of the EC2 instance after the templates are applied
output "url" {
  value = "https://${aws_instance.prometheus.public_ip}"
}
