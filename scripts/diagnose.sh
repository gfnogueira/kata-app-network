#!/usr/bin/env bash
# Troubleshooting ladder, bottom-up, run from the container that feels the
# failure (default kata-api) against the hop it dials (default backend:80).
#
#   0 config    what is the caller set to dial?        env
#   1 symptom   what did the caller log recently?      docker logs
#   2 networks  are both sides on a common network?    docker inspect
#   3 dns       does the name resolve from the caller? dig
#   4 l3        is the host reachable?                 ping
#   5 l4        is the port open? refused vs timeout   nc
#   6 l7        does http answer, how fast?            curl -w
#   7 target    what does it really listen on?         ss, tc, iptables
#
# Usage: scripts/diagnose.sh [host] [port] [from-container]
set -uo pipefail
HOST=${1:-backend}; PORT=${2:-80}; FROM=${3:-kata-api}
WINDOW=20s
TOOLBOX="nicolaka/netshoot:v0.13"
B=$'\e[1m'; N=$'\e[0m'
step(){ echo; echo "${B}== $*${N}"; }
nets(){ docker inspect "$1" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}} {{end}}' 2>/dev/null; }

echo "${B}diagnosing  $FROM  ->  $HOST:$PORT${N}"

step "0) CONFIG   - what is $FROM configured to dial?"
docker exec "$FROM" sh -c 'env | grep -E "_(HOST|PORT)=" || true' | sed 's/^/   /'

step "1) SYMPTOM  - errors logged by $FROM in the last $WINDOW"
errs=$(docker logs --since "$WINDOW" "$FROM" 2>&1 | grep -E "\[(error|crit)\]")
if [[ -n "$errs" ]]; then
  echo "$errs" | wc -l | sed 's/^ */   count: /'
  echo "$errs" | tail -2 | sed -E 's/^[0-9/]+ ([0-9:]+) \[[a-z]+\] [0-9#]+: \*[0-9]+ /   \1  /; s/, client:.*//'
else
  echo "   (none)"
fi

step "2) NETWORKS - who is on which docker network?"
printf "   %-14s %s\n" "$FROM" "$(nets "$FROM")"
printf "   %-14s %s\n" "kata-$HOST" "$(nets "kata-$HOST" || echo '<no such container>')"

# Steps 3 to 6 run in one toolbox container sharing the caller's netns.
docker run --rm --network "container:$FROM" --cap-add NET_RAW -e HOST="$HOST" -e PORT="$PORT" "$TOOLBOX" bash -c '
B=$'"'"'\e[1m'"'"'; N=$'"'"'\e[0m'"'"'
step(){ echo; echo "${B}== $*${N}"; }

step "3) DNS      - dig $HOST   (resolver: $(grep nameserver /etc/resolv.conf | head -1 | cut -d" " -f2))"
ip=$(dig +short +time=1 +tries=1 "$HOST" | head -1)
echo "   ${ip:-<no answer>}   $(dig +noall +comments +time=1 +tries=1 "$HOST" | grep -o "status: [A-Z]*")"
[[ -z "$ip" ]] && { echo "   >>> name does not resolve here: typo, or not on a shared docker network"; exit 0; }

step "4) L3       - ping $HOST  (reachability + RTT)"
ping -c3 -i0.3 -W3 "$HOST" 2>&1 | tail -2 | sed "s/^/   /"

step "5) L4       - nc -zv $HOST $PORT   (is the TCP port open?)"
out=$(timeout 4 nc -zv -w3 "$HOST" "$PORT" 2>&1)
echo "   ${out:-(no answer)}"
case "$out" in
  *succeeded*) ;;
  *refused*)   echo "   >>> REFUSED: host is up, nothing listens on $PORT (check ss on the target)";;
  *)           echo "   >>> TIMEOUT: packets are dropped (firewall, routing, wrong network)";;
esac

step "6) L7       - curl http://$HOST:$PORT/   (HTTP + timing breakdown)"
curl -s -o /dev/null --max-time 6 \
  -w "   http=%{http_code}  dns=%{time_namelookup}s  connect=%{time_connect}s  ttfb=%{time_starttransfer}s  total=%{time_total}s\n" \
  "http://$HOST:$PORT/" || echo "   >>> curl failed (exit $?)"
'

step "7) TARGET   - inside kata-$HOST: listening sockets, tc qdisc, iptables"
if docker inspect "kata-$HOST" >/dev/null 2>&1; then
  docker run --rm --network "container:kata-$HOST" --cap-add NET_ADMIN "$TOOLBOX" bash -c '
    ss -tlnp | grep -v 127.0.0.11 | sed "s/^/   /"
    echo "   tc:       $(tc qdisc show dev eth0)"
    echo "   iptables: $(iptables -S INPUT 2>/dev/null | grep -v "^-P" | tr "\n" " ")"'
else
  echo "   (no container named kata-$HOST)"
fi
echo
