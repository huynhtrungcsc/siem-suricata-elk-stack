---
title: "SIEM with Suricata and Elastic Stack — Documentation Series"
description: "A complete step-by-step guide to deploying a Security Information and Event Management (SIEM) system using Suricata IDS/IPS and the Elastic Stack on Ubuntu 20.04."
author: "Jamon Camisso"
date: 2022-03-01
category: Security
series: "SIEM with Suricata and Elastic Stack"
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

# SIEM with Suricata and Elastic Stack

A complete documentation series for building a production-grade **Security Information and Event Management (SIEM)** system using **Suricata** as the network detection engine, integrated with **Elasticsearch**, **Kibana**, and **Filebeat** on Ubuntu 20.04.

---

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Documentation Series](#documentation-series)
- [Technology Stack](#technology-stack)
- [Quick Reference](#quick-reference)

---

## Architecture

```
                        ┌───────────────────────────────┐
                        │         Suricata Server        │
                        │                               │
   Network Traffic ────►│  Suricata (IDS/IPS)           │
                        │       │                       │
                        │       │ eve.json              │
                        │       ▼                       │
                        │  Filebeat ──────────────────────────────┐
                        └───────────────────────────────┘         │
                                                                   │ Private Network
                        ┌───────────────────────────────┐         │
                        │      Elasticsearch Server      │         │
                        │                               │         │
                        │  Elasticsearch (port 9200) ◄──────────┘
                        │       │                       │
                        │       ▼                       │
                        │  Kibana (port 5601)            │
                        │   - SIEM Dashboards            │
                        │   - Detection Rules            │
                        │   - Timelines & Cases          │
                        └───────────────────────────────┘
```

---

## Prerequisites

### Suricata Server

| Requirement | Specification |
|---|---|
| OS | Ubuntu 20.04 LTS |
| CPU | 2+ cores |
| RAM | 4 GB minimum |
| Access | Non-root `sudo` user |
| Firewall | UFW enabled |

### Elasticsearch Server

| Requirement | Specification |
|---|---|
| OS | Ubuntu 20.04 LTS |
| CPU | 2+ cores |
| RAM | **4 GB minimum** (8 GB recommended) |
| Access | Non-root `sudo` user |
| Network | Private IP reachable from Suricata server |

> **Note:** Both services can run on a single server for testing purposes, but a two-server setup is recommended for production deployments.

---

## Documentation Series

| Part | Title | Description |
|---|---|---|
| [Part 1](01-install-suricata.md) | **Installing Suricata on Ubuntu 20.04** | Install Suricata, configure network interfaces, update rulesets, and verify detection |
| [Part 2](02-understanding-signatures.md) | **Understanding Suricata Signatures** | Learn signature structure, actions, headers, options, and write custom rules |
| [Part 3](03-configure-ips.md) | **Configuring Suricata as an IPS** | Enable IPS mode with NFQUEUE, configure UFW to route traffic through Suricata |
| [Part 4](04-build-siem.md) | **Building a SIEM with Elastic Stack** | Deploy Elasticsearch and Kibana, configure Filebeat to ship Suricata logs |
| [Part 5](05-kibana-siem-apps.md) | **Kibana SIEM: Rules, Timelines, and Cases** | Create detection rules, build investigation timelines, and manage security cases |

---

## Technology Stack

| Component | Version | Role |
|---|---|---|
| [Suricata](https://suricata.io) | 6.x | Network threat detection and prevention |
| [Elasticsearch](https://www.elastic.co/elasticsearch/) | 7.x | Event storage, indexing, and correlation |
| [Kibana](https://www.elastic.co/kibana) | 7.x | Visualization, SIEM dashboards, and case management |
| [Filebeat](https://www.elastic.co/beats/filebeat) | 7.x | Log collection and forwarding |
| [ET Open Ruleset](https://rules.emergingthreats.net) | Latest | Community threat intelligence signatures |

---

## Quick Reference

```bash
# Reload Suricata rules without restart
sudo kill -usr2 $(pidof suricata)

# Test Suricata configuration
sudo suricata -T -c /etc/suricata/suricata.yaml -v

# Update rulesets
sudo suricata-update

# Query EVE log for a specific alert
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json

# Check Suricata status
sudo systemctl status suricata.service
```

---

## Getting Started

Begin with [Part 1: Installing Suricata on Ubuntu 20.04](01-install-suricata.md).

---

*Based on the DigitalOcean Community tutorial series by [Jamon Camisso](https://www.digitalocean.com/community/users/jamonation).*
