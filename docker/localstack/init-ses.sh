#!/bin/bash
# Initialize LocalStack SES for local development

set -euo pipefail

echo "Initializing SES..."

# Verify sender email for local development
# Uses SES_FROM_EMAIL from environment if set, otherwise defaults to noreply@example.com
awslocal ses verify-email-identity --email-address "${SES_FROM_EMAIL:-noreply@example.com}"

echo "SES initialization complete"
