<div align="center">

# English Documentation

**SIEM with Suricata and Elastic Stack — 5-Part Series**

[← Back to Repository](../../README.md) · [🇻🇳 Đọc bằng Tiếng Việt](../vi/README.md)

</div>

---

This documentation series walks you through building a complete, production-ready SIEM from scratch — starting with a bare Ubuntu 20.04 server and ending with a fully operational threat detection, prevention, and incident management platform.

Each part builds directly on the previous one. Follow them in order on your first read.

---

## Prerequisites

Before starting Part 1, ensure both servers meet the following requirements.

### Suricata Server

| Requirement | Specification |
|---|---|
| OS | Ubuntu 20.04 LTS |
| CPU | 2+ cores |
| RAM | 4 GB minimum |
| Disk | 20 GB+ (for EVE log storage) |
| Access | Non-root user with `sudo` privileges |
| Firewall | UFW installed and enabled |
| Network interface | Known — run `ip link show` to identify |

### Elasticsearch Server

| Requirement | Specification |
|---|---|
| OS | Ubuntu 20.04 LTS |
| CPU | 2+ cores |
| RAM | **4 GB minimum** (8 GB recommended) |
| Disk | 50 GB+ (for event index storage) |
| Access | Non-root user with `sudo` privileges |
| Network | Private IP reachable from the Suricata server |

> Both servers can be the same machine for lab and testing. For production, keep them separate: Suricata's packet inspection and Elasticsearch's JVM heap compete for RAM at the same 4 GB floor.

---

## Documentation Series

| Part | Title | Time | What you will have when done |
|---|---|---|---|
| [Part 1](01-install-suricata.md) | **Installing Suricata on Ubuntu 20.04** | ~30 min | Suricata running in IDS mode, ET Open ruleset active, first alert verified |
| [Part 2](02-understanding-signatures.md) | **Understanding Suricata Signatures** | ~20 min | Custom SSH brute-force, HTTP, and TLS detection rules written and tested |
| [Part 3](03-configure-ips.md) | **Configuring Suricata as an IPS** | ~30 min | Suricata in IPS mode — matching rules now actively drop traffic |
| [Part 4](04-build-siem.md) | **Building a SIEM with Elastic Stack** | ~45 min | Elasticsearch + Kibana secured with xpack; Suricata EVE logs flowing via Filebeat |
| [Part 5](05-kibana-siem-apps.md) | **Kibana SIEM: Rules, Timelines, and Cases** | ~30 min | Scheduled detection rules, correlated investigation timelines, and managed security cases |

**Total estimated reading and lab time:** approximately 2.5 hours

---

## Quick Reference

Commands you will use throughout this series and during day-to-day operations.

```bash
# Validate configuration before restarting
sudo suricata -T -c /etc/suricata/suricata.yaml -v

# Pull latest threat intelligence rulesets
sudo suricata-update

# Hot-reload rules without stopping the daemon
sudo kill -usr2 $(pidof suricata)

# Check service health
sudo systemctl status suricata.service

# Stream the operational log in real time
sudo tail -f /var/log/suricata/suricata.log

# Find all alerts for a specific signature
jq 'select(.event_type=="alert") | {ts: .timestamp, src: .src_ip, sig: .alert.signature}' \
  /var/log/suricata/eve.json

# Trigger the standard test alert (SID 2100498)
curl http://testmynids.org/uid/index.html
grep 2100498 /var/log/suricata/fast.log

# Check Elasticsearch cluster health
curl -s -u elastic:<password> http://localhost:9200/_cluster/health | jq .

# List active Filebeat modules
sudo filebeat modules list
```

---

## Reading Order

If this is your first time working with Suricata or the Elastic Stack, read sequentially from Part 1 through Part 5. Each part assumes the infrastructure from the previous part is in place.

If you are looking for a specific topic:

- **Installing Suricata, configuring interfaces and rulesets** → [Part 1](01-install-suricata.md)
- **Signature syntax and custom rule writing** → [Part 2](02-understanding-signatures.md)
- **Switching from detection-only to active blocking** → [Part 3](03-configure-ips.md)
- **Elasticsearch and Kibana installation and security** → [Part 4](04-build-siem.md)
- **Detection rules, investigation timelines, case management** → [Part 5](05-kibana-siem-apps.md)

---

**[→ Start with Part 1: Installing Suricata on Ubuntu 20.04](01-install-suricata.md)**
