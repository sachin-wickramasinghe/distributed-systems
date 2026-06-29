#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE_NAME="orders-exp-e"
TOPIC="orders-exp-e"
WORKER_LOG="/tmp/exp_e_worker.log"
S1_LOG="/tmp/exp_e_sub1.log"
S2_LOG="/tmp/exp_e_sub2.log"
S3_LOG="/tmp/exp_e_sub3.log"

cd "$ROOT_DIR"

printf 'Experiment E\n\n'

printf 'Step 1. Verify required queue and pub/sub containers are running.\n'
for c in lab05-queue-broker lab05-producer lab05-worker lab05-pubsub-broker lab05-publisher lab05-subscriber1 lab05-subscriber2 lab05-subscriber3; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
    echo "[E] ERROR: required container '$c' is not running. Start docker compose first."
    exit 1
  fi
done

printf 'Step 2. Restart both brokers to clear previous queue and topic state.\n'
docker restart lab05-queue-broker >/dev/null
docker restart lab05-pubsub-broker >/dev/null
sleep 2


# Event Queue half.
printf 'Step 3. Event Queue phase: start 3 workers on queue %q and produce 100 tasks.\n' "$QUEUE_NAME"
docker exec lab05-worker sh -lc "killall queue_bin 2>/dev/null || true; rm -f $WORKER_LOG"
docker exec -d lab05-worker sh -lc "nohup /lab05/queue/queue_bin -mode work -queue $QUEUE_NAME -workers 3 > $WORKER_LOG 2>&1"
sleep 1
docker exec lab05-producer /lab05/queue/queue_bin -mode produce -queue "$QUEUE_NAME" -payload orderE -count 100 >/tmp/exp_e_producer.out 2>&1 || true

printf 'Step 4. Wait for queue processing and collect worker logs.\n'
for _ in $(seq 1 120); do
  processed="$(docker exec lab05-worker sh -lc "grep -c 'Processing task=' $WORKER_LOG 2>/dev/null || true")"
  if [[ "${processed:-0}" -ge 100 ]]; then
    break
  fi
  sleep 0.5
done

WOUT="$(docker exec lab05-worker sh -lc "cat $WORKER_LOG 2>/dev/null || true")"
w1="$(printf '%s\n' "$WOUT" | grep -c '\[WORKER worker-1\] Processing task=' || true)"
w2="$(printf '%s\n' "$WOUT" | grep -c '\[WORKER worker-2\] Processing task=' || true)"
w3="$(printf '%s\n' "$WOUT" | grep -c '\[WORKER worker-3\] Processing task=' || true)"
queue_total=$((w1 + w2 + w3))
docker exec lab05-worker sh -lc "killall queue_bin 2>/dev/null || true"

# Pub/Sub half.
printf 'Step 5. Pub/Sub phase: start 3 subscribers on topic %q.\n' "$TOPIC"
for c in lab05-subscriber1 lab05-subscriber2 lab05-subscriber3; do
  docker exec "$c" sh -lc "killall pubsub_bin 2>/dev/null || true"
done

docker exec lab05-subscriber1 sh -lc "rm -f $S1_LOG"
docker exec lab05-subscriber2 sh -lc "rm -f $S2_LOG"
docker exec lab05-subscriber3 sh -lc "rm -f $S3_LOG"

docker exec -d lab05-subscriber1 sh -lc "nohup /lab05/pubsub/pubsub_bin -mode subscribe -topic $TOPIC -id inventory -port 9100 -host subscriber1 > $S1_LOG 2>&1"
docker exec -d lab05-subscriber2 sh -lc "nohup /lab05/pubsub/pubsub_bin -mode subscribe -topic $TOPIC -id billing -port 9100 -host subscriber2 > $S2_LOG 2>&1"
docker exec -d lab05-subscriber3 sh -lc "nohup /lab05/pubsub/pubsub_bin -mode subscribe -topic $TOPIC -id shipping -port 9100 -host subscriber3 > $S3_LOG 2>&1"

sleep 2
printf 'Step 6. Publish 100 events to topic %q.\n' "$TOPIC"
docker exec lab05-publisher /lab05/pubsub/pubsub_bin -mode publish -topic "$TOPIC" -key order -value placed -count 100 >/tmp/exp_e_publish.out 2>&1 || true

