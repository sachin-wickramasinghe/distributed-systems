docker exec lab03-ap-node1 /lab03/ap/ap_bin -mode cli -port 7000 put version 1
docker exec lab03-ap-node5 /lab03/ap/ap_bin -mode cli -port 7000 get version
sleep 3
docker exec lab03-ap-node5 /lab03/ap/ap_bin -mode cli -port 7000 get version