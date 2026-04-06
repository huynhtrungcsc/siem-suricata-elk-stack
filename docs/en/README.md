---
title: "SIEM with Suricata and Elastic Stack — English Documentation"
description: "A complete step-by-step guide to deploying a production-grade SIEM system using Suricata IDS/IPS and the Elastic Stack on Ubuntu 20.04."
date: 2022-03-01
category: Security
series: "SIEM with Suricata and Elastic Stack"
language: English
tags:
  - suricata
  - elasticsearch
  - kibana
  - filebeat
  - siem
  - ubuntu
  - security
  - ids
  - ips
---

<div align="center">

# SIEM: Suricata + Elastic Stack

**Network Intrusion Detection, Prevention, and Centralized Security Analytics**

Deployment guide for building a production-grade SIEM on Ubuntu 20.04 LTS

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](../../LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)]()
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2020.04%20LTS-E95420?logo=ubuntu&logoColor=white)]()
[![Stack](https://img.shields.io/badge/stack-Suricata%20|%20Elasticsearch%20|%20Kibana%20|%20Filebeat-005571?logo=elastic&logoColor=white)]()

<br/>

[← Back to Repository](../../README.md) · [🇻🇳 Đọc bằng Tiếng Việt](../vi/README.md)

</div>

---

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Prerequisites](#prerequisites)
- [Documentation Series](#documentation-series)
- [Technology Stack](#technology-stack)
- [Quick Reference](#quick-reference)
- [Acknowledgements](#acknowledgements)

---

## Overview

This documentation series provides a complete, end-to-end guide for deploying a **Security Information and Event Management (SIEM)** system using **Suricata** as the network threat detection and prevention engine, integrated with the **Elastic Stack** (Elasticsearch, Kibana, Filebeat) on Ubuntu 20.04 LTS.

The series covers the full operational lifecycle:

| Phase | Parts | Description |
|---|---|---|
| **Detection** | Parts 1–2 | Deploy Suricata, configure signatures, update rulesets |
| **Prevention** | Part 3 | Enable IPS mode, route traffic through Suricata with NFQUEUE |
| **Analytics** | Parts 4–5 | Build SIEM with Elastic Stack, create detection rules and incident cases |

---

## System Architecture

```
┌─────────────────────────────────────┐         ┌─────────────────────────────────────┐
│           Suricata Server           │         │         Elasticsearch Server         │
│                                     │         │                                     │
│  Network Traffic ──► Suricata       │         │  Elasticsearch  ◄── Filebeat        │
│                      (IDS/IPS)      │  Private│       │                             │
│                         │           │  Network│       ▼                             │
│                    eve.json         │         │  Kibana (port 5601)                 │
│                         │           │         │   ├─ SIEM Dashboards               │
│                         ▼           │         │   ├─ Detection Rules               │
│                      Filebeat ──────────────► │   ├─ Timelines                     │
│                                     │         │   └─ Case Management               │
└─────────────────────────────────────┘         └─────────────────────────────────────┘
```

---

## Prerequisites

### Suricata Server

| Requirement | Specification |
|---|---|
| OS | Ubuntu 20.04 LTS |
| CPU | 2+ cores |
| RAM | 4 GB minimum |
| Access | Non-root user with `sudo` |
| Firewall | UFW configured and enabled |

### Elasticsearch Server

| Requirement | Specification |
|---|---|
| OS | Ubuntu 20.04 LTS |
| CPU | 2+ cores |
| RAM | **4 GB minimum** (8 GB recommended) |
| Access | Non-root user with `sudo` |
| Network | Private IP reachable from Suricata server |

> **Note:** Both services can run on a single server for testing purposes. A two-server setup is recommended for production deployments to avoid resource contention between Suricata's packet inspection workload and Elasticsearch's JVM heap allocation.

---

## Documentation Series

| Part | Title | Time | Description |
|---|---|---|---|
| [Part 1](01-install-suricata.md) | **Installing Suricata on Ubuntu 20.04** | ~30 min | Install from OISF PPA, configure interface and Community Flow ID, download ET Open ruleset, verify first alert |
| [Part 2](02-understanding-signatures.md) | **Understanding Suricata Signatures** | ~20 min | Signature structure, actions, headers, options — write custom SSH, HTTP, and TLS detection rules |
| [Part 3](03-configure-ips.md) | **Configuring Suricata as an IPS** | ~30 min | Switch from IDS to IPS mode with NFQUEUE, route all traffic through Suricata, preserve SSH access |
| [Part 4](04-build-siem.md) | **Building a SIEM with Elastic Stack** | ~45 min | Deploy Elasticsearch and Kibana with xpack security, ship Suricata EVE logs via Filebeat |
| [Part 5](05-kibana-siem-apps.md) | **Kibana SIEM: Rules, Timelines, and Cases** | ~30 min | Create detection rules, build correlation timelines using community_id, manage security cases |

**Total estimated time:** ~2.5 hours

---

## Technology Stack

| Component | Version | Role |
|---|---|---|
| [Suricata](https://suricata.io) | 6.x | Network-based intrusion detection and prevention engine |
| [Elasticsearch](https://www.elastic.co/elasticsearch/) | 7.x | Distributed event storage, indexing, and correlation |
| [Kibana](https://www.elastic.co/kibana) | 7.x | SIEM dashboards, detection rules, timelines, and case management |
| [Filebeat](https://www.elastic.co/beats/filebeat) | 7.x | Lightweight log collection and forwarding |
| [ET Open Ruleset](https://rules.emergingthreats.net) | Latest | Community-maintained threat intelligence signatures (~30,000 rules) |
| Ubuntu | 20.04 LTS | Operating system |

---

## Quick Reference

```bash
# Test Suricata configuration before applying changes
sudo suricata -T -c /etc/suricata/suricata.yaml -v

# Update threat intelligence rulesets
sudo suricata-update

# Hot-reload rules without restarting the daemon
sudo kill -usr2 $(pidof suricata)

# Check Suricata service status
sudo systemctl status suricata.service

# Follow the Suricata log in real time
sudo tail -f /var/log/suricata/suricata.log

# Query EVE log for a specific Suricata alert (replace SID as needed)
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json

# Trigger test alert (matches SID 2100498)
curl http://testmynids.org/uid/index.html
```

---

## Acknowledgements

This documentation series was developed with reference to the original tutorial series authored by [**Jamon Camisso**](https://www.digitalocean.com/community/users/jamonation), published on the [DigitalOcean Community](https://www.digitalocean.com/community) platform. The content in this repository has been independently restructured, significantly extended, translated into Vietnamese, and adapted with additional theoretical context, real-world operational notes, and common error documentation.

---

*[← Back to Repository Root](../../README.md)*
