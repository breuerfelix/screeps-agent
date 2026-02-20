#!/bin/bash

# Script to rebuild and update Grafana dashboards
# Usage: ./build_and_update.sh

set -e  # Exit on error

echo "🔨 Compiling Jsonnet to JSON..."
jsonnet -J grafonnet-lib overview.jsonnet -o overview.json
jsonnet -J grafonnet-lib assets.jsonnet -o assets.json

echo "📤 Uploading to Grafana..."
./update_dashboard.sh overview
./update_dashboard.sh assets

echo "✅ Done!"
