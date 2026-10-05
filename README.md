# kata-app-network

Network troubleshooting kata. A deliberately tiny HTTP chain, zero application
code, and a set of scripted network failures to break, diagnose and fix live.

```
 client -> edge (nginx) -> api (nginx) -> backend (whoami)
 :8080      [frontend]     [both nets]    [backend]

 netshoot: toolbox (dig, nc, mtr, tcpdump, ss, tc, iptables)
```

## Run

```bash
make up        # start the stack       -> http://localhost:8080
make watch     # live client requests  (HTTP code + latency, 1/s)
make status    # one-screen DNS / L3 / L4 / L7 per hop
make diagnose  # the troubleshooting ladder, run from inside kata-api
make down
```

## Scenarios

| # | Failure                 | break / fix                              | Symptom at the edge | Tell-tale sign                                   |
|---|-------------------------|------------------------------------------|---------------------|--------------------------------------------------|
| 1 | DNS (typo in hostname)  | `make break-dns` / `make fix-dns`         | 502, instant        | nginx log: `could not be resolved (Host not found)` |
| 2 | Wrong port              | `make break-port` / `make fix-port`       | 502, instant        | `nc`: **Connection refused**; `ss` shows `:9000`   |
| 3 | Firewall (DROP)         | `make break-firewall` / `make fix-firewall` | 504 after 2s      | `ping` ok, `nc`: **timed out**; iptables DROP rule |
| 4 | Latency + packet loss   | `make break-latency` / `make fix-latency` | slow 200s, some 504 | `ping` RTT 1000ms + loss; `tc qdisc` shows netem   |
| 5 | Network segmentation    | `make break-network` / `make fix-network` | 502, instant        | `dig`: **NXDOMAIN** from api; api missing from `kata_backend` |

`make fix-all` resets everything. `make capture` runs tcpdump on a hop.
`make shell` drops you into netshoot.

## Why it is built this way

- **No application code.** The app is two nginx configs and a stock `whoami`
  image, so all the time goes into the network.
- **Two docker networks.** `api` is the only container on both, so there is a
  real boundary to break.
- **nginx resolves at request time** (`resolver 127.0.0.11` + variable in
  `proxy_pass`). That is what makes the DNS scenario show up as a runtime 502
  instead of nginx refusing to start.
- **Failures are injected inside the target's network namespace** with
  `docker run --network container:kata-backend nicolaka/netshoot`, so the
  `whoami` image stays untouched (it is `FROM scratch`, no shell).
