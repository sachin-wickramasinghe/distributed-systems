#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_MODE=""
CLIENT_BIN=""

resolve_client_bin() {
  if [[ -x "$ROOT_DIR/client_bin" ]]; then
    printf '%s\n' "$ROOT_DIR/client_bin"
    return 0
  fi
  if [[ -x "$ROOT_DIR/student/client/client_bin" ]]; then
    printf '%s\n' "$ROOT_DIR/student/client/client_bin"
    return 0
  fi
  return 1
}

if CLIENT_BIN="$(resolve_client_bin 2>/dev/null)"; then
  RUN_MODE="local"
elif command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -qx 'lab04-client'; then
  RUN_MODE="docker"
else
  echo "ERROR: no client runner found."
  echo "Expected one of:"
  echo "  1) local binary at ./client_bin or ./student/client/client_bin"
  echo "  2) running docker container named lab04-client"
  exit 1
fi

run_client() {
  if [[ "$RUN_MODE" == "local" ]]; then
    "$CLIENT_BIN" "$@" 2>&1 || true
  else
    docker exec lab04-client /lab04/client/client_bin "$@" 2>&1 || true
  fi
}

declare -A TOTAL_100 AVG_100 OPS_100
declare -A TOTAL_500 AVG_500 OPS_500

parse_bench_output() {
  local n="$1"
  local out="$2"

  while read -r proto total avg ops; do
    [[ -z "${proto:-}" ]] && continue
    if [[ "$n" == "100" ]]; then
      TOTAL_100["$proto"]="$total"
      AVG_100["$proto"]="$avg"
      OPS_100["$proto"]="$ops"
    else
      TOTAL_500["$proto"]="$total"
      AVG_500["$proto"]="$avg"
      OPS_500["$proto"]="$ops"
    fi
  done < <(printf '%s\n' "$out" | awk '/^[[:space:]]*(net\/rpc|gRPC|REST)[[:space:]]+/ {print $1, $2, $3, $4}')
}

metric_or_na() {
  local val="$1"
  if [[ -n "${val:-}" ]]; then
    printf '%s' "$val"
  else
    printf 'N/A'
  fi
}

rank_order() {
  local n="$1"
  local tmp
  tmp="$(mktemp)"

  for proto in net/rpc gRPC REST; do
    local v=""
    if [[ "$n" == "100" ]]; then
      v="${OPS_100[$proto]:-}"
    else
      v="${OPS_500[$proto]:-}"
    fi

    if [[ "$v" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      printf '%s %s\n' "$proto" "$v" >> "$tmp"
    fi
  done

  if [[ -s "$tmp" ]]; then
    sort -k2,2nr "$tmp" | awk 'BEGIN { first = 1 } { if (!first) printf(" > "); printf("%s", $1); first = 0 } END { print "" }'
  else
    printf 'N/A'
  fi

  rm -f "$tmp"
}

fast_slow_delta() {
  local tmp
  tmp="$(mktemp)"

  for proto in net/rpc gRPC REST; do
    local v="${OPS_100[$proto]:-}"
    if [[ "$v" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      printf '%s %s\n' "$proto" "$v" >> "$tmp"
    fi
  done

  if [[ ! -s "$tmp" ]]; then
    printf 'N/A|N/A|N/A'
    rm -f "$tmp"
    return
  fi

  local fastest slowest fast_v slow_v ratio
  fastest="$(sort -k2,2nr "$tmp" | head -n1 | awk '{print $1}')"
  slowest="$(sort -k2,2nr "$tmp" | tail -n1 | awk '{print $1}')"
  fast_v="$(sort -k2,2nr "$tmp" | head -n1 | awk '{print $2}')"
  slow_v="$(sort -k2,2nr "$tmp" | tail -n1 | awk '{print $2}')"
  ratio="$(awk -v f="$fast_v" -v s="$slow_v" 'BEGIN { if (s > 0) printf "%.2fx", f/s; else printf "N/A" }')"

  printf '%s|%s|%s' "$fastest" "$slowest" "$ratio"
  rm -f "$tmp"
}

printf '\n====================================================\n'
printf ' Experiment B - Benchmark: 100 and 500 Operations\n'
printf '====================================================\n\n'

echo "Running: ./client_bin bench 100"
out100="$(run_client bench 100)"
printf '%s\n' "$out100"
parse_bench_output 100 "$out100"

echo
echo "Running: ./client_bin bench 500"
out500="$(run_client bench 500)"
printf '%s\n' "$out500"
parse_bench_output 500 "$out500"

echo
echo "Benchmark table (filled from this run)"
printf '%-10s | %-18s | %-14s | %-11s | %-14s\n' "Protocol" "100 ops total time" "100 ops avg/op" "100 ops/sec" "500 ops avg/op"
printf -- '-------------------------------------------------------------------------------------------\n'
for proto in net/rpc gRPC REST; do
  printf '%-10s | %-18s | %-14s | %-11s | %-14s\n' \
    "$proto" \
    "$(metric_or_na "${TOTAL_100[$proto]:-}")" \
    "$(metric_or_na "${AVG_100[$proto]:-}")" \
    "$(metric_or_na "${OPS_100[$proto]:-}")" \
    "$(metric_or_na "${AVG_500[$proto]:-}")"
done

REPORT_FILE="$SCRIPT_DIR/experiment-b-results.md"
{
  echo "# Experiment B table - Benchmark Results"
  echo
  echo "| Protocol | 100 ops total time | 100 ops avg/op | 100 ops/sec | 500 ops avg/op |"
  echo "|---|---:|---:|---:|---:|"
  for proto in net/rpc gRPC REST; do
    echo "| $proto | $(metric_or_na "${TOTAL_100[$proto]:-}") | $(metric_or_na "${AVG_100[$proto]:-}") | $(metric_or_na "${OPS_100[$proto]:-}") | $(metric_or_na "${AVG_500[$proto]:-}") |"
  done
} > "$REPORT_FILE"

echo
echo "Table saved to: $REPORT_FILE"

IFS='|' read -r fastest100 slowest100 ratio100 <<< "$(fast_slow_delta)"
order100="$(rank_order 100)"
order500="$(rank_order 500)"

echo
echo "Required observations"
printf '1) Fastest protocol at 100 ops: %s\n' "$fastest100"
printf '2) Slowest protocol at 100 ops: %s\n' "$slowest100"
printf '3) Fastest is approximately %s faster than slowest (100 ops/sec basis).\n' "$ratio100"
echo "4) REST is usually slower due to HTTP overhead, text/JSON encoding, and request parsing."
printf '5) Ranking at 100 ops: %s\n' "$order100"
printf '6) Ranking at 500 ops: %s\n' "$order500"
if [[ "$order100" == "$order500" ]]; then
  echo "7) Ranking change between 100 and 500: NO"
else
  echo "7) Ranking change between 100 and 500: YES"
fi

echo
echo "Experiment B complete."
