# Look up an existing secret by name
data "aws_secretsmanager_secret" "db_password" {
  name = "rds-master-password"
}

# Get the current version's value
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

# -----------------------------
# OpenAI API Key
# -----------------------------

data "aws_secretsmanager_secret" "openai_key" {
  name = "openai-api-key"
}

data "aws_secretsmanager_secret_version" "openai_key" {
  secret_id = data.aws_secretsmanager_secret.openai_key.id
}