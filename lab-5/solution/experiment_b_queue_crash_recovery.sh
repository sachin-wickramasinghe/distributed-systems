#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE_NAME="orders-exp-b"
W1_LOG="/tmp/exp_b_worker1.log"
W2_LOG="/tmp/exp_b_worker2.log"

cd "$ROOT_DIR"

printf 'Experiment B\n\n'

printf 'Step 1. Verify required queue containers are running.\n'
for c in lab05-queue-broker lab05-producer lab05-worker; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
    echo "[B] ERROR: required container '$c' is not running. Start docker compose first."
    exit 1
  fi
done

printf 'Step 2. Restart the queue broker to clear previous queue state.\n'
docker restart lab05-queue-broker >/dev/null
sleep 2

printf 'Step 3. Reset old worker processes and logs.\n'
docker exec lab05-worker sh -lc "killall queue_bin 2>/dev/null || true; rm -f $W1_LOG $W2_LOG"

printf 'Step 4. Start 1 worker on queue %q.\n' "$QUEUE_NAME"
docker exec -d lab05-worker sh -lc "nohup /lab05/queue/queue_bin -mode work -queue $QUEUE_NAME -workers 1 > $W1_LOG 2>&1"
sleep 1

printf 'Step 5. Produce 5 tasks to queue %q.\n' "$QUEUE_NAME"
PRODUCER_OUT="$(docker exec lab05-producer /lab05/queue/queue_bin -mode produce -queue "$QUEUE_NAME" -payload orderB -count 5)"
printf '%s\n' "$PRODUCER_OUT"

# Kill quickly to maximize chance worker dies before ack.
sleep 0.05
KILL_EPOCH="$(date +%s)"
printf 'Step 6. Kill the worker before ack to simulate a crash.\n'
docker exec lab05-worker sh -lc "killall queue_bin 2>/dev/null || true"

START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

printf 'Step 7. Start a new worker on the same queue.\n'
docker exec -d lab05-worker sh -lc "nohup /lab05/queue/queue_bin -mode work -queue $QUEUE_NAME -workers 1 > $W2_LOG 2>&1"

printf 'Step 8. Wait for stale-delivery redelivery and collect logs.\n'
stale_line=""
for _ in $(seq 1 30); do
  BROKER_LOGS="$(docker logs --timestamps --since "$START_ISO" lab05-queue-broker 2>&1 || true)"
  stale_line="$(printf '%s\n' "$BROKER_LOGS" | grep 'appears stuck (worker may have crashed) — redelivering' | tail -n 1 || true)"
  if [[ -n "$stale_line" ]]; then
    break
  fi
  sleep 0.5
done

sleep 2
W2_OUT="$(docker exec lab05-worker sh -lc "cat $W2_LOG 2>/dev/null || true")"

printf '\n[B] Relevant broker logs\n'
printf '%s\n' "${BROKER_LOGS:-}" | grep 'appears stuck\|Nacked task=' || true
printf '\n[B] Relevant new-worker logs\n'
printf '%s\n' "$W2_OUT" | grep 'Processing task=\|Done task=' || true

redelivered="No"
redelivery_secs="N/A"
redelivered_task="N/A"
redelivery_worker="N/A"

if [[ -n "$stale_line" ]]; then
  redelivered="Yes"
  ts="$(printf '%s\n' "$stale_line" | awk '{print $1}')"
  if redeliver_epoch="$(date -d "$ts" +%s 2>/dev/null)"; then
    redelivery_secs="$((redeliver_epoch - KILL_EPOCH))"
  fi
  redelivered_task="$(printf '%s\n' "$stale_line" | grep -o 'Task [^ ]*' | awk '{print $2}')"
  if [[ -n "$redelivered_task" ]]; then
    redelivery_worker_line="$(printf '%s\n' "$W2_OUT" | grep "Processing task=$redelivered_task" | head -n 1 || true)"
    redelivery_worker="$(printf '%s\n' "$redelivery_worker_line" | grep -o '\[WORKER [^]]*\]' | sed 's/\[WORKER //; s/\]//' || true)"
    redelivery_worker="${redelivery_worker:-unknown}"
  fi
fi

ack_before_note="Task loss risk increases. If Ack happened before processing and worker crashed mid-task, that task could be permanently lost instead of redelivered."

printf '\nEvent Queue Results (Experiment B)\n'
printf '+----------------------------------------------+---------------------------------------------------------------+\n'
printf '| Experiment                                   | Observation                                                    |\n'
printf '+----------------------------------------------+---------------------------------------------------------------+\n'
printf '| B - Did in-progress task get redelivered?    | %-61s |\n' "$redelivered"
printf '| B - Redelivery time (seconds)                | %-61s |\n' "$redelivery_secs"
printf '| B - Which worker got redelivered task?       | %-61s |\n' "${redelivery_worker} (task ${redelivered_task})"
printf '| B - If Ack happened before processing?        | %-61s |\n' "$ack_before_note"
printf '+----------------------------------------------+---------------------------------------------------------------+\n'

printf '\n[B] Observe and record answers\n'
printf -- '-> Did the in-progress task get redelivered to the new worker? %s\n' "$redelivered"
printf -- '-> How long did it take before redelivery happened? %s seconds\n' "$redelivery_secs"
printf -- '-> What would happen if Ack happened BEFORE processing? %s\n' "$ack_before_note"

printf '\n[B] Cleanup: stopping worker processes\n'
docker exec lab05-worker sh -lc "killall queue_bin 2>/dev/null || true"
