#!/bin/bash

# Complete this script to deploy external-service and counter-service in two separate containers
# You will be using the conductor tool that you completed in task 3.

# Creating link to the tool within this directory
# ln -s ../task3/conductor.sh conductor.sh
# ln -s ../task3/config.sh config.sh

# use the above scripts to accomplish the following actions -

# Logical actions to do:
# 1. Build image for the container
# 2. Run two containers say c1 and c2 which should run in background. Tip: to keep the container running
#    in background you should use a init program that will not interact with the terminal and will not
#    exit. e.g. sleep infinity, tail -f /dev/null
# 3. Copy directory external-service to c1 and counter-service to c2 at appropriate location. You can
#    put these directories in the containers by copying them within ".containers/{c1,c2}/rootfs/" directory
# 4. Configure network such that:
#    4.a: c1 is connected to the internet and c1 has its port 8080 forwarded to port 3000 of the host
#    4.b: c2 is connected to the internet and does not have any port exposed
#    4.c: peer network is setup between c1 and c2
# 5. Get ip address of c2. You should use script to get the ip address. 
#    You can use ip interface configuration within the host to get ip address of c2 or you can 
#    exec any command within c2 to get it's ip address
# 6. Within c2 launch the counter service using exec [path to counter-service directory within c2]/run.sh
# 7. Within c1 launch the external service using exec [path to external-service directory within c1]/run.sh
# 8. Within your host system open/curl the url: http://localhost:3000 to verify output of the service
# 9. On any system which can ping the host system open/curl the url: `http://<host-ip>:3000` to verify
#    output of the service

source config.sh

# ./conductor.sh build mydebian

./conductor.sh run mydebian c1 -- tail -f /dev/null > /dev/null &
./conductor.sh run mydebian c2 -- tail -f /dev/null > /dev/null &

sleep 5

cp -r external-service "$CONTAINERDIR/c1/rootfs/home/"
cp -r counter-service "$CONTAINERDIR/c2/rootfs/home/"


./conductor.sh addnetwork c1 -i -e 8080-3000
./conductor.sh addnetwork c2 -i 

./conductor.sh peer c1 c2

read

IP_OUTPUT=$(./conductor.sh exec c2 -- ip -4 -brief address show dev c2-inside)

# C2_IP=`echo "$IP_OUTPUT" | awk '{print $3}' | cut -d'/' -f1`
C2_IP="192.168.2.2"

echo "IP_OUTPUT: $IP_OUTPUT"
echo "C2_IP: $C2_IP"

./conductor.sh exec c2 -- bash /home/counter-service/run.sh &
./conductor.sh exec c1 -- bash /home/external-service/run.sh  "http://$C2_IP:8080"
# ./conductor.sh exec c1 -- /bin/bash -c "cd /home/external-service && echo hello && bash run.sh "http://$C2_IP:8080""


