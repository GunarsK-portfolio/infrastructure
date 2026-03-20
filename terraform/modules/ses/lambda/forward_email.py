"""SES email forwarder Lambda.

Reads raw email from S3 (stored by SES receipt rule), rewrites From/To
headers, and forwards to the configured destination via SES SendRawEmail.
"""

import json
import logging
import os
import email
from email.utils import parseaddr

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
ses = boto3.client("ses")

S3_BUCKET = os.environ["S3_BUCKET"]
FORWARDING_RULES = json.loads(os.environ["FORWARDING_RULES"])
FROM_DOMAIN = os.environ["FROM_DOMAIN"]


def handler(event, context):
    for record in event["Records"]:
        notification = record.get("ses", {})
        mail = notification.get("mail", {})
        message_id = mail.get("messageId", "")
        recipients = [
            r.lower() for r in notification.get("receipt", {}).get("recipients", [])
        ]

        logger.info("Processing message %s for %d recipient(s)", message_id, len(recipients))

        try:
            raw = s3.get_object(Bucket=S3_BUCKET, Key=f"incoming/{message_id}")
            original = email.message_from_bytes(raw["Body"].read())
        except ClientError:
            logger.exception("Failed to fetch message %s from S3", message_id)
            continue

        for recipient in recipients:
            forward_to = FORWARDING_RULES.get(recipient)
            if not forward_to:
                logger.warning("No forwarding rule for %s, skipping", recipient)
                continue

            try:
                forwarded = rewrite_for_forwarding(original, forward_to)
                response = ses.send_raw_email(
                    Source=f"noreply@{FROM_DOMAIN}",
                    Destinations=[forward_to],
                    RawMessage={"Data": forwarded.as_string()},
                )
                logger.info(
                    "Forwarded message %s for %s, SES MessageId: %s",
                    message_id, recipient, response.get("MessageId"),
                )
            except ClientError:
                logger.exception(
                    "Failed to forward message %s for %s", message_id, recipient
                )


def rewrite_for_forwarding(original, forward_to):
    """Rewrite headers on the original email for forwarding."""
    msg = email.message_from_string(original.as_string())

    original_from = msg.get("From", "")
    original_subject = msg.get("Subject", "(no subject)")

    # Replace headers for forwarding
    del msg["To"]
    del msg["CC"]
    del msg["BCC"]
    del msg["Return-Path"]
    del msg["DKIM-Signature"]

    if msg.get("From"):
        msg.replace_header("From", f"noreply@{FROM_DOMAIN}")
    else:
        msg["From"] = f"noreply@{FROM_DOMAIN}"
    msg["To"] = forward_to
    msg["X-Original-From"] = original_from

    # Set Reply-To to original sender if valid
    _, addr = parseaddr(original_from)
    if addr and "@" in addr:
        msg["Reply-To"] = original_from

    # Prefix subject
    fwd_subject = f"Fwd: {original_subject}"
    if msg.get("Subject"):
        msg.replace_header("Subject", fwd_subject)
    else:
        msg["Subject"] = fwd_subject

    return msg
