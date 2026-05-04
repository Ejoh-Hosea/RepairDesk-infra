resource "aws_secretsmanager_secret" "mongo_uri" {
  name                    = "/${var.project}/${var.environment}/mongo-uri"
  description             = "MongoDB Atlas connection string"
  recovery_window_in_days = 0 # Instant delete — critical for terraform destroy/recreate
}

resource "aws_secretsmanager_secret_version" "mongo_uri" {
  secret_id     = aws_secretsmanager_secret.mongo_uri.id
  secret_string = var.mongo_uri
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "/${var.project}/${var.environment}/jwt-secret"
  description             = "JWT signing secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret
}
