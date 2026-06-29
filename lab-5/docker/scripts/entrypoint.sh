#!/bin/bash
echo "============================================"
echo " Lab 05 — Event Queues and Pub/Sub"
echo " Role: ${ROLE}"
echo "============================================"

case "$ROLE" in
  queue-broker)
    cd /lab05/queue
    ./queue_bin -mode broker -port 9000 &
    ;;
  pubsub-broker)
    cd /lab05/pubsub
    ./pubsub_bin -mode broker -port 9001 &
    ;;
  subscriber)
    cd /lab05/pubsub
    ./pubsub_bin -mode subscribe -broker "${BROKER_ADDR:-pubsub-broker:9001}" -topic "${SUB_TOPIC:-news}" -id "${SUB_ID:-sub1}" -port "${SUB_PORT:-9100}" -host "${SUB_HOST:-localhost}" &
    ;;
  idle)
    echo "[ENTRYPOINT] Idle container — use docker exec to run commands"
    ;;
  *)
    echo "[ENTRYPOINT] Unknown ROLE '${ROLE}' — staying idle"
    ;;
esac

tail -f /dev/null
