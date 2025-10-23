#!/usr/bin/env python3
"""
Generate secure passwords and secrets for local development environment.
This script creates a .env file with randomly generated credentials.
"""

import secrets
import string
import sys
from pathlib import Path


def generate_password(length=32, use_special_chars=False):
    """Generate a cryptographically secure random password."""
    if use_special_chars:
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*()-_=+[]{}|;:,.<>?"
    else:
        alphabet = string.ascii_letters + string.digits

    password = ''.join(secrets.choice(alphabet) for _ in range(length))
    return password


def generate_jwt_secret(length=64):
    """Generate a JWT secret key (base64-like format)."""
    return secrets.token_urlsafe(length)


def generate_hex_secret(length=32):
    """Generate a hexadecimal secret."""
    return secrets.token_hex(length)


def read_env_example(infrastructure_dir):
    """Read the .env.example file to preserve structure and comments."""
    env_example_path = infrastructure_dir / '.env.example'

    if not env_example_path.exists():
        print(f"Error: {env_example_path} not found!")
        sys.exit(1)

    with open(env_example_path, 'r') as f:
        return f.read()


def generate_env_file(infrastructure_dir, force=False):
    """Generate .env file with secure passwords."""
    env_path = infrastructure_dir / '.env'

    # Check if .env already exists
    if env_path.exists() and not force:
        response = input(f"\n{env_path} already exists. Overwrite? (y/N): ")
        if response.lower() != 'y':
            print("Aborted. No changes made.")
            sys.exit(0)

    # Generate all secrets
    secrets_map = {
        # PostgreSQL passwords
        'POSTGRES_SUPERUSER_PASSWORD': generate_password(32),
        'FLYWAY_PASSWORD': generate_password(32),
        'DB_PASSWORD': generate_password(32),
        'DB_PASSWORD_READONLY': generate_password(32),

        # MinIO credentials
        'MINIO_ROOT_PASSWORD': generate_password(32),
        'S3_SECRET_KEY': generate_password(48),

        # JWT secret
        'JWT_SECRET': generate_jwt_secret(48),
    }

    # Read the example file
    env_content = read_env_example(infrastructure_dir)

    # Replace default passwords with generated ones
    replacements = {
        'postgres_pass': secrets_map['POSTGRES_SUPERUSER_PASSWORD'],
        'portfolio_owner_dev_pass': secrets_map['FLYWAY_PASSWORD'],
        'portfolio_admin_dev_pass': secrets_map['DB_PASSWORD'],
        'portfolio_public_dev_pass': secrets_map['DB_PASSWORD_READONLY'],
        'minioadmin': secrets_map['MINIO_ROOT_PASSWORD'],
        'files-api-secret-change-in-production': secrets_map['S3_SECRET_KEY'],
        'your-secret-key-change-in-production': secrets_map['JWT_SECRET'],
    }

    for old_value, new_value in replacements.items():
        env_content = env_content.replace(old_value, new_value)

    # Write the new .env file
    with open(env_path, 'w') as f:
        f.write(env_content)

    # Create a backup file with just the secrets for reference
    secrets_backup_path = infrastructure_dir / '.secrets.txt'
    with open(secrets_backup_path, 'w') as f:
        f.write("# Generated Secrets - KEEP THIS FILE SECURE!\n")
        f.write("# This file is for backup reference only.\n")
        f.write("# DO NOT COMMIT THIS FILE TO VERSION CONTROL!\n\n")
        for key, value in secrets_map.items():
            f.write(f"{key}={value}\n")

    print(f"\n✓ Successfully generated {env_path}")
    print(f"✓ Secrets backup saved to {secrets_backup_path}")
    print("\nGenerated secrets:")
    print("-" * 80)
    for key in secrets_map.keys():
        print(f"  {key}: <generated>")
    print("-" * 80)
    print("\nWARNING: Keep these secrets secure and never commit them to version control!")
    print("The .env and .secrets.txt files should be in your .gitignore")

    # Check if .gitignore exists and has proper entries
    gitignore_path = infrastructure_dir / '.gitignore'
    if gitignore_path.exists():
        with open(gitignore_path, 'r') as f:
            gitignore_content = f.read()

        missing_entries = []
        if '.env' not in gitignore_content:
            missing_entries.append('.env')
        if '.secrets.txt' not in gitignore_content:
            missing_entries.append('.secrets.txt')

        if missing_entries:
            print(f"\n⚠ WARNING: Add these entries to {gitignore_path}:")
            for entry in missing_entries:
                print(f"  {entry}")
    else:
        print(f"\n⚠ WARNING: No .gitignore found in {infrastructure_dir}")
        print("  Create one and add: .env and .secrets.txt")


def main():
    # Determine the infrastructure directory
    script_dir = Path(__file__).parent
    infrastructure_dir = script_dir.parent

    print("=" * 80)
    print("Portfolio Infrastructure - Secret Generator")
    print("=" * 80)
    print(f"\nInfrastructure directory: {infrastructure_dir}")

    # Check for --force flag
    force = '--force' in sys.argv or '-f' in sys.argv

    generate_env_file(infrastructure_dir, force)

    print("\nNext steps:")
    print("  1. Review the generated .env file")
    print("  2. Run 'task up' or 'docker-compose up -d' to start services")
    print("  3. Keep .secrets.txt in a secure location (password manager, encrypted vault, etc.)")
    print("\n")


if __name__ == '__main__':
    main()
