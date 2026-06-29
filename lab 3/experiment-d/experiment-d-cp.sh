docker stop lab03-cp-node3 lab03-cp-node4 lab03-cp-node5

docker exec lab03-cp-node1 /lab03/cp/cp_bin -mode cli -port 8000 put alert critical-2
docker exec lab03-cp-node1 /lab03/cp/cp_bin -mode cli -port 8000 get alert
docker exec lab03-cp-node2 /lab03/cp/cp_bin -mode cli -port 8000 get alert

docker start lab03-cp-node3 lab03-cp-node4 lab03-cp-node5
# sleep 5

# docker exec lab03-cp-node1 /lab03/cp/cp_bin -mode cli -port 8000 get alert
# docker exec lab03-cp-node2 /lab03/cp/cp_bin -mode cli -port 8000 get alert
# docker exec lab03-cp-node3 /lab03/cp/cp_bin -mode cli -port 8000 get alert
# docker exec lab03-cp-node4 /lab03/cp/cp_bin -mode cli -port 8000 get alert
# docker exec lab03-cp-node5 /lab03/cp/cp_bin -mode cli -port 8000 get alert

start_ms=$(date +%s%3N)

docker start lab03-cp-node3 lab03-cp-node4 lab03-cp-node5

while true; do
  ok3=$(docker exec lab03-cp-node3 /lab03/cp/cp_bin -mode cli -port 8000 get alert | grep -c 'value="critical-2"' || true)
  ok4=$(docker exec lab03-cp-node4 /lab03/cp/cp_bin -mode cli -port 8000 get alert | grep -c 'value="critical-2"' || true)
  ok5=$(docker exec lab03-cp-node5 /lab03/cp/cp_bin -mode cli -port 8000 get alert | grep -c 'value="critical-2"' || true)

  if [ "$ok3" -gt 0 ] && [ "$ok4" -gt 0 ] && [ "$ok5" -gt 0 ]; then
    end_ms=$(date +%s%3N)
    echo "Recovery time: $((end_ms - start_ms)) ms"
    break
  fi
  sleep 0.2
done