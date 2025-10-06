#!/bin/bash

# Script to rebuild and update Grafana dashboard
# Usage: ./build_and_update.sh

set -e  # Exit on error

echo "🔨 Compiling Jsonnet to JSON..."
jsonnet -J grafonnet-lib cpu_dashboard.jsonnet -o cpu_dashboard.json

echo "📤 Uploading to Grafana..."
./update_dashboard.sh

echo "✅ Done!"
