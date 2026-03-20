"""SES email forwarder Lambda.

Reads raw email from S3 (stored by SES receipt rule), rewrites headers,
and forwards to the configured destination via SES SendRawEmail.
"""

import json
import logging
import os
import email
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase

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
                forwarded = build_forwarded_message(original, recipient, forward_to)
                ses.send_raw_email(
                    Source=f"noreply@{FROM_DOMAIN}",
                    Destinations=[forward_to],
                    RawMessage={"Data": forwarded.as_string()},
                )
                logger.info("Forwarded message %s for %s", message_id, recipient)
            except ClientError:
                logger.exception(
                    "Failed to forward message %s for %s", message_id, recipient
                )


def build_forwarded_message(original, original_recipient, forward_to):
    """Build a new message that wraps the original for forwarding."""
    msg = MIMEMultipart("mixed")

    original_from = original.get("From", "unknown")
    original_subject = original.get("Subject", "(no subject)")

    msg["From"] = f"noreply@{FROM_DOMAIN}"
    msg["To"] = forward_to
    msg["Subject"] = f"Fwd: {original_subject}"
    msg["Reply-To"] = original_from
    msg["X-Original-To"] = original_recipient
    msg["X-Original-From"] = original_from

    body = MIMEText(
        f"Forwarded email to {original_recipient}\n"
        f"From: {original_from}\n"
        f"Subject: {original_subject}\n"
        f"---\n\n",
        "plain",
    )
    msg.attach(body)

    original_attachment = MIMEBase("message", "rfc822")
    original_attachment.set_payload(original.as_string())
    original_attachment.add_header(
        "Content-Disposition", "attachment", filename="original.eml"
    )
    msg.attach(original_attachment)

    return msg
