#!/bin/bash

# Grafana configuration
GRAFANA_URL="http://192.168.178.13:3001"
GRAFANA_API_KEY=""  # Set this or use admin:admin below
DASHBOARD_NAME="${1:-overview}"  # Use first argument as dashboard name, default to overview
DASHBOARD_FILE="${DASHBOARD_NAME}.json"

# Upload the dashboard (with overwrite=true, it will update if UID matches)
echo "📤 Uploading dashboard: $DASHBOARD_NAME..."
RESPONSE=$(curl -s -X POST "$GRAFANA_URL/api/dashboards/db" \
  -u admin:jamo \
  -H "Content-Type: application/json" \
  -d @<(cat "$DASHBOARD_FILE" | jq '{dashboard: ., overwrite: true}'))

# Check if successful
if echo "$RESPONSE" | jq -e '.status == "success"' > /dev/null; then
  DASHBOARD_UID=$(echo "$RESPONSE" | jq -r '.uid')
  DASHBOARD_URL=$(echo "$RESPONSE" | jq -r '.url')
  VERSION=$(echo "$RESPONSE" | jq -r '.version')
  echo "✅ Dashboard updated successfully!"
  echo "   UID: $DASHBOARD_UID"
  echo "   Version: $VERSION"
  echo "   URL: $GRAFANA_URL$DASHBOARD_URL"
else
  echo "❌ Error updating dashboard:"
  echo "$RESPONSE" | jq '.'
  exit 1
fi
