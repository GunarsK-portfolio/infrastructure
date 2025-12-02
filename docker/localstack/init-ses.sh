#!/bin/bash
# Initialize LocalStack SES for local development

set -e

echo "Initializing SES..."

# Verify sender email for local development
# Note: This must match SES_FROM_EMAIL in .env
awslocal ses verify-email-identity --email-address noreply@example.com

echo "SES initialization complete"
