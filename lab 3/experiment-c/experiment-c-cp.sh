docker stop lab03-cp-node4 lab03-cp-node5

docker exec lab03-cp-node1 /lab03/cp/cp_bin -mode cli -port 8000 put status active
docker exec lab03-cp-node1 /lab03/cp/cp_bin -mode cli -port 8000 get status
docker exec lab03-cp-node2 /lab03/cp/cp_bin -mode cli -port 8000 get status
docker exec lab03-cp-node3 /lab03/cp/cp_bin -mode cli -port 8000 get status

docker start lab03-cp-node4 lab03-cp-node5