docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 put k1 v1
docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 put k2 v2
docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 put k3 v3
docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 put k4 v4
docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 put k5 v5

sleep 3

docker exec lab03-ap-node5 /lab03/ap/ap_bin -mode cli -port 7000 get k1
docker exec lab03-ap-node5 /lab03/ap/ap_bin -mode cli -port 7000 get k2
docker exec lab03-ap-node5 /lab03/ap/ap_bin -mode cli -port 7000 get k3
docker exec lab03-ap-node5 /lab03/ap/ap_bin -mode cli -port 7000 get k4
docker exec lab03-ap-node5 /lab03/ap/ap_bin -mode cli -port 7000 get k5
