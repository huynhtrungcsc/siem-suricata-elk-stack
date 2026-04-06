<div align="center">

# SIEM: Suricata + Elastic Stack

**Network Intrusion Detection, Prevention, and Centralized Security Analytics**

Deployment guide for building a production-grade SIEM on Ubuntu 20.04 LTS

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)]()
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2020.04%20LTS-E95420?logo=ubuntu&logoColor=white)]()
[![Stack](https://img.shields.io/badge/stack-Suricata%20|%20Elasticsearch%20|%20Kibana%20|%20Filebeat-005571?logo=elastic&logoColor=white)]()

<br/>

[🇬🇧 English Documentation](docs/en/README.md) · [🇻🇳 Tài liệu Tiếng Việt](docs/vi/README.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

</div>

---

## Overview

This repository contains a complete, step-by-step documentation series for deploying a **Security Information and Event Management (SIEM)** system using **Suricata** as the network detection and prevention engine, integrated with the **Elastic Stack** (Elasticsearch, Kibana, Filebeat) on Ubuntu 20.04 LTS.

The series covers the full operational lifecycle — from initial sensor installation to active threat prevention and centralized incident management.

---

## System Architecture

```
┌─────────────────────────────────────┐         ┌─────────────────────────────────────┐
│           Suricata Server           │         │         Elasticsearch Server         │
│                                     │         │                                     │
│  Network Traffic ──► Suricata       │         │  Elasticsearch  ◄── Filebeat        │
│                      (IDS/IPS)      │         │       │                             │
│                         │           │  Private│       ▼                             │
│                    eve.json         │  Network│  Kibana (port 5601)                 │
│                         │           │         │   ├─ SIEM Dashboards               │
│                         ▼           │         │   ├─ Detection Rules               │
│                      Filebeat ──────────────► │   ├─ Timelines                     │
│                                     │         │   └─ Case Management               │
└─────────────────────────────────────┘         └─────────────────────────────────────┘
```

---

## Technology Stack

| Component | Version | Purpose |
|---|---|---|
| [Suricata](https://suricata.io) | 6.x | Network-based intrusion detection and prevention |
| [Elasticsearch](https://www.elastic.co/elasticsearch/) | 7.x | Distributed event storage, indexing, and correlation |
| [Kibana](https://www.elastic.co/kibana) | 7.x | SIEM dashboards, detection rules, and case management |
| [Filebeat](https://www.elastic.co/beats/filebeat) | 7.x | Lightweight log collection and forwarding |
| [ET Open Ruleset](https://rules.emergingthreats.net) | Latest | Community-maintained threat intelligence signatures |
| Ubuntu | 20.04 LTS | Operating system |

---

## Documentation

Available in two languages:

| | English | Tiếng Việt |
|---|---|---|
| **Series Overview** | [en/README.md](docs/en/README.md) | [vi/README.md](docs/vi/README.md) |
| **Part 1** — Install Suricata | [01-install-suricata.md](docs/en/01-install-suricata.md) | [01-cai-dat-suricata.md](docs/vi/01-cai-dat-suricata.md) |
| **Part 2** — Signatures | [02-understanding-signatures.md](docs/en/02-understanding-signatures.md) | [02-hieu-ve-signatures.md](docs/vi/02-hieu-ve-signatures.md) |
| **Part 3** — IPS Configuration | [03-configure-ips.md](docs/en/03-configure-ips.md) | [03-cau-hinh-ips.md](docs/vi/03-cau-hinh-ips.md) |
| **Part 4** — Build SIEM | [04-build-siem.md](docs/en/04-build-siem.md) | [04-xay-dung-siem.md](docs/vi/04-xay-dung-siem.md) |
| **Part 5** — Kibana SIEM Apps | [05-kibana-siem-apps.md](docs/en/05-kibana-siem-apps.md) | [05-kibana-siem.md](docs/vi/05-kibana-siem.md) |

---

## Quick Start

```bash
# 1. Add OISF PPA and install Suricata
sudo add-apt-repository ppa:oisf/suricata-stable
sudo apt install suricata

# 2. Update threat intelligence rulesets
sudo suricata-update

# 3. Validate configuration
sudo suricata -T -c /etc/suricata/suricata.yaml -v

# 4. Start Suricata
sudo systemctl start suricata.service

# 5. Verify detection with a test alert
curl http://testmynids.org/uid/index.html
grep 2100498 /var/log/suricata/fast.log
```

---

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a pull request.

---

## Security

To report a security vulnerability in this project, please follow the process described in [SECURITY.md](SECURITY.md).

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## Acknowledgements

This documentation series was developed with reference to the original tutorial series authored by [**Jamon Camisso**](https://www.digitalocean.com/community/users/jamonation), published on the [DigitalOcean Community](https://www.digitalocean.com/community) platform. The content in this repository has been independently restructured, significantly extended, translated into Vietnamese, and adapted with additional technical detail and operational context.
