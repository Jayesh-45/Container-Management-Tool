#!/bin/bash

cd "$(dirname "$0")"

apt update
apt install -y build-essential
make
./counter-service 8080 1