#!/bin/bash
# Initialize LocalStack SES for local development

set -e

echo "Initializing SES..."

# Verify sender email for local development
awslocal ses verify-email-identity --email-address noreply@localhost

echo "SES initialization complete"
