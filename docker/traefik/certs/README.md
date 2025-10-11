# SSL/TLS Certificates

This directory contains SSL certificates for local HTTPS development.

## Generate Self-Signed Certificates

For local development, generate self-signed certificates:

```bash
# Generate certificate valid for localhost
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout localhost.key \
  -out localhost.crt \
  -days 365 \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:*.localhost,IP:127.0.0.1"
```

Or use mkcert for better browser trust:

```bash
# Install mkcert
brew install mkcert  # macOS
# or
choco install mkcert # Windows
# or
apt install mkcert   # Linux

# Install local CA
mkcert -install

# Generate certificates
mkcert localhost 127.0.0.1 ::1
```

## Required Files

- `localhost.crt` - Certificate file
- `localhost.key` - Private key file

These files are ignored by git for security reasons.

## Production

For production, use Let's Encrypt by uncommenting the relevant configuration in `docker-compose.yml`.
