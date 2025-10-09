#!/usr/bin/env bash
set -euo pipefail

VM_ENDPOINT="${VM_ENDPOINT:-http://192.168.178.13:8428}"

usage() {
  cat <<EOF
Usage: $0 [--delete]

Without flags: lists all metric names with label shard="shard2".
With --delete: deletes all those metrics via VictoriaMetrics delete API.

Requires: curl, jq
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }
DO_DELETE=false
[[ "${1:-}" == "--delete" ]] && DO_DELETE=true

echo "Querying metrics where shard=\"shard2\" from $VM_ENDPOINT ..."

# Fetch all metric names having shard="shard2"
names=$(curl -sG "$VM_ENDPOINT/api/v1/label/__name__/values" \
  --data-urlencode 'match[]={shard="shard2"}' \
  | jq -r '.data[]' | sort -u)

if [[ -z "$names" ]]; then
  echo "No metrics found with shard=\"shard2\"."
  exit 0
fi

echo
echo "Metrics with shard=\"shard2\":"
printf '  %s\n' $names
echo
echo "Total: $(echo "$names" | wc -l | tr -d ' ')"

if $DO_DELETE; then
  echo
  echo "Deleting metrics with shard=\"shard2\"..."
  while read -r m; do
    [[ -z "$m" ]] && continue
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
      "$VM_ENDPOINT/api/v1/admin/tsdb/delete_series" \
      --data-urlencode "match[]={__name__=\"${m}\",shard=\"shard2\"}")
    if [[ "$code" == "204" || "$code" == "200" ]]; then
      echo "OK  : ${m}"
    else
      echo "FAIL: ${m} (HTTP $code)"
    fi
  done <<< "$names"
  echo
  echo "Done. Deleted all series with shard=\"shard2\"."
  echo "Note: Disk space is reclaimed gradually during background merges."
else
  echo
  echo "Dry-run only. Re-run with --delete to actually remove them."
fi
