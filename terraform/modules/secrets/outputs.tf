# Secrets Module Outputs

output "kms_key_id" {
  description = "KMS key ID for secrets encryption"
  value       = aws_kms_key.secrets.id
}

output "kms_key_arn" {
  description = "KMS key ARN for secrets encryption"
  value       = aws_kms_key.secrets.arn
}

output "aurora_master_password_arn" {
  description = "ARN of Aurora master password secret"
  value       = aws_secretsmanager_secret.aurora_master_password.arn
  sensitive   = true
}

output "aurora_owner_password_arn" {
  description = "ARN of Aurora owner password secret"
  value       = aws_secretsmanager_secret.aurora_owner_password.arn
  sensitive   = true
}

output "aurora_admin_password_arn" {
  description = "ARN of Aurora admin password secret"
  value       = aws_secretsmanager_secret.aurora_admin_password.arn
  sensitive   = true
}

output "aurora_public_password_arn" {
  description = "ARN of Aurora public password secret"
  value       = aws_secretsmanager_secret.aurora_public_password.arn
  sensitive   = true
}

output "redis_auth_token_arn" {
  description = "ARN of Redis AUTH token secret"
  value       = aws_secretsmanager_secret.redis_auth_token.arn
  sensitive   = true
}

output "jwt_secret_arn" {
  description = "ARN of JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
  sensitive   = true
}

output "secret_arns" {
  description = "Map of all secret ARNs"
  value = {
    aurora_master = aws_secretsmanager_secret.aurora_master_password.arn
    aurora_owner  = aws_secretsmanager_secret.aurora_owner_password.arn
    aurora_admin  = aws_secretsmanager_secret.aurora_admin_password.arn
    aurora_public = aws_secretsmanager_secret.aurora_public_password.arn
    redis_auth    = aws_secretsmanager_secret.redis_auth_token.arn
    jwt_secret    = aws_secretsmanager_secret.jwt_secret.arn
  }
  sensitive = true
}
