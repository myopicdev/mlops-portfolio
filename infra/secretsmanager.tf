# Look up an existing secret by name
data "aws_secretsmanager_secret" "db_password" {
  name = "rds-master-password"
}

# Get the current version's value
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}