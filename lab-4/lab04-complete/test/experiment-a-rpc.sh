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

printf '\n====================================================\n'
printf ' Experiment A - Cross-Protocol Data Sharing\n'
printf '====================================================\n\n'

echo "Step 0: Reset keys used in this experiment"
for proto in rpc grpc rest; do
  run_client "$proto" delete key_rpc >/dev/null
  run_client "$proto" delete key_grpc >/dev/null
  run_client "$proto" delete key_rest >/dev/null
done

echo "Step 1: Write 3 keys using 3 protocols"
out_rpc_put="$(run_client rpc put key_rpc value_from_rpc)"
out_grpc_put="$(run_client grpc put key_grpc value_from_grpc)"
out_rest_put="$(run_client rest put key_rest value_from_rest)"

echo "[rpc put key_rpc]"
printf '%s\n' "$out_rpc_put"
echo "[grpc put key_grpc]"
printf '%s\n' "$out_grpc_put"
echo "[rest put key_rest]"
printf '%s\n' "$out_rest_put"

declare -A KEY_BY_WRITER=(
  [rpc]=key_rpc
  [grpc]=key_grpc
  [rest]=key_rest
)

declare -A RESULT=()

echo
echo "Step 2: Read all keys with all protocols (9 reads)"
for writer in rpc grpc rest; do
  key="${KEY_BY_WRITER[$writer]}"
  for reader in rpc grpc rest; do
    out="$(run_client "$reader" get "$key")"
    if is_get_success "$out"; then
      RESULT["$writer|$reader"]="WORKED"
    else
      RESULT["$writer|$reader"]="FAILED"
    fi
    printf 'write=%-4s read=%-4s key=%-9s => %s\n' "$writer" "$reader" "$key" "${RESULT[$writer|$reader]}"
  done
done

echo
echo "Step 3: Matrix (write protocol x read protocol)"
printf '%-14s | %-7s | %-7s | %-7s\n' "Write\\Read" "rpc" "grpc" "rest"
printf -- '------------------------------------------------\n'
for writer in rpc grpc rest; do
  printf '%-14s | %-7s | %-7s | %-7s\n' \
    "$writer" \
    "${RESULT[$writer|rpc]}" \
    "${RESULT[$writer|grpc]}" \
    "${RESULT[$writer|rest]}"
done

echo
echo "Required observations"
printf '1) Read via gRPC key written via net/rpc: %s\n' "${RESULT[rpc|grpc]}"
printf '2) Read via REST key written via gRPC: %s\n' "${RESULT[grpc|rest]}"
if [[ "${RESULT[rpc|grpc]}" == "WORKED" && "${RESULT[grpc|rest]}" == "WORKED" ]]; then
  echo "3) Interpretation: protocols are different interfaces over the SAME shared store."
else
  echo "3) Interpretation: one or more protocol paths are not sharing data or are not reachable."
fi

echo
echo "Experiment A complete."
