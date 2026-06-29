#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPIC="updates-exp-d"
SUB_LOG="/tmp/exp_d_sub1.log"

cd "$ROOT_DIR"

printf 'Experiment D\n\n'

printf 'Step 1. Verify required pub/sub containers are running.\n'
for c in lab05-pubsub-broker lab05-publisher lab05-subscriber1; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
    echo "[D] ERROR: required container '$c' is not running. Start docker compose first."
    exit 1
  fi
done

printf 'Step 2. Restart the pub/sub broker to clear previous topic state.\n'
docker restart lab05-pubsub-broker >/dev/null
sleep 2

printf 'Step 3. Ensure subscriber1 is not running and clear its old log.\n'
docker exec lab05-subscriber1 sh -lc "killall pubsub_bin 2>/dev/null || true; rm -f $SUB_LOG"

sleep 1

printf 'Step 4. Publish 5 events to topic %q with no subscribers.\n' "$TOPIC"
docker exec lab05-publisher /lab05/pubsub/pubsub_bin -mode publish -topic "$TOPIC" -key prejoin -value before -count 5

printf 'Step 5. Start subscriber1 on topic %q after the first 5 events.\n' "$TOPIC"
docker exec -d lab05-subscriber1 sh -lc "nohup /lab05/pubsub/pubsub_bin -mode subscribe -topic $TOPIC -id sub1 -port 9100 -host subscriber1 > $SUB_LOG 2>&1"

sleep 2

printf 'Step 6. Publish 3 more events after the subscriber joins.\n'
docker exec lab05-publisher /lab05/pubsub/pubsub_bin -mode publish -topic "$TOPIC" -key postjoin -value after -count 3

sleep 2

printf 'Step 7. Collect subscriber logs to see what the late joiner received.\n'
SUB_OUT="$(docker exec lab05-subscriber1 sh -lc "cat $SUB_LOG 2>/dev/null || true")"
printf '\n[D] Relevant subscriber log lines\n'
printf '%s\n' "$SUB_OUT" | grep '\[SUBSCRIBER\]' || true

received_count="$(printf '%s\n' "$SUB_OUT" | grep -c '\[SUBSCRIBER\] #' || true)"
seqs="$(printf '%s\n' "$SUB_OUT" | grep '\[SUBSCRIBER\] #' | grep -o 'seq=[0-9]*' | cut -d= -f2 | tr '\n' ',' | sed 's/,$//')"

if [[ "$received_count" -ge 1 ]]; then
  min_seq="$(printf '%s\n' "$SUB_OUT" | grep '\[SUBSCRIBER\] #' | grep -o 'seq=[0-9]*' | cut -d= -f2 | sort -n | head -n 1)"
else
  min_seq=""
fi

if [[ -n "$min_seq" && "$min_seq" -le 5 ]]; then
  got_early="Yes"
else
  got_early="No"
fi

if [[ "$received_count" -eq 3 ]]; then
  got_late="Yes (3 events)"
else
  got_late="No (received $received_count)"
fi

kafka_note="Kafka can replay older messages to late consumers from persisted logs using consumer offsets. This lab broker is non-persistent and only delivers live events."

printf '\nPub/Sub Results (Experiment D)\n'
printf '+-----------------------------------------------+----------------------------------------------------------------+\n'
printf '| Experiment                                    | Observation                                                     |\n'
printf '+-----------------------------------------------+----------------------------------------------------------------+\n'
printf '| D - Late subscriber received earlier events?   | %-62s |\n' "$got_early"
printf '| D - Late subscriber received later events?     | %-62s |\n' "$got_late"
printf '| D - Kafka difference                            | %-62s |\n' "$kafka_note"
printf '| D - Observed seq values                         | %-62s |\n' "${seqs:-none}"
printf '+-----------------------------------------------+----------------------------------------------------------------+\n'

printf '\n[D] Observe and record answers\n'
printf -- '-> Did subscriber1 receive the first 5 events published before it joined? %s\n' "$got_early"
printf -- '-> Did subscriber1 receive the 3 events published after it joined? %s\n' "$got_late"
printf -- '-> What would Kafka do differently here? %s\n' "$kafka_note"

printf '\n[D] Cleanup: stopping subscriber1 process\n'
docker exec lab05-subscriber1 sh -lc "killall pubsub_bin 2>/dev/null || true"
