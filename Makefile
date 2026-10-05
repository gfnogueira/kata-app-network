.PHONY: up down watch status diagnose shell capture logs help fix-all \
        break-dns fix-dns break-port fix-port break-firewall fix-firewall \
        break-latency fix-latency break-network fix-network

up:            ## start the stack
	docker compose up -d
	@echo; echo "http://localhost:8080  |  make watch  |  make status"
down:          ## stop and remove everything
	docker compose down --remove-orphans
watch:         ## live client requests, 1/s
	docker compose logs -f --no-log-prefix client
status:        ## DNS / L3 / L4 / L7 per hop
	@scripts/status.sh
diagnose:      ## ladder from kata-api to backend:80 (H=api P=8080 FROM=kata-edge)
	@scripts/diagnose.sh $(or $(H),backend) $(or $(P),80) $(or $(FROM),kata-api)
shell:         ## interactive netshoot
	docker exec -it kata-netshoot bash
capture:       ## tcpdump on backend (C=kata-api F="tcp port 8080")
	@scripts/capture.sh $(or $(C),kata-backend) $(or $(F),tcp port 80)
logs:          ## nginx logs of edge and api
	docker compose logs --tail 20 edge api

break-dns:      ; @scripts/break-dns.sh
fix-dns:        ; @scripts/fix-dns.sh
break-port:     ; @scripts/break-port.sh
fix-port:       ; @scripts/fix-port.sh
break-firewall: ; @scripts/break-firewall.sh
fix-firewall:   ; @scripts/fix-firewall.sh
break-latency:  ; @scripts/break-latency.sh $(D) $(L)
fix-latency:    ; @scripts/fix-latency.sh
break-network:  ; @scripts/break-network.sh
fix-network:    ; @scripts/fix-network.sh
fix-all:        ; @scripts/fix-all.sh

help:
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/' | column -t -s $$'\t'
