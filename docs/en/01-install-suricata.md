---
title: "How To Install Suricata on Ubuntu 20.04"
description: "A step-by-step guide to installing Suricata from the OISF repository, configuring network interfaces, managing rulesets with suricata-update, and verifying threat detection on Ubuntu 20.04."
author: "Jamon Camisso"
date: 2021-10-23
category: Security
series: "SIEM with Suricata and Elastic Stack"
part: 1
tags:
  - suricata
  - ubuntu
  - security
  - ids
  - ips
  - networking
  - installation
---

# Part 1 — How To Install Suricata on Ubuntu 20.04

| | |
|---|---|
| **Series** | SIEM with Suricata and Elastic Stack |
| **Part** | 1 of 5 |
| **Difficulty** | Intermediate |
| **Time** | ~30 minutes |
| **OS** | Ubuntu 20.04 LTS |

---

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Step 1 — Installing Suricata](#step-1--installing-suricata)
- [Step 2 — Initial Configuration](#step-2--initial-configuration)
  - [Enable Community Flow ID](#enable-community-flow-id-recommended)
  - [Configure the Network Interface](#configure-the-network-interface)
  - [Enable Live Rule Reloading](#enable-live-rule-reloading)
- [Step 3 — Updating Rulesets](#step-3--updating-rulesets)
- [Step 4 — Validating the Configuration](#step-4--validating-the-configuration)
- [Step 5 — Starting Suricata](#step-5--starting-suricata)
- [Step 6 — Testing Detection](#step-6--testing-detection)
- [Step 7 — Handling Alerts](#step-7--handling-alerts)
- [Summary](#summary)

---

## Introduction

**Suricata** is an open-source Network Security Monitoring (NSM) engine that inspects network traffic using community-maintained and user-defined signature rules. It can generate log events, trigger alerts, and drop malicious packets matching specific threat patterns.

Suricata operates in two primary modes:

| Mode | Behavior |
|---|---|
| **IDS** *(Intrusion Detection System)* | Passively monitors traffic; logs and generates alerts only |
| **IPS** *(Intrusion Prevention System)* | Actively monitors and blocks suspicious traffic |

The default installation uses IDS mode. This guide covers installation, initial configuration, ruleset management, and basic testing. IPS mode is covered in [Part 3](03-configure-ips.md).

---

## Prerequisites

- Ubuntu 20.04 server with **2+ CPUs** and **4+ GB RAM**
- A non-root user with `sudo` privileges
- UFW firewall configured and enabled

---

## Step 1 — Installing Suricata

Add the Open Information Security Foundation (OISF) PPA repository:

```bash
sudo add-apt-repository ppa:oisf/suricata-stable
```

Press **ENTER** to confirm. Install Suricata:

```bash
sudo apt install suricata
```

Enable the service to start at boot:

```bash
sudo systemctl enable suricata.service
```

Stop the service before making configuration changes:

```bash
sudo systemctl stop suricata.service
```

---

## Step 2 — Initial Configuration

Open the main configuration file:

```bash
sudo nano /etc/suricata/suricata.yaml
```

### Enable Community Flow ID *(Recommended)*

The Community Flow ID provides a consistent, cross-tool identifier for network flows — essential when correlating Suricata events with Elasticsearch or Zeek.

Navigate to line 120 (`CTRL+_`, then type `120`):

```yaml
# /etc/suricata/suricata.yaml  (line ~120)

      # enable/disable the community id feature.
      community-id: true
```

### Configure the Network Interface

Determine your default network interface:

```bash
ip -p -j route show default
```

Example output:

```json
[ {
        "dst": "default",
        "gateway": "203.0.113.254",
        "dev": "eth0",
        "protocol": "static"
    } ]
```

Note the value of `"dev"`. Update the `af-packet` section (line ~580):

```yaml
# /etc/suricata/suricata.yaml  (line ~580)

af-packet:
  - interface: eth0    # Replace with your interface name
    cluster-id: 99
```

To monitor **multiple interfaces**, add additional entries before `- interface: default`. Each interface requires a unique `cluster-id`:

```yaml
  - interface: eth0
    cluster-id: 99

  - interface: enp0s1
    cluster-id: 98

  - interface: default
```

### Enable Live Rule Reloading

Append the following to the end of the file:

```yaml
# /etc/suricata/suricata.yaml  (end of file)

detect-engine:
  - rule-reload: true
```

With this setting, reload rules without restarting Suricata:

```bash
sudo kill -usr2 $(pidof suricata)
```

Save and close the file (`CTRL+X`, `Y`, `ENTER`).

---

## Step 3 — Updating Rulesets

Suricata includes `suricata-update`, a built-in tool to fetch and manage threat intelligence rulesets.

Download the default **ET Open** ruleset from Emerging Threats:

```bash
sudo suricata-update
```

Expected output:

```
19/10/2021 -- 19:31:03 - <Info> -- Fetching https://rules.emergingthreats.net/open/suricata-6.0.3/emerging.rules.tar.gz.
 100% - 3044855/3044855
...
19/10/2021 -- 19:31:06 - <Info> -- Writing rules to /var/lib/suricata/rules/suricata.rules:
  total: 31011; enabled: 23649; added: 31011
```

### Adding Additional Rule Sources

List available ruleset providers:

```bash
sudo suricata-update list-sources
```

Enable an additional source (example):

```bash
sudo suricata-update enable-source tgreen/hunting
sudo suricata-update
```

---

## Step 4 — Validating the Configuration

Run Suricata in test mode to validate the configuration and all loaded rules:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v
```

> **Note:** This test can take 1–2 minutes depending on the number of loaded rules.

Successful output ends with:

```
<Notice> - Configuration provided was successfully loaded. Exiting.
```

If the test fails, Suricata outputs a specific error code and description. For example, a missing rules file produces:

```
<Warning> - [ERRCODE: SC_ERR_NO_RULES(42)] - No rule files match the pattern /var/lib/suricata/rules/test.rules
```

---

## Step 5 — Starting Suricata

Start the Suricata service:

```bash
sudo systemctl start suricata.service
```

Verify it is running:

```bash
sudo systemctl status suricata.service
```

Expected output:

```
● suricata.service - LSB: Next Generation IDS/IPS
     Active: active (running) since Thu 2021-10-21 18:22:56 UTC
...
Starting suricata in IDS (af-packet) mode... done.
```

Wait until Suricata has fully initialized by tailing the log:

```bash
sudo tail -f /var/log/suricata/suricata.log
```

Suricata is ready when you see:

```
<Info> - All AFP capture threads are running.
```

Press `CTRL+C` to stop tailing.

---

## Step 6 — Testing Detection

Trigger rule `sid:2100498` with a crafted HTTP request:

```bash
curl http://testmynids.org/uid/index.html
```

The server returns a simulated response (`uid=0(root) gid=0(root)...`) designed to match this rule.

### Checking `fast.log`

```bash
grep 2100498 /var/log/suricata/fast.log
```

Expected output:

```
10/21/2021-18:35:57.247239  [**] [1:2100498:7] GPL ATTACK_RESPONSE id check returned root [**]
[Classification: Potentially Bad Traffic] [Priority: 2] {TCP} 204.246.178.81:80 -> 203.0.113.1:36364
```

### Checking `eve.json` with `jq`

Install `jq` if not already available:

```bash
sudo apt install jq
```

Query the EVE log for the specific alert:

```bash
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json
```

Expected output (truncated):

```json
{
  "timestamp": "2021-10-21T19:42:47.368856+0000",
  "event_type": "alert",
  "src_ip": "204.246.178.81",
  "dest_ip": "203.0.113.1",
  "community_id": "1:XLNse90QNVTgyXCWN9JDovC0XF4=",
  "alert": {
    "action": "allowed",
    "signature_id": 2100498,
    "signature": "GPL ATTACK_RESPONSE id check returned root",
    "category": "Potentially Bad Traffic"
  }
}
```

A matching log entry in either file confirms that Suricata is successfully inspecting traffic and generating alerts.

---

## Step 7 — Handling Alerts

Once alerts are operational, you can choose your response strategy:

| Strategy | Description |
|---|---|
| **Log only** | Retain alerts in EVE log for audit and forensic review |
| **Firewall block** | Parse EVE log with `jq`, extract source IPs, add UFW rules |
| **IPS mode** | Convert `alert` actions to `drop` and enable NFQUEUE (see [Part 3](03-configure-ips.md)) |
| **SIEM integration** | Forward logs to Elasticsearch via Filebeat (see [Part 4](04-build-siem.md)) |

---

## Summary

In this guide you:

- Installed Suricata from the OISF stable PPA
- Configured the Community Flow ID, network interface, and live rule reloading
- Downloaded the ET Open ruleset using `suricata-update`
- Validated the configuration and started the Suricata daemon
- Generated a test alert and confirmed it in both `fast.log` and `eve.json`

---

## References

- [Suricata Official Documentation](https://suricata.readthedocs.io/)
- [OISF Suricata GitHub](https://github.com/OISF/suricata)
- [ET Open Ruleset](https://rules.emergingthreats.net)

---

## Navigation

| | |
|---|---|
| **← Previous** | [README — Series Overview](README.md) |
| **Next →** | [Part 2: Understanding Suricata Signatures](02-understanding-signatures.md) |
