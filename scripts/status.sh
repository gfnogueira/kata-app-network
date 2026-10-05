#!/usr/bin/env bash
# One-screen health of every hop, checked from netshoot:
# DNS (dig), L3 (ping), L4 (nc), L7 (curl).
set -uo pipefail
NS="docker exec kata-netshoot"
G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; N=$'\e[0m'
ok(){ printf "%s OK %s" "$G" "$N"; }; bad(){ printf "%s!! %s" "$R" "$N"; }

check_hop() {
  local name=$1 port=$2 path=$3
  local dns l3 l4 l7 ip t0 t1 code
  ip=$($NS dig +short +time=1 +tries=1 "$name" 2>/dev/null | head -1)
  [[ -n "$ip" ]] && dns=$(ok) || dns=$(bad)
  if [[ -n "$ip" ]]; then
    $NS ping -c1 -W1 "$name" >/dev/null 2>&1 && l3=$(ok) || l3=$(bad)
    $NS nc -z -w2 "$name" "$port" >/dev/null 2>&1 && l4=$(ok) || l4=$(bad)
    t0=$(date +%s%N)
    code=$($NS curl -s -o /dev/null --max-time 5 -w '%{http_code}' "http://$name:$port$path" 2>/dev/null)
    t1=$(date +%s%N)
    [[ "$code" == "200" ]] && l7="$(ok)$code $(( (t1-t0)/1000000 ))ms" || l7="$(bad)${code:-000}"
  else
    l3="$Y -- $N"; l4="$Y -- $N"; l7="$Y -- $N"
  fi
  printf "  %-8s %-16s DNS:%s  L3:%s  L4:%s  L7:%s\n" "$name" "${ip:-<unresolved>}" "$dns" "$l3" "$l4" "$l7"
}

echo
echo "  client -> edge:80 -> api:8080 -> backend:80"
echo
check_hop edge    80   /healthz
check_hop api     8080 /healthz
check_hop backend 80   /
echo
printf "  END-TO-END  edge/ -> "
code=$($NS curl -s -o /dev/null --max-time 5 -w '%{http_code} in %{time_total}s' http://edge/ 2>/dev/null)
[[ "$code" == 200* ]] && echo "$G$code$N" || echo "$R${code:-timeout}$N"
echo
