#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPIC="news-exp-c"
S1_LOG="/tmp/exp_c_sub1.log"
S2_LOG="/tmp/exp_c_sub2.log"
S3_LOG="/tmp/exp_c_sub3.log"

cd "$ROOT_DIR"

printf 'Experiment C\n\n'

printf 'Step 1. Verify required pub/sub containers are running.\n'
for c in lab05-pubsub-broker lab05-publisher lab05-subscriber1 lab05-subscriber2 lab05-subscriber3; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
    echo "[C] ERROR: required container '$c' is not running. Start docker compose first."
    exit 1
  fi
done

printf 'Step 2. Restart the pub/sub broker to clear previous topic state.\n'
docker restart lab05-pubsub-broker >/dev/null
sleep 2

printf 'Step 3. Reset subscriber processes and old subscriber logs.\n'
for c in lab05-subscriber1 lab05-subscriber2 lab05-subscriber3; do
  docker exec "$c" sh -lc "killall pubsub_bin 2>/dev/null || true"
done
docker exec lab05-subscriber1 sh -lc "rm -f $S1_LOG"
docker exec lab05-subscriber2 sh -lc "rm -f $S2_LOG"
docker exec lab05-subscriber3 sh -lc "rm -f $S3_LOG"

printf 'Step 4. Start 3 subscribers on topic %q.\n' "$TOPIC"
docker exec -d lab05-subscriber1 sh -lc "nohup /lab05/pubsub/pubsub_bin -mode subscribe -topic $TOPIC -id sub1 -port 9100 -host subscriber1 > $S1_LOG 2>&1"
docker exec -d lab05-subscriber2 sh -lc "nohup /lab05/pubsub/pubsub_bin -mode subscribe -topic $TOPIC -id sub2 -port 9100 -host subscriber2 > $S2_LOG 2>&1"
docker exec -d lab05-subscriber3 sh -lc "nohup /lab05/pubsub/pubsub_bin -mode subscribe -topic $TOPIC -id sub3 -port 9100 -host subscriber3 > $S3_LOG 2>&1"

sleep 2

printf 'Step 5. Publish 5 events to topic %q.\n' "$TOPIC"
PUBLISH_OUT="$(docker exec lab05-publisher /lab05/pubsub/pubsub_bin -mode publish -topic "$TOPIC" -key headline -value fanout -count 5)"
printf '%s\n' "$PUBLISH_OUT"

sleep 2

printf 'Step 6. Collect subscriber logs and compare deliveries and sequence numbers.\n'
SUB1="$(docker exec lab05-subscriber1 sh -lc "cat $S1_LOG 2>/dev/null || true")"
SUB2="$(docker exec lab05-subscriber2 sh -lc "cat $S2_LOG 2>/dev/null || true")"
SUB3="$(docker exec lab05-subscriber3 sh -lc "cat $S3_LOG 2>/dev/null || true")"

printf '\n[C] Relevant subscriber logs\n'
printf '\n--- subscriber1 ---\n%s\n' "$(printf '%s\n' "$SUB1" | grep '\[SUBSCRIBER\]' || true)"
printf '\n--- subscriber2 ---\n%s\n' "$(printf '%s\n' "$SUB2" | grep '\[SUBSCRIBER\]' || true)"
printf '\n--- subscriber3 ---\n%s\n' "$(printf '%s\n' "$SUB3" | grep '\[SUBSCRIBER\]' || true)"

c1="$(printf '%s\n' "$SUB1" | grep -c '\[SUBSCRIBER\] #' || true)"
c2="$(printf '%s\n' "$SUB2" | grep -c '\[SUBSCRIBER\] #' || true)"
c3="$(printf '%s\n' "$SUB3" | grep -c '\[SUBSCRIBER\] #' || true)"

if [[ "$c1" -eq 5 && "$c2" -eq 5 && "$c3" -eq 5 ]]; then
  all5="Yes"
else
  all5="No (sub1=$c1 sub2=$c2 sub3=$c3)"
fi

seq1="$(printf '%s\n' "$SUB1" | grep '\[SUBSCRIBER\] #' | grep -o 'seq=[0-9]*' | cut -d= -f2 | tr '\n' ',' | sed 's/,$//')"
seq2="$(printf '%s\n' "$SUB2" | grep '\[SUBSCRIBER\] #' | grep -o 'seq=[0-9]*' | cut -d= -f2 | tr '\n' ',' | sed 's/,$//')"
seq3="$(printf '%s\n' "$SUB3" | grep '\[SUBSCRIBER\] #' | grep -o 'seq=[0-9]*' | cut -d= -f2 | tr '\n' ',' | sed 's/,$//')"

if [[ -n "$seq1" && "$seq1" == "$seq2" && "$seq2" == "$seq3" ]]; then
  seq_match="Yes ($seq1)"
else
  seq_match="No"
fi

fanout_note="Pub/Sub fan-out delivers each published event to all subscribers, unlike queue work distribution where one task goes to one worker."

printf '\nPub/Sub Results (Experiment C)\n'
printf '+-----------------------------------------------+-------------------------------------------------------------+\n'
printf '| Experiment                                    | Observation                                                  |\n'
printf '+-----------------------------------------------+-------------------------------------------------------------+\n'
printf '| C - All 3 subscribers got all 5 events?       | %-59s |\n' "$all5"
printf '| C - Sequence numbers matched?                 | %-59s |\n' "$seq_match"
printf '| C - Fan-out vs work distribution              | %-59s |\n' "$fanout_note"
printf '+-----------------------------------------------+-------------------------------------------------------------+\n'

printf '\n[C] Observe and record answers\n'
printf -- '-> Did ALL 3 subscribers receive ALL 5 events? %s\n' "$all5"
printf -- '-> Did sequence numbers (seq) match across all subscribers? %s\n' "$seq_match"
printf -- '-> How is fan-out different from Experiment A work distribution? %s\n' "$fanout_note"

printf '\n[C] Cleanup: stopping subscriber processes\n'
for c in lab05-subscriber1 lab05-subscriber2 lab05-subscriber3; do
  docker exec "$c" sh -lc "killall pubsub_bin 2>/dev/null || true"
done
