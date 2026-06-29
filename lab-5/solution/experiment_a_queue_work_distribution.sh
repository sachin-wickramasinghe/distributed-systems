#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE_NAME="orders-exp-a"
WORKER_LOG="/tmp/exp_a_worker.log"

cd "$ROOT_DIR"

printf 'Experiment A\n\n'

printf 'Step 1. Verify required queue containers are running.\n'
for c in lab05-queue-broker lab05-producer lab05-worker; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
    echo "[A] ERROR: required container '$c' is not running. Start docker compose first."
    exit 1
  fi
done

printf 'Step 2. Restart the queue broker to clear previous queue state.\n'
echo "[A] Using existing running Docker stack"
docker restart lab05-queue-broker >/dev/null
sleep 2

printf 'Step 3. Reset worker process state and old worker logs.\n'
docker exec lab05-worker sh -lc "killall queue_bin 2>/dev/null || true; rm -f $WORKER_LOG"

printf 'Step 4. Start 3 workers on queue %q.\n' "$QUEUE_NAME"
docker exec -d lab05-worker sh -lc "nohup /lab05/queue/queue_bin -mode work -queue $QUEUE_NAME -workers 3 > $WORKER_LOG 2>&1"
sleep 1

printf 'Step 5. Produce 20 tasks to queue %q.\n' "$QUEUE_NAME"
PRODUCER_OUT="$(docker exec lab05-producer /lab05/queue/queue_bin -mode produce -queue "$QUEUE_NAME" -payload orderA -count 20)"
printf '%s\n' "$PRODUCER_OUT"

mapfile -t PRODUCED_IDS < <(printf '%s\n' "$PRODUCER_OUT" | grep -o 'task=[^ ]*' | cut -d= -f2)

printf 'Step 6. Wait for processing to complete and collect worker logs.\n'
# Wait until worker log shows all 20 processed lines or timeout.
for _ in $(seq 1 40); do
  processed_count="$(docker exec lab05-worker sh -lc "grep -c 'Processing task=' $WORKER_LOG 2>/dev/null || true")"
  if [[ "${processed_count:-0}" -ge 20 ]]; then
    break
  fi
  sleep 0.5
done

WORKER_OUT="$(docker exec lab05-worker sh -lc "cat $WORKER_LOG 2>/dev/null || true")"

printf '\n[A] Relevant worker log lines\n'
printf '%s\n' "$WORKER_OUT" | grep 'Processing task=\|Done task=' || true

mapfile -t PROCESSED_IDS < <(printf '%s\n' "$WORKER_OUT" | grep -o 'Processing task=[^ ]*' | cut -d= -f2)

w1="$(printf '%s\n' "$WORKER_OUT" | grep -c '\[WORKER worker-1\] Processing task=' || true)"
w2="$(printf '%s\n' "$WORKER_OUT" | grep -c '\[WORKER worker-2\] Processing task=' || true)"
w3="$(printf '%s\n' "$WORKER_OUT" | grep -c '\[WORKER worker-3\] Processing task=' || true)"

total_produced="${#PRODUCED_IDS[@]}"
total_processed="${#PROCESSED_IDS[@]}"
unique_processed="$(printf '%s\n' "${PROCESSED_IDS[@]:-}" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')"

if [[ "$total_processed" -eq "$unique_processed" ]]; then
  duplicates="No"
else
  duplicates="Yes"
fi

lost=0
for id in "${PRODUCED_IDS[@]}"; do
  if ! printf '%s\n' "${PROCESSED_IDS[@]:-}" | grep -qx "$id"; then
    lost=$((lost + 1))
  fi
done

if [[ "$lost" -eq 0 ]]; then
  lost_text="No"
else
  lost_text="Yes ($lost lost)"
fi

if [[ "$duplicates" == "No" && "$lost" -eq 0 ]]; then
  one_worker_each="Yes"
else
  one_worker_each="No"
fi

max_w="$w1"
min_w="$w1"
for v in "$w2" "$w3"; do
  if [[ "$v" -gt "$max_w" ]]; then
    max_w="$v"
  fi
  if [[ "$v" -lt "$min_w" ]]; then
    min_w="$v"
  fi
done
if [[ $((max_w - min_w)) -le 5 ]]; then
  roughly_even="Yes"
else
  roughly_even="No"
fi

printf '\nEvent Queue Results (Experiment A)\n'
printf '+-----------------------------------------+-------------------------------------------+\n'
printf '| Experiment                              | Observation                                |\n'
printf '+-----------------------------------------+-------------------------------------------+\n'
printf '| A - Tasks per worker (out of 20)        | W1: %-3s W2: %-3s W3: %-3s                 |\n' "$w1" "$w2" "$w3"
printf '| A - Any duplicates or lost tasks?       | Duplicates: %-3s Lost: %-12s               |\n' "$duplicates" "$lost_text"
printf '+-----------------------------------------+-------------------------------------------+\n'

printf '\n[A] Observe and record answers\n'
printf -- '-> Was each task processed by exactly ONE worker? Any duplicates? %s (duplicates: %s)\n' "$one_worker_each" "$duplicates"
printf -- '-> Were tasks distributed roughly evenly across 3 workers? %s (W1=%s W2=%s W3=%s)\n' "$roughly_even" "$w1" "$w2" "$w3"
printf -- '-> Were any tasks lost (never processed)? %s\n' "$lost_text"

echo "----------------------------------------------------------"
printf '\n[A] Cleanup: stopping worker process\n'
if docker exec lab05-worker sh -lc "pgrep -x queue_bin >/dev/null"; then
  docker exec lab05-worker sh -lc "killall queue_bin"
else
  echo "[A] Cleanup: no queue_bin process running"
fi
