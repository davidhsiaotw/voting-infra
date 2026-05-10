output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "rds_address" {
  value = aws_db_instance.main.address
}

output "db_password" {
  value     = data.aws_ssm_parameter.db_password.value
  sensitive = true
}