printf 'Step 7. Collect subscriber logs and compare queue vs pub/sub results.\n'
for _ in $(seq 1 80); do
  s1="$(docker exec lab05-subscriber1 sh -lc "grep -c '\\[SUBSCRIBER\\] #' $S1_LOG 2>/dev/null || true")"
  s2="$(docker exec lab05-subscriber2 sh -lc "grep -c '\\[SUBSCRIBER\\] #' $S2_LOG 2>/dev/null || true")"
  s3="$(docker exec lab05-subscriber3 sh -lc "grep -c '\\[SUBSCRIBER\\] #' $S3_LOG 2>/dev/null || true")"
  if [[ "${s1:-0}" -ge 100 && "${s2:-0}" -ge 100 && "${s3:-0}" -ge 100 ]]; then
    break
  fi
  sleep 0.5
done

s1="$(docker exec lab05-subscriber1 sh -lc "grep -c '\\[SUBSCRIBER\\] #' $S1_LOG 2>/dev/null || true")"
s2="$(docker exec lab05-subscriber2 sh -lc "grep -c '\\[SUBSCRIBER\\] #' $S2_LOG 2>/dev/null || true")"
s3="$(docker exec lab05-subscriber3 sh -lc "grep -c '\\[SUBSCRIBER\\] #' $S3_LOG 2>/dev/null || true")"

pattern_note="Pub/Sub is correct for inventory, billing, shipping because each service must receive every order event. Event Queue would split work across workers instead of broadcasting."

printf '\nPattern Comparison (Experiment E)\n'
printf '+--------------------------------------+------------------------------+------------------------------+\n'
printf '| Property                             | Event Queue                  | Pub/Sub                      |\n'
printf '+--------------------------------------+------------------------------+------------------------------+\n'
printf '| Each message delivered to            | One worker only              | All subscribers              |\n'
printf '| Best for                             | Work distribution            | Broadcast to many services   |\n'
printf '| New consumer sees old messages?      | No                           | No (in this lab)             |\n'
printf '+--------------------------------------+------------------------------+------------------------------+\n'

printf '\nExperiment E Observations\n'
printf '+--------------------------------------+---------------------------------------------------------------+\n'
printf '| Observation                           | Value                                                         |\n'
printf '+--------------------------------------+---------------------------------------------------------------+\n'
printf '| Queue tasks per worker (out of 100)   | W1: %-3s W2: %-3s W3: %-3s (total=%-3s)                      |\n' "$w1" "$w2" "$w3" "$queue_total"
printf '| Pub/Sub events per subscriber         | inventory: %-3s billing: %-3s shipping: %-3s                 |\n' "$s1" "$s2" "$s3"
printf '| Correct pattern for 3-service scenario| %-61s |\n' "$pattern_note"
printf '+--------------------------------------+---------------------------------------------------------------+\n'

printf '\n[E] Observe and record answers\n'
printf -- '-> With Event Queue, how many of the 100 tasks did each worker process? W1=%s W2=%s W3=%s\n' "$w1" "$w2" "$w3"
printf -- '-> With Pub/Sub, how many of the 100 events did each subscriber receive? inventory=%s billing=%s shipping=%s\n' "$s1" "$s2" "$s3"
printf -- '-> Which pattern is correct for the 3-services scenario? Why? %s\n' "$pattern_note"

printf '\n[E] Relevant queue worker log sample\n'
printf '%s\n' "$WOUT" | grep 'Processing task=' | head -n 15 || true

printf '\n[E] Relevant pubsub subscriber samples\n'
printf '\n--- subscriber1 ---\n'
docker exec lab05-subscriber1 sh -lc "grep '\[SUBSCRIBER\] #' $S1_LOG | head -n 5" || true
printf '\n--- subscriber2 ---\n'
docker exec lab05-subscriber2 sh -lc "grep '\[SUBSCRIBER\] #' $S2_LOG | head -n 5" || true
printf '\n--- subscriber3 ---\n'
docker exec lab05-subscriber3 sh -lc "grep '\[SUBSCRIBER\] #' $S3_LOG | head -n 5" || true
