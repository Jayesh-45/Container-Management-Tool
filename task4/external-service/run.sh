#!/bin/bash

# This script takes an argument for the url of the counter-service
# which the external-service will use to get visit counter

cd "$(dirname "$0")"

apt update
apt install -y python3 python3-flask python3-requests
# $1 is the command line argument for the url of the counter-service
python3 app.py $1