---
title: "How To Configure Suricata as an Intrusion Prevention System (IPS) on Ubuntu 20.04"
description: "Enable Suricata IPS mode using NFQUEUE, configure drop and reject actions on custom signatures, and route network traffic through Suricata via UFW on Ubuntu 20.04."
author: "Jamon Camisso"
date: 2021-12-10
category: Security
series: "SIEM with Suricata and Elastic Stack"
part: 3
tags:
  - suricata
  - ips
  - nfqueue
  - ufw
  - ubuntu
  - security
  - intrusion-prevention
---

# Part 3 — How To Configure Suricata as an IPS on Ubuntu 20.04

| | |
|---|---|
| **Series** | SIEM with Suricata and Elastic Stack |
| **Part** | 3 of 5 |
| **Difficulty** | Intermediate |
| **Time** | ~30 minutes |
| **OS** | Ubuntu 20.04 LTS |

---

## Introduction

By default, Suricata runs as a passive **IDS** — it observes traffic and generates alerts without blocking anything. This guide covers switching to active **IPS mode**, enabling Suricata to drop or reject matching packets in real time.

> **Warning:** Before enabling IPS mode, thoroughly review your active signatures. An overly broad or misconfigured rule can block legitimate traffic — including your own SSH access to the server.

---

## Prerequisites

- Suricata installed and running in IDS mode ([Part 1](01-install-suricata.md))
- Familiarity with signature structure ([Part 2](02-understanding-signatures.md))
- ET Open ruleset loaded via `suricata-update`
- `jq` installed: `sudo apt install jq`

---

## Step 1 — Adding Custom Signatures

### Find Your Server's Public IP Addresses

```bash
ip -brief address show
```

Example output:

```
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             203.0.113.5/20 2001:DB8::1/32 ...
eth1             UP             10.137.0.2/16 ...
```

Note your public IPv4 (`203.0.113.5`) and IPv6 (`2001:DB8::1/32`) addresses.

### Create a Local Rules File

```bash
sudo nano /var/lib/suricata/rules/local.rules
```

Add signatures to detect traffic on non-standard ports. Replace `203.0.113.5` and `2001:DB8::1/32` with your actual public IPs:

**SSH on a non-standard port:**

```
alert ssh any any -> 203.0.113.5 !22 (msg:"SSH TRAFFIC on non-SSH port"; flow:to_client,not_established; classtype:misc-attack; target:dest_ip; sid:1000000;)
alert ssh any any -> 2001:DB8::1/32 !22 (msg:"SSH TRAFFIC on non-SSH port"; flow:to_client,not_established; classtype:misc-attack; target:dest_ip; sid:1000001;)
```

**HTTP on a non-standard port:**

```
alert http any any -> 203.0.113.5 !80 (msg:"HTTP REQUEST on non-HTTP port"; flow:to_client,not_established; classtype:misc-activity; sid:1000002;)
alert http any any -> 2001:DB8::1/32 !80 (msg:"HTTP REQUEST on non-HTTP port"; flow:to_client,not_established; classtype:misc-activity; sid:1000003;)
```

**TLS on a non-standard port:**

```
alert tls any any -> 203.0.113.5 !443 (msg:"TLS TRAFFIC on non-TLS port"; flow:to_client,not_established; classtype:misc-activity; sid:1000004;)
alert tls any any -> 2001:DB8::1/32 !443 (msg:"TLS TRAFFIC on non-TLS port"; flow:to_client,not_established; classtype:misc-activity; sid:1000005;)
```

Register the file in `suricata.yaml`:

```bash
sudo nano /etc/suricata/suricata.yaml
```

```yaml
rule-files:
  - suricata.rules
  - local.rules
```

Validate the configuration:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v
```

---

## Step 2 — Converting Signature Actions to `drop`

Once signatures are tested and generating expected alerts, change `alert` to `drop` to actively block matching traffic.

```bash
sudo nano /var/lib/suricata/rules/local.rules
```

```
# /var/lib/suricata/rules/local.rules

drop ssh any any -> 203.0.113.5 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype:misc-attack; target:dest_ip; sid:1000000;)
drop ssh any any -> 2001:DB8::1/32 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype:misc-attack; target:dest_ip; sid:1000001;)
drop http any any -> 203.0.113.5 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000002;)
drop http any any -> 2001:DB8::1/32 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000003;)
drop tls any any -> 203.0.113.5 !443 (msg:"TLS TRAFFIC on non-TLS port"; classtype:misc-activity; sid:1000004;)
drop tls any any -> 2001:DB8::1/32 !443 (msg:"TLS TRAFFIC on non-TLS port"; classtype:misc-activity; sid:1000005;)
```

### `drop` vs. `reject`

| Action | Behavior | Best For |
|---|---|---|
| `drop` | Silently discards the packet; TCP connections time out | Network scans, invalid connections |
| `reject` | Sends TCP RST (TCP) or ICMP unreachable (UDP/ICMP); drops packet | Fast client feedback required |

> **Recommendation for `suricata.rules`:** The ET Open ruleset contains 30,000+ signatures. Do **not** bulk-convert all of them to `drop`. Instead, keep them as `alert` for several days to analyze which SIDs generate alerts relevant to your environment, then selectively convert those to `drop`.

---

## Step 3 — Enabling NFQUEUE Mode (IPS)

Suricata defaults to `af-packet` mode (passive capture). Switch to `nfqueue` mode to actively intercept and process packets via the Linux Netfilter framework:

```bash
sudo nano /etc/default/suricata
```

```bash
# /etc/default/suricata

