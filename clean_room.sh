#!/usr/bin/env bash
set -euo pipefail

VM_ENDPOINT="${VM_ENDPOINT:-http://192.168.178.13:8428}"
ROOM_LABEL="${ROOM_LABEL:-room}"
ROOMS=("E9N39" "E1N39")

echo "VictoriaMetrics endpoint: $VM_ENDPOINT"
echo "Deleting ALL series with label '$ROOM_LABEL' matching: ${ROOMS[*]}"
echo "==================================================================="

for room in "${ROOMS[@]}"; do
  echo "Fetching metric names for room=\"$room\"..."
  metrics=$(curl -sG "$VM_ENDPOINT/api/v1/label/__name__/values" \
    --data-urlencode "match[]={${ROOM_LABEL}=\"${room}\"}" | jq -r '.data[]?' | sort -u)

  if [[ -z "$metrics" ]]; then
    echo "  No metrics found for room=\"$room\""
    continue
  fi

  echo "  Found $(echo "$metrics" | wc -l) metrics for room=\"$room\". Deleting..."
  while read -r metric; do
    [[ -z "$metric" ]] && continue
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
      "$VM_ENDPOINT/api/v1/admin/tsdb/delete_series" \
      --data-urlencode "match[]={__name__=\"${metric}\",${ROOM_LABEL}=\"${room}\"}")
    if [[ "$code" == "204" || "$code" == "200" ]]; then
      echo "    OK  : ${metric} (room=${room})"
    else
      echo "    FAIL: ${metric} (room=${room}) HTTP ${code}"
    fi
  done <<< "$metrics"

  echo "-------------------------------------------------------------------"
done

echo "Done. Note: disk space is reclaimed gradually during background merges."
