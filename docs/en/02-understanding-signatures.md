---
title: "Understanding Suricata Signatures"
description: "A deep dive into Suricata signature structure — actions, headers, and options — with practical examples for writing custom detection rules."
author: "Jamon Camisso"
date: 2021-11-25
category: Security
series: "SIEM with Suricata and Elastic Stack"
part: 2
tags:
  - suricata
  - signatures
  - rules
  - ids
  - security
  - networking
---

# Part 2 — Understanding Suricata Signatures

| | |
|---|---|
| **Series** | SIEM with Suricata and Elastic Stack |
| **Part** | 2 of 5 |
| **Difficulty** | Intermediate |
| **Time** | ~20 minutes |
| **OS** | Any (Linux recommended) |

---

## Introduction

The [previous guide](01-install-suricata.md) covered installing Suricata and loading the ET Open ruleset, which contains over 30,000 signatures. However, many of those signatures may not apply to your environment.

This guide explains:

- The **structure** of a Suricata signature
- The key **actions**, **header** fields, and **options**
- How to **write custom rules** tailored to your network

Understanding signatures allows you to maintain a lean, targeted ruleset — reducing false positives and improving Suricata's processing efficiency.

---

## Prerequisites

- Suricata installed and running ([Part 1](01-install-suricata.md))
- ET Open ruleset downloaded via `suricata-update`
- Basic familiarity with networking concepts (TCP/UDP, ports, IP addressing)

---

## Signature Structure

Every Suricata signature follows a three-part structure:

```
ACTION HEADER (OPTIONS)
```

| Component | Description |
|---|---|
| **Action** | What Suricata does when traffic matches the rule |
| **Header** | Defines the network scope: protocol, source/destination IPs, ports, and direction |
| **Options** | Rule-specific logic: message, content matching, metadata, classification |

### Example Signature

```
alert ip any any -> any any (msg:"GPL ATTACK_RESPONSE id check returned root"; content:"uid=0|28|root|29|"; classtype:bad-unknown; sid:2100498; rev:7; metadata:created_at 2010_09_23, updated_at 2010_09_23;)
```

Parsed:

| Component | Value |
|---|---|
| **Action** | `alert` |
| **Header** | `ip any any -> any any` |
| **Options** | `msg:"..."` `content:"..."` `classtype:...` `sid:...` `rev:...` |

---

## Actions

The action determines Suricata's response when a packet matches the signature:

| Action | Mode | Behavior |
|---|---|---|
| `alert` | IDS & IPS | Generates an alert entry and logs the event |
| `pass` | IDS & IPS | Allows the packet; suppresses alert generation |
| `drop` | **IPS only** | Silently discards the packet; TCP connections time out |
| `reject` | **IPS only** | Sends TCP RST (TCP) or ICMP unreachable (other) and drops the packet |

> **Important:** `drop` and `reject` have no effect in IDS mode — Suricata will generate an alert instead. IPS mode configuration is covered in [Part 3](03-configure-ips.md).

---

## Headers

The header defines the traffic scope for a signature.

### Syntax

```
<PROTOCOL> <SRC_IP> <SRC_PORT> -> <DST_IP> <DST_PORT>
```

### Protocols

| Value | Scope |
|---|---|
| `tcp` | TCP traffic |
| `udp` | UDP traffic |
| `icmp` | ICMP traffic |
| `ip` | All IP traffic |
| `http`, `tls`, `dns`, `ssh`, `ftp`, etc. | Application-layer protocols |

### Address and Port Syntax

| Syntax | Meaning |
|---|---|
| `203.0.113.5` | Specific IP address |
| `203.0.113.0/24` | CIDR network block |
| `any` | Match all addresses or ports |
| `!22` | Negation — match everything **except** port 22 |
| `[80, 443]` | Port group |

### Direction

| Operator | Meaning |
|---|---|
| `->` | Unidirectional (source → destination) |
| `<>` | Bidirectional |

### Header Examples

```
# All TCP traffic to any port 80
tcp any any -> any 80

# SSH traffic into the 203.0.113.0/24 block on any port except 22
ssh any any -> 203.0.113.0/24 !22

# Catch-all: inspect all traffic regardless of protocol or address
ip any any -> any any
```

---

## Options

Options are enclosed in parentheses `(...)`, separated by semicolons `;`, and generally use `key:value;` format.

### `msg` — Human-Readable Alert Message

```
msg:"SSH TRAFFIC on non-SSH port";
```

Always include a descriptive `msg`. It is the primary identifier when reviewing alerts in logs or SIEM dashboards.

---

### `content` — Payload Inspection

Match a specific byte sequence or string within the packet payload:

```
content:"uid=0|28|root|29|";
```

> Values in `|...|` are hexadecimal byte sequences.

Content matching is **case-sensitive** by default. Use `nocase;` for case-insensitive matching:

