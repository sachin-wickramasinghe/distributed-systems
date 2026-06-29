#!/usr/bin/env bash
set -euo pipefail

cleanup() {
	docker exec --privileged -u 0 lab03-ap-node3 iptables -F 
}

trap cleanup EXIT

docker exec --privileged -u 0 lab03-ap-node3 iptables -F
docker exec --privileged -u 0 lab03-ap-node3 iptables -A OUTPUT -d 127.0.0.1 -j ACCEPT
docker exec --privileged -u 0 lab03-ap-node3 iptables -A OUTPUT -j DROP

docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 put score 500
docker exec lab03-ap-node3 /lab03/ap/ap_bin -mode cli -port 7000 put score 499

docker exec --privileged -u 0 lab03-ap-node3 iptables -F

sleep 5

docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 get score
docker exec lab03-ap-node2 /lab03/ap/ap_bin -mode cli -port 7000 get score
docker exec lab03-ap-node3 /lab03/ap/ap_bin -mode cli -port 7000 get score
docker exec lab03-ap-node4 /lab03/ap/ap_bin -mode cli -port 7000 get score
docker exec lab03-ap-node5 /lab03/ap/ap_bin -mode cli -port 7000 get score