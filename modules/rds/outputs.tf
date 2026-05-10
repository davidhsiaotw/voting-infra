output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "rds_address" {
  value = aws_db_instance.main.address
}

output "db_password" {
  value     = "v4gX9^D4cv"
  sensitive = true
}
