docker stop lab03-ap-node4 lab03-ap-node5

docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 put status active
docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 get status
docker exec lab03-ap-node2 /lab03/ap/ap_bin -mode cli -port 7000 get status
docker exec lab03-ap-node3 /lab03/ap/ap_bin -mode cli -port 7000 get status

docker start lab03-ap-node4 lab03-ap-node5
sleep 5

docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 get status
docker exec lab03-ap-node2 /lab03/ap/ap_bin -mode cli -port 7000 get status
docker exec lab03-ap-node3 /lab03/ap/ap_bin -mode cli -port 7000 get status
docker exec lab03-ap-node4 /lab03/ap/ap_bin -mode cli -port 7000 get status
docker exec lab03-ap-node5 /lab03/ap/ap_bin -mode cli -port 7000 get status