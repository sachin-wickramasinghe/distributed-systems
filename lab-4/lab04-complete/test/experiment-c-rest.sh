#!/usr/bin/env bash
set -euo pipefail

REST_BASE_URL="${REST_BASE_URL:-http://localhost:8080}"
RPC_HTTP_PROBE_URL="${RPC_HTTP_PROBE_URL:-http://localhost:7000}"
GRPC_HTTP_PROBE_URL="${GRPC_HTTP_PROBE_URL:-http://localhost:7001}"

printf '\n====================================================\n'
printf ' Experiment C - REST from Browser and curl\n'
printf '====================================================\n\n'

echo "Step 1: Browser checks (manual)"
echo "Open in browser: ${REST_BASE_URL}/keys"
echo "Open in browser: ${REST_BASE_URL}/keys/city"
echo

echo "Step 2: Prepare a known key using curl"
put_out="$(curl -sS -m 5 -X PUT "${REST_BASE_URL}/keys/city" -H 'Content-Type: application/json' -d '{"value":"London"}' 2>&1 || true)"
printf '%s\n' "$put_out"
echo

echo "Step 3: Read REST endpoints with curl"
keys_out="$(curl -sS -m 5 "${REST_BASE_URL}/keys" 2>&1 || true)"
city_out="$(curl -sS -m 5 "${REST_BASE_URL}/keys/city" 2>&1 || true)"
echo "GET ${REST_BASE_URL}/keys"
printf '%s\n' "$keys_out"
echo
echo "GET ${REST_BASE_URL}/keys/city"
printf '%s\n' "$city_out"
echo

echo "Step 4: Try calling net/rpc and gRPC directly with curl (expected to fail)"
rpc_probe="$(curl -sS -m 5 -i "${RPC_HTTP_PROBE_URL}" 2>&1 || true)"
grpc_probe="$(curl -sS -m 5 -i "${GRPC_HTTP_PROBE_URL}" 2>&1 || true)"
echo "curl ${RPC_HTTP_PROBE_URL}"
printf '%s\n' "$rpc_probe"
echo
echo "curl ${GRPC_HTTP_PROBE_URL}"
printf '%s\n' "$grpc_probe"

echo
echo "Required observations"
if printf '%s' "$keys_out" | grep -q '"keys"'; then
  echo "1) Browser/curl REST call status: SUCCESS (REST responds with JSON)."
else
  echo "1) Browser/curl REST call status: CHECK NEEDED (no JSON list detected)."
fi
echo "2) Browser can call REST because it uses HTTP/JSON, which browsers natively support."
echo "3) Browser cannot directly call net/rpc (custom TCP protocol) and usually cannot call raw gRPC without gRPC-Web support."
echo "4) For web apps, expose REST or gRPC-Web at backend/API gateway, not raw net/rpc."

echo
echo "Experiment C complete."
