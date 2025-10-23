# GitHub Actions CI/CD

## Workflows

### CI Pipeline (`ci.yml`)

Comprehensive continuous integration pipeline that runs on:
- Pull requests to `main` or `develop`
- Pushes to `main` or `develop`
- Manual workflow dispatch

**Jobs:**

1. **YAML Lint** - Validate YAML syntax and formatting
2. **Docker Compose Validation** - Ensure docker-compose.yml is valid
3. **ShellCheck** - Lint shell scripts for common errors
4. **Python Lint** - Check Python scripts with flake8
5. **Secret Scanning** - Detect exposed secrets with TruffleHog
6. **Markdown Lint** - Validate Markdown documentation

**Security Features:**
- Secret scanning to prevent credential leaks
- Validates all configuration files before deployment

## Status Badges

Add these to your README.md:

```markdown
![CI](https://github.com/GunarsK-portfolio/infrastructure/workflows/CI/badge.svg)
```

## Local Testing

Using Task:
```bash
task validate          # Validate docker-compose.yml
task lint-yaml         # Lint YAML files
task lint-shell        # Lint shell scripts
task lint-python       # Lint Python scripts
task lint-markdown     # Lint Markdown files
task ci                # Run all CI checks locally
task install-tools     # Install required linting tools
```

## Configuration Files

- `.yamllint.yml` - YAML linting rules
- `docker-compose.yml` - Main orchestration file
- `scripts/` - Shell and Python automation scripts

## Notes for Infrastructure Repository

This repository contains configuration files and orchestration:
- No application code to build or test
- Focus on configuration validation and linting
- Ensures infrastructure-as-code quality
- Prevents misconfigurations before deployment
