# SES Module Outputs

output "domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.main.arn
}

output "verification_status" {
  description = "Verification status of the domain identity"
  value       = aws_ses_domain_identity_verification.main.id
}