```
content:"your_domain.com"; nocase;
```

Combine with application-layer keywords for targeted inspection:

```
alert dns any any -> any any (msg:"DNS query for example.com"; dns.query; content:"example.com"; nocase; sid:1000010;)
```

---

### `sid` and `rev` — Signature ID and Revision

Every signature requires a unique **Signature ID (SID)**:

```
sid:1000000;
```

**SID allocation ranges:**

| Range | Purpose |
|---|---|
| `1000000–1999999` | Custom / local rules |
| `2200000–2299999` | Suricata built-in rules |
| `2000000–2099999` | Emerging Threats ET Open |

Duplicate SIDs prevent Suricata from starting:

```
[ERRCODE: SC_ERR_DUPLICATE_SIG(176)] - Duplicate signature "..."
```

The `rev` keyword tracks the revision history of a rule:

```
sid:1000000; rev:2;
```

---

### `reference` — External Documentation

Link to external resources for an alert:

```
reference:cve,2014-0160;
reference:url,heartbleed.com;
```

Available reference types are defined in `/etc/suricata/reference.config`.

---

### `classtype` — Traffic Classification

Assign a predefined classification category:

```
classtype:bad-unknown;
classtype:misc-attack;
classtype:misc-activity;
classtype:protocol-command-decode;
```

Classification entries, including their descriptions and default priorities, are defined in `/etc/suricata/classification.config`:

```
config classification: bad-unknown,Potentially Bad Traffic,2
config classification: misc-attack,Misc Attack,2
```

Override the default priority with the `priority` keyword (1 is highest):

```
classtype:misc-attack; priority:1;
```

---

### `target` — Source and Destination Host Identification

Instructs Suricata to label the source and target hosts in the EVE log:

```
target:dest_ip;    # Traffic directed at your server
target:src_ip;     # Traffic originating from your server
```

When `target` is set, `eve.json` includes structured host fields:

```json
"source": {
  "ip": "198.51.100.10",
  "port": 54321
},
"target": {
  "ip": "203.0.113.5",
  "port": 2022
}
```

This enriches SIEM queries when searching for alerts by victim or attacker.

---

## Writing Custom Rules

### 1. SSH on a Non-Standard Port

```
alert ssh any any -> 203.0.113.5 !22 (
  msg:"SSH TRAFFIC on non-SSH port";
  flow:to_client, not_established;
  classtype:misc-attack;
  target:dest_ip;
  sid:1000000;
  rev:1;
)
```

### 2. HTTP on a Non-Standard Port

```
alert http any any -> 203.0.113.5 !80 (
  msg:"HTTP REQUEST on non-HTTP port";
  flow:to_client, not_established;
  classtype:misc-activity;
  sid:1000002;
  rev:1;
)
```

### 3. TLS on a Non-Standard Port

```
alert tls any any -> 203.0.113.5 !443 (
  msg:"TLS TRAFFIC on non-standard port";
  flow:to_client, not_established;
  classtype:misc-activity;
  sid:1000004;
  rev:1;
)
```

### 4. DNS Query for a Specific Domain

```
alert dns any any -> any any (
  msg:"DNS query for suspicious domain";
  dns.query;
  content:"malicious-domain.com";
  nocase;
  sid:1000010;
  rev:1;
)
```

---

## Deploying Custom Rules

Create a local rules file:

```bash
sudo nano /var/lib/suricata/rules/local.rules
```

Add your rules and register the file in `suricata.yaml`:

```bash
sudo nano /etc/suricata/suricata.yaml
```

```yaml
rule-files:
  - suricata.rules
  - local.rules
```

Validate the updated configuration:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v
```

Hot-reload rules without restarting:

```bash
sudo kill -usr2 $(pidof suricata)
```

---

## Summary

In this guide you:

- Learned the three-part signature structure: **Action**, **Header**, **Options**
- Understood each action type and when `drop`/`reject` apply
- Built headers using protocols, IPs, ports, negation, and direction operators
- Explored key options: `content`, `msg`, `sid`, `rev`, `reference`, `classtype`, `target`
- Created and deployed custom rules for SSH, HTTP, TLS, and DNS traffic

---

## References

- [Suricata Rules Documentation](https://suricata.readthedocs.io/en/latest/rules/)
- [Emerging Threats SID Allocation](https://doc.emergingthreats.net/bin/view/Main/SidAllocation)
- [Suricata Classification Config](https://suricata.readthedocs.io/en/latest/rules/meta.html#classtype)

---

## Navigation

| | |
|---|---|
| **← Previous** | [Part 1: Installing Suricata on Ubuntu 20.04](01-install-suricata.md) |
| **Next →** | [Part 3: Configuring Suricata as an IPS](03-configure-ips.md) |
| **↑ Overview** | [README — Series Overview](README.md) |
