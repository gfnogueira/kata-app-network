# kata-app-network

A network troubleshooting kata. The application is deliberately tiny and has
no code of its own. The point is to break the network between its hops in
realistic ways, then find the cause with a fixed, repeatable method.

```
 client -> edge (nginx) -> api (nginx) -> backend (whoami)
 :8080      [frontend]     [both nets]    [backend]

 netshoot: toolbox with dig, nc, mtr, tcpdump, ss, tc, iptables
```

- **edge**: public entrypoint on `localhost:8080`, proxies to `api:8080`.
- **api**: internal service, proxies to `backend:80`. The only container on
  both docker networks, so there is a real boundary to break.
- **backend**: stock `traefik/whoami` image. Answers with its name, IP and
  the headers it received.
- **client**: a `curl` loop hitting the edge once per second. Prints time,
  HTTP code and duration. This is the live monitor.
- **netshoot**: `nicolaka/netshoot`, kept idle. Used for `make status`,
  `make shell`, and to inject failures into other containers.

## Quick start

```bash
make up          # start the stack, then open http://localhost:8080
make watch       # live client requests (HTTP code + latency, 1/s)
make status      # one screen: DNS / L3 / L4 / L7 per hop
make diagnose    # the troubleshooting ladder, run from inside kata-api
make down        # stop and remove everything
make help        # every target
```

Suggested layout: one pane with `make watch`, one with `watch -n1 docker ps`,
and one where you type.

## Scenarios

Each one has a `break` and a `fix` target. Run the break, look at the client
pane, run `make diagnose`, read it bottom-up, run the fix.

| # | Failure                | Commands                                    | Symptom at the edge   | What gives it away                                        |
|---|------------------------|---------------------------------------------|-----------------------|-----------------------------------------------------------|
| 1 | DNS, typo in hostname  | `make break-dns` / `make fix-dns`            | 502, instant          | api log `Host not found`; `dig` NXDOMAIN                   |
| 2 | Wrong port             | `make break-port` / `make fix-port`          | 502, instant          | `nc` **Connection refused**; `ss` on backend shows `:9000` |
| 3 | Firewall, iptables DROP| `make break-firewall` / `make fix-firewall`  | 504 after 2s          | `ping` ok, `nc` **timed out**; DROP rule on backend        |
| 4 | Latency + packet loss  | `make break-latency` / `make fix-latency`    | slow 200s, some 504s  | `ping` RTT 1000ms with loss; `tc qdisc` shows netem        |
| 5 | Network segmentation   | `make break-network` / `make fix-network`    | 502, instant          | `dig` NXDOMAIN from api only; api missing from `kata_backend` |

How each break works:

- **1 and 2** apply a compose override from `scenarios/` and recreate one
  container with a bad setting. They simulate a bad deploy. You can see the
  container get recreated in `docker ps`.
- **3 and 4** attach a netshoot to the backend's network namespace
  (`docker run --network container:kata-backend`) and run `iptables` or
  `tc netem` there. Nothing is redeployed and no config changes, which is
  what makes them realistic.
- **5** removes the api from the backend network. Docker DNS only resolves
  names across a shared network, so the api suddenly cannot resolve a name
  that netshoot still can.

`make fix-all` resets every scenario at once.

## The method

`make diagnose` always runs the same ladder, from inside the container that
feels the failure (`kata-api` by default) against the hop it dials:

```
0  config    what is it configured to dial?          env
1  symptom   what did it log in the last 20s?        docker logs
2  networks  are both sides on a common network?     docker inspect
3  dns       does the name resolve from here?        dig
4  l3        is the host reachable?                  ping
5  l4        is the port open?                       nc -zv
6  l7        does http answer, and how fast?         curl -w (dns / connect / ttfb)
7  target    what does it really listen on?          ss, tc, iptables inside the target
```

Two rules the ladder is built on:

- **Refused is not timeout.** `Connection refused` means the packet arrived
  and the host answered with RST: it is alive, nothing listens on that port.
  `Timed out` means the packet vanished: firewall, routing, wrong network.
  The edge shows this too: an instant 502 versus a 504 after a few seconds.
- **Test from where the failure is felt.** Scenario 5 looks healthy from
  netshoot and broken from the api. The observation point changes the answer.

Other targets: `make capture` runs tcpdump on a hop (`C=kata-api F="tcp port 8080"`),
`make shell` opens netshoot, `make diagnose H=api P=8080 FROM=kata-edge`
runs the ladder on a different hop.

## Layout

```
docker-compose.yml       the five containers and two networks
nginx/                   edge and api configs (resolver + variable proxy_pass)
scenarios/               compose overrides for the bad-deploy scenarios
scripts/                 break-*, fix-*, diagnose, status, capture, netns
Makefile                 one target per action
```

## Design notes

- **No application code.** Two nginx configs and a stock image. All the
  attention goes to the network.
- **nginx resolves at request time.** `resolver 127.0.0.11` plus a variable
  in `proxy_pass` makes nginx resolve the upstream on every request instead
  of once at startup. That is why the DNS scenario shows up as a runtime 502
  rather than nginx refusing to start.
- **Short proxy timeouts.** `proxy_connect_timeout 2s` and
  `proxy_read_timeout 3s` keep the timeout scenarios visible within seconds.
- **Failures go into the target's namespace, not its image.** `whoami` is
  built `FROM scratch` and has no shell, so iptables and tc run from a
  netshoot that shares its network namespace. Same idea as `kubectl debug`.
