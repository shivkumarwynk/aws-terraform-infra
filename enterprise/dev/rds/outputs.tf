output "mysql_endpoint" {
  description = "MySQL connection endpoint"
  value       = aws_db_instance.mysql.endpoint
}

output "mysql_master_secret_arn" {
  description = "Secrets Manager ARN containing the MySQL master credentials"
  value       = aws_db_instance.mysql.master_user_secret[0].secret_arn
}

output "postgres_endpoint" {
  description = "PostgreSQL connection endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "postgres_master_secret_arn" {
  description = "Secrets Manager ARN containing the PostgreSQL master credentials"
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "db_subnet_group_name" {
  description = "Shared database subnet group name"
  value       = aws_db_subnet_group.this.name
}
