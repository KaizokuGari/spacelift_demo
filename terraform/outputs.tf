output "key_ssm_param" {
  value = aws_ssm_parameter.private_key.name
}

output "public_ip" {
  value = aws_instance.demo_instance.public_ip
}

output "private_key_pem" {
  value     = tls_private_key.demo_key.private_key_pem
  sensitive = true
}