# LISTENMODE=af-packet
LISTENMODE=nfqueue
```

Restart the service:

```bash
sudo systemctl restart suricata.service
```

Verify IPS mode is active:

```bash
sudo systemctl status suricata.service
```

Look for the confirmation line:

```
Starting suricata in IPS (nfqueue) mode... done.
```

---

## Step 4 — Configuring UFW to Route Traffic Through Suricata

Open the UFW IPv4 rules file:

```bash
sudo nano /etc/ufw/before.rules
```

Insert the following block immediately **after** the `# End required lines` comment:

```
## Start Suricata NFQUEUE rules
-I INPUT 1 -p tcp --dport 22 -j NFQUEUE --queue-bypass
-I OUTPUT 1 -p tcp --sport 22 -j NFQUEUE --queue-bypass
-I FORWARD -j NFQUEUE
-I INPUT 2 -j NFQUEUE
-I OUTPUT 2 -j NFQUEUE
## End Suricata NFQUEUE rules
```

Apply the **same block** to `/etc/ufw/before6.rules` for IPv6 traffic.

### Rule Explanation

| Rule | Purpose |
|---|---|
| `INPUT 1 --dport 22 --queue-bypass` | Bypass Suricata for inbound SSH — maintains access if Suricata stops |
| `OUTPUT 1 --sport 22 --queue-bypass` | Bypass Suricata for outbound SSH — same safety reason |
| `FORWARD -j NFQUEUE` | Route forwarded traffic (gateway mode) through Suricata |
| `INPUT 2 -j NFQUEUE` | Route all remaining inbound traffic through Suricata |
| `OUTPUT 2 -j NFQUEUE` | Route all remaining outbound traffic through Suricata |

> **Critical:** The SSH bypass rules ensure SSH access is preserved even if Suricata is stopped or crashes. Without them, all traffic would be queued to a dead NFQUEUE and dropped — locking you out of the server.

Reload UFW:

```bash
sudo systemctl restart ufw.service
```

### Alternative: firewalld

```bash
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p tcp --dport 22 -j NFQUEUE --queue-bypass
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 1 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 0 -p tcp --dport 22 -j NFQUEUE --queue-bypass
firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT 1 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv6 filter FORWARD 0 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -p tcp --sport 22 -j NFQUEUE --queue-bypass
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 1 -j NFQUEUE
firewall-cmd --permanent --direct --add-rule ipv6 filter OUTPUT 0 -p tcp --sport 22 -j NFQUEUE --queue-bypass
firewall-cmd --permanent --direct --add-rule ipv6 filter OUTPUT 1 -j NFQUEUE
```

---

## Step 5 — Testing Traffic Blocking

Modify `sid:2100498` in `/var/lib/suricata/rules/suricata.rules` to use `drop`:

```
drop ip any any -> any any (msg:"GPL ATTACK_RESPONSE id check returned root"; content:"uid=0|28|root|29|"; classtype:bad-unknown; sid:2100498; rev:7; metadata:created_at 2010_09_23, updated_at 2010_09_23;)
```

Reload signatures:

```bash
sudo kill -usr2 $(pidof suricata)
```

Send the test request:

```bash
curl --max-time 5 http://testmynids.org/uid/index.html
```

Expected result — request times out:

```
curl: (28) Operation timed out after 5000 milliseconds with 0 out of 39 bytes received
```

Confirm the block in the EVE log:

```bash
jq 'select(.alert .signature_id==2100498)' /var/log/suricata/eve.json
```

Expected output:

```json
{
  "alert": {
    "action": "blocked",
    "signature_id": 2100498,
    "signature": "GPL ATTACK_RESPONSE id check returned root",
    "category": "Potentially Bad Traffic",
    "severity": 2
  }
}
```

The `"action": "blocked"` field confirms Suricata is actively dropping traffic in IPS mode.

---

## Summary

In this guide you:

- Created custom signatures for SSH, HTTP, and TLS traffic on non-standard ports
- Converted signature actions from `alert` to `drop` for active blocking
- Switched Suricata from IDS (`af-packet`) to IPS (`nfqueue`) mode
- Configured UFW to route all traffic through Suricata while preserving SSH access
- Verified traffic blocking via a timed-out curl request and EVE log inspection

---

## References

- [Suricata IPS Mode Documentation](https://suricata.readthedocs.io/en/latest/setting-up-ipsinline-for-linux.html)
- [Netfilter NFQUEUE](https://netfilter.org/projects/libnetfilter_queue/)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)

---

## Navigation

| | |
|---|---|
| **← Previous** | [Part 2: Understanding Suricata Signatures](02-understanding-signatures.md) |
| **Next →** | [Part 4: Building a SIEM with Elastic Stack](04-build-siem.md) |
| **↑ Overview** | [README — Series Overview](README.md) |
