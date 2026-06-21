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

now_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
  else
    date +%s%3N
  fi
}

run_client() {
  if [[ "$RUN_MODE" == "local" ]]; then
    "$CLIENT_BIN" "$@" 2>&1 || true
  else
    docker exec lab04-client /lab04/client/client_bin "$@" 2>&1 || true
  fi
}

is_get_success() {
  local text="$1"
  if printf '%s' "$text" | grep -qiE 'not found|failed|connect failed|not available'; then
    return 1
  fi
  if printf '%s' "$text" | grep -q 'value='; then
    return 0
  fi
  return 1
}

measure_get_ms() {
  local proto="$1"
  local key="$2"

  local start end out
  start="$(now_ms)"
  out="$(run_client "$proto" get "$key")"
  end="$(now_ms)"

  if is_get_success "$out"; then
    echo $((end - start))
  else
    echo "NA"
  fi
}

printf '\n====================================================\n'
printf ' Experiment D - Large Values (~10,000 chars)\n'
printf '====================================================\n\n'

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

if command -v python3 >/dev/null 2>&1; then
  python3 -c "print('x'*10000)" > "$tmp_file"
else
  head -c 10000 < /dev/zero | tr '\0' 'x' > "$tmp_file"
fi
VAL="$(cat "$tmp_file")"

echo "Generated large value of size: $(wc -c < "$tmp_file") bytes"
echo

echo "Step 1: Store large value via each protocol"
out_rpc_put="$(run_client rpc put bigkey "$VAL")"
out_grpc_put="$(run_client grpc put bigkey "$VAL")"
out_rest_put="$(run_client rest put bigkey "$VAL")"
echo "[rpc put bigkey]"
printf '%s\n' "$out_rpc_put"
echo "[grpc put bigkey]"
printf '%s\n' "$out_grpc_put"
echo "[rest put bigkey]"
printf '%s\n' "$out_rest_put"

declare -A GET_MS

echo
echo "Step 2: Time get operation for each protocol"
GET_MS[rpc]="$(measure_get_ms rpc bigkey)"
GET_MS[grpc]="$(measure_get_ms grpc bigkey)"
GET_MS[rest]="$(measure_get_ms rest bigkey)"

printf '%-10s | %-10s\n' "Protocol" "Get time"
printf -- '-------------------------\n'
for proto in rpc grpc rest; do
  if [[ "${GET_MS[$proto]}" == "NA" ]]; then
    printf '%-10s | %-10s\n' "$proto" "FAILED"
  else
    printf '%-10s | %-10sms\n' "$proto" "${GET_MS[$proto]}"
  fi
done

ranked="$(
  for proto in rpc grpc rest; do
    if [[ "${GET_MS[$proto]}" =~ ^[0-9]+$ ]]; then
      printf '%s %s\n' "$proto" "${GET_MS[$proto]}"
    fi
  done | sort -k2,2n
)"

echo
echo "Required observations"
if [[ -n "$ranked" ]]; then
  fastest="$(printf '%s\n' "$ranked" | head -n1 | awk '{print $1}')"
  slowest="$(printf '%s\n' "$ranked" | tail -n1 | awk '{print $1}')"
  order="$(printf '%s\n' "$ranked" | awk 'BEGIN { first = 1 } { if (!first) printf(" < "); printf("%s", $1); first = 0 } END { print "" }')"
  echo "1) Fastest protocol for large value get: $fastest"
  echo "2) Slowest protocol for large value get: $slowest"
  echo "3) Relative order (low latency to high latency): $order"
  echo "4) Compare with Experiment B order to decide whether ranking changed for large values."
else
  echo "Unable to rank protocols because get operations failed."
fi

echo
echo "Experiment D complete."
