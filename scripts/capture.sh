#!/usr/bin/env bash
# tcpdump inside a hop. Shows SYN / SYN-ACK / RST live.
# Usage: scripts/capture.sh [container] [filter]   (default kata-backend "tcp port 80")
set -e
C=${1:-kata-backend}; F=${2:-"tcp port 80"}
echo ">> tcpdump in $C, filter: $F  (ctrl-c to stop)"
docker run --rm -it --network "container:$C" --cap-add NET_RAW nicolaka/netshoot:v0.13 \
  tcpdump -i eth0 -nn -l "$F"
