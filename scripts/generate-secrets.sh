#!/usr/bin/env bash
# Wrapper script for generate-secrets.py
# Checks for Python 3 and executes the Python script

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Python 3 is available
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    # Check if 'python' is Python 3
    PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}' | cut -d. -f1)
    if [ "$PYTHON_VERSION" = "3" ]; then
        PYTHON_CMD="python"
    else
        echo "Error: Python 3 is required but not found."
        echo "Please install Python 3 or ensure 'python3' is in your PATH."
        exit 1
    fi
else
    echo "Error: Python 3 is required but not found."
    echo "Please install Python 3 and ensure it's in your PATH."
    exit 1
fi

# Execute the Python script with all arguments passed through
exec "$PYTHON_CMD" "$SCRIPT_DIR/generate-secrets.py" "$@"
