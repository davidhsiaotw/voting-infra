output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "rds_address" {
  value = aws_db_instance.main.address
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}
