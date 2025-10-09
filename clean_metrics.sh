#!/usr/bin/env bash
set -euo pipefail

VM_ENDPOINT="${VM_ENDPOINT:-http://192.168.178.13:8428}"
CUTOFF_SECONDS="${CUTOFF_SECONDS:-3600}"      # “inactive” window (default: 1h)
BASELINE_DAYS="${BASELINE_DAYS:-14}"           # lookback to find known metrics (default: 7d)

usage() {
  cat <<EOF
Usage: $0 [--delete]

Without flags: lists metric names seen in last ${BASELINE_DAYS}d but NOT in last $((CUTOFF_SECONDS/3600))h.
With --delete: deletes those metrics via VictoriaMetrics delete API.

Env overrides:
  VM_ENDPOINT     ($VM_ENDPOINT)
  CUTOFF_SECONDS  ($CUTOFF_SECONDS)
  BASELINE_DAYS   ($BASELINE_DAYS)

Requires: curl, jq, comm, sort, date
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }
DO_DELETE=false
[[ "${1:-}" == "--delete" ]] && DO_DELETE=true

NOW=$(date -u +%s)
START_BASELINE=$((NOW - BASELINE_DAYS*24*3600))
START_CUTOFF=$((NOW - CUTOFF_SECONDS))

# Fetch metric names in baseline and in the last cutoff window
names_baseline=$(curl -sG "$VM_ENDPOINT/api/v1/label/__name__/values" \
  --data-urlencode "start=${START_BASELINE}" \
  --data-urlencode "end=${NOW}" \
  | jq -r '.data[]' | sort -u)

names_recent=$(curl -sG "$VM_ENDPOINT/api/v1/label/__name__/values" \
  --data-urlencode "start=${START_CUTOFF}" \
  --data-urlencode "end=${NOW}" \
  | jq -r '.data[]' | sort -u)

# Set-diff: baseline minus recent => inactive for the last cutoff window
readarray -t CANDIDATES < <(comm -23 <(printf "%s\n" "$names_baseline") <(printf "%s\n" "$names_recent"))

echo "VictoriaMetrics: $VM_ENDPOINT"
echo "Now (UTC): $(date -u -d @${NOW} '+%Y-%m-%d %H:%M:%S')"
echo "Baseline window start: $(date -u -d @${START_BASELINE} '+%Y-%m-%d %H:%M:%S')"
echo "Inactive cutoff start: $(date -u -d @${START_CUTOFF} '+%Y-%m-%d %H:%M:%S')"
echo

if ((${#CANDIDATES[@]}==0)); then
  echo "No metric names qualify for deletion (none inactive over the last $((CUTOFF_SECONDS/3600))h)."
  exit 0
fi

echo "Metric names with NO samples in the last $((CUTOFF_SECONDS/3600))h (but seen within ${BASELINE_DAYS}d):"
printf '  %s\n' "${CANDIDATES[@]}"
echo
echo "Total: ${#CANDIDATES[@]}"

if $DO_DELETE; then
  echo
  echo "Deleting these metrics (this removes ALL historical data for each selected metric name)..."
  for m in "${CANDIDATES[@]}"; do
    # Delete all series with this metric name
    # See: /api/v1/admin/tsdb/delete_series (no time-range supported)
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
      "$VM_ENDPOINT/api/v1/admin/tsdb/delete_series" \
      --data-urlencode "match[]={__name__=\"${m}\"}")
    if [[ "$code" == "204" || "$code" == "200" ]]; then
      echo "OK  : ${m}"
    else
      echo "FAIL: ${m} (HTTP $code)"
    fi
  done
  echo
  echo "Tip: space reclamation happens during background merges; data may not disappear from disk immediately." #  [oai_citation:2‡docs.victoriametrics.com](https://docs.victoriametrics.com/guides/guide-delete-or-replace-metrics/readme/?utm_source=chatgpt.com)
else
  echo
  echo "Dry-run only. Re-run with --delete to remove them."
fi
