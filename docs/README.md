# SIEM: Suricata + Elastic Stack

> A complete, step-by-step documentation series for deploying a **Security Information and Event Management (SIEM)** system using Suricata IDS/IPS integrated with the Elastic Stack on Ubuntu 20.04.

---

## Language / Ngôn ngữ

| 🇬🇧 English | 🇻🇳 Tiếng Việt |
|---|---|
| [Read in English →](en/README.md) | [Đọc bằng tiếng Việt →](vi/README.md) |

---

## Series Overview

```
Suricata (IDS/IPS)
      │
      │  /var/log/suricata/eve.json
      ▼
  Filebeat ──────────────────────────────────►  Elasticsearch
                                                      │
                                                      ▼
                                                   Kibana
                                              (SIEM Dashboards,
                                              Rules, Timelines,
                                                   Cases)
```

---

## Technology Stack

| Component | Version | Purpose |
|---|---|---|
| Suricata | 6.x | Network IDS/IPS engine |
| Elasticsearch | 7.x | Event storage and indexing |
| Kibana | 7.x | Visualization and SIEM UI |
| Filebeat | 7.x | Log shipping |
| Ubuntu | 20.04 LTS | Operating system |

---

*Based on the DigitalOcean Community tutorial series by [Jamon Camisso](https://www.digitalocean.com/community/users/jamonation).*
