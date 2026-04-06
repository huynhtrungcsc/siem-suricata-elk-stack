---
title: "How To Create Rules, Timelines, and Cases from Suricata Events Using Kibana's SIEM Apps"
description: "Create custom Kibana detection rules, build investigation timelines grouped by community_id, and manage security cases to track and resolve Suricata-generated alerts."
author: "Jamon Camisso"
date: 2022-03-01
category: Security
series: "SIEM with Suricata and Elastic Stack"
part: 5
tags:
  - suricata
  - kibana
  - siem
  - detection-rules
  - timelines
  - cases
  - elasticsearch
  - security-operations
---

# Part 5 — Kibana SIEM: Rules, Timelines, and Cases

| | |
|---|---|
| **Series** | SIEM with Suricata and Elastic Stack |
| **Part** | 5 of 5 |
| **Difficulty** | Intermediate |
| **Time** | ~30 minutes |
| **OS** | Ubuntu 20.04 LTS |

---

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Step 1 — Enabling API Keys in Elasticsearch](#step-1--enabling-api-keys-in-elasticsearch)
- [Step 2 — Creating Detection Rules in Kibana](#step-2--creating-detection-rules-in-kibana)
  - [Access the Rules Dashboard](#access-the-rules-dashboard)
  - [Configure a Custom Query Rule](#configure-a-custom-query-rule)
  - [Define Rule Metadata](#define-rule-metadata)
- [Step 3 — Creating a Timeline to Investigate Alerts](#step-3--creating-a-timeline-to-investigate-alerts)
  - [Generate Test Traffic](#generate-test-traffic)
  - [Add community_id to the Alerts Table](#add-community_id-to-the-alerts-table)
  - [Add Alerts to a Timeline](#add-alerts-to-a-timeline)
  - [Configure and Save the Timeline](#configure-and-save-the-timeline)
- [Step 4 — Creating and Managing SIEM Cases](#step-4--creating-and-managing-siem-cases)
- [Investigation Workflow](#investigation-workflow)
- [Summary](#summary)

---

## Introduction

The [previous guide](04-build-siem.md) established the full SIEM pipeline — Suricata → Filebeat → Elasticsearch → Kibana. This final guide uses Kibana's built-in Security apps to:

1. **Create detection rules** that generate structured alerts from Suricata events
2. **Build timelines** to group and investigate correlated alerts
3. **Manage cases** to track incidents from detection through resolution

---

## Prerequisites

- A working SIEM stack (Suricata + Elastic Stack) as configured in [Parts 1–4](README.md)
- Kibana accessible via SSH tunnel at `http://127.0.0.1:5601`
- Active Suricata events visible in the Suricata dashboards

### Example Suricata Signatures Referenced in This Guide

```
alert ssh any any -> 203.0.113.5 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype:misc-attack; target:dest_ip; sid:1000000;)
alert ssh any any -> 2001:DB8::1/32 !22 (msg:"SSH TRAFFIC on non-SSH port"; classtype:misc-attack; target:dest_ip; sid:1000001;)
alert http any any -> 203.0.113.5 !80 (msg:"HTTP REQUEST on non-HTTP port"; classtype:misc-activity; sid:1000002;)
alert tls any any -> 203.0.113.5 !443 (msg:"TLS TRAFFIC on non-TLS port"; classtype:misc-activity; sid:1000004;)
```

---

## Step 1 — Enabling API Keys in Elasticsearch

Kibana's SIEM rules require the Elasticsearch API key authentication feature. Enable it on the **Elasticsearch server**:

```bash
sudo nano /etc/elasticsearch/elasticsearch.yml
```

Add the following line at the end of the file:

```yaml
xpack.security.authc.api_key.enabled: true
```

Restart Elasticsearch:

```bash
sudo systemctl restart elasticsearch.service
```

---

## Step 2 — Creating Detection Rules in Kibana

Detection rules continuously query Elasticsearch event data and generate structured alerts when matching patterns are found.

### Access the Rules Dashboard

Navigate to: `http://localhost:5601/app/security/rules/`

Click **Create new rule** in the top-right corner.

### Configure a Custom Query Rule

1. Ensure the **Custom query** rule type card is selected.

2. In the **Custom query** field, enter a KQL query targeting the Suricata SID. Ensure `rule.id` values correspond to the `sid` values in your Suricata signatures:

   ```
   rule.id: "1000000" or rule.id: "1000001"
   ```

3. Set the **Query quick preview** dropdown to **Last Month**.

4. Click **Preview Results** to confirm matching events appear in the graph.

5. Click **Continue**.

### Define Rule Metadata

| Field | Example Value |
|---|---|
| **Rule Name** | `SSH TRAFFIC on non-SSH port` |
| **Description** | `Detects SSH connection attempts directed at non-standard ports, which may indicate port scanning or service enumeration activity.` |
| **Severity** | `Medium` |
| **Risk Score** | `47` |

Expand **Advanced Settings** to optionally add:
- Investigation notes or remediation steps
- References to threat intelligence articles
- MITRE ATT&CK technique mappings

6. Click **Continue** → leave **Schedule rule** at defaults (runs every 5 minutes) → Click **Continue**.

7. On the **Rule actions** step, click **Create & activate rule**.

> **Note:** Allow up to 5 minutes for the first alerts to populate after rule activation.

> **Why detection rules run on a schedule (not in real time):** Kibana's detection engine is not a streaming processor — it operates as a periodic scheduled job. At each interval (default: every 5 minutes), it runs a pre-defined KQL or EQL query against the Elasticsearch index, collects matching documents from the lookback window, and generates structured alerts. This design allows complex multi-field correlation queries that would be prohibitively expensive to evaluate on every incoming event. The trade-off is an inherent latency of up to one full schedule interval between an event occurring and its corresponding alert appearing. For time-critical detections, the interval can be reduced to 1 minute.

Repeat this process for each additional Suricata SID you wish to monitor.

---

## Step 3 — Creating a Timeline to Investigate Alerts

Timelines group related alerts into a focused investigation view based on shared network flow identifiers.

### Generate Test Traffic

From your local machine, attempt an SSH connection on a non-standard port to trigger `sid:1000000`:

```bash
ssh -p 80 your_server_ip
```

Allow a few minutes for the alert to process through Elasticsearch and appear in Kibana.

### Add `community_id` to the Alerts Table

1. Navigate to the Alerts dashboard: `http://127.0.0.1:5601/app/security/alerts`
2. Click the **Fields** button.
3. Search for `network.community_id` and tick the checkbox.
4. Close the modal.

The Community Flow ID column now appears in the alerts table.

> **Why `community_id` is the key correlation field:** A single attack event — one port scan, one exploitation attempt — typically generates multiple separate alerts from different Suricata rules (e.g., a TCP SYN alert, then an application-layer alert, then a C2 callback alert). Without a shared identifier, each alert appears as an isolated event. The Community Flow ID links all alerts that belong to the same network flow, allowing you to see the complete sequence of events in a timeline. This is especially valuable when a single intrusion chain spans multiple protocols or triggers rules from both `local.rules` and `suricata.rules`.

### Add Alerts to a Timeline

1. Hover over an alert row with a specific `community_id`.
2. Click the **Add to timeline investigation** icon.

This adds all alerts sharing that `community_id` to a new timeline, enabling investigation of the complete network flow.

### Configure and Save the Timeline

1. Click the **Untitled Timeline** link at the bottom-left of the browser.
2. In the timeline view, click **All data sources** → select **Detection Alerts** → click **Save**.

   > This filters the timeline to show only Kibana-generated detection alerts, excluding raw Suricata events.

3. Click the **pencil icon** (top-left) to rename the timeline.
4. Provide a meaningful **Name** and optional **Description**.
5. Click **Save**.

**Naming convention suggestion:** `<Alert Type> — <Source IP> — <Date>`
Example: `SSH on non-SSH port — 198.51.100.10 — 2022-03-01`

---

## Step 4 — Creating and Managing SIEM Cases

Cases provide a centralized location for tracking the full lifecycle of a security incident — from initial detection through investigation to resolution.

### Create a Case from a Timeline

1. Ensure you are on a saved timeline page.
2. Click **Attach to case** (top-right) → **Attach to new case**.

### Fill in Case Details

| Field | Example Value |
|---|---|
| **Name** | `SSH TRAFFIC on non-SSH port from 198.51.100.10` |
| **Tags** | `ssh`, `port-scan`, `intrusion-attempt` |
| **Description** | Link to the associated timeline; include initial findings |
| **Severity** | `Medium` |

> **Naming convention:** Use the format `<attack type> from <source IP>` to maintain consistency with Suricata signature messages and facilitate cross-referencing between rules, timelines, and cases.

Click **Create case**.

### Add Alerts to the Case

1. Return to the timeline associated with the case.
2. For each relevant alert, click the **More actions** icon (⋮).
3. Select **Add to existing case**.
4. Select the corresponding case from the modal.

### Document Investigation Progress

Navigate to **Security → Cases** from the left menu. Open your case and add Markdown-formatted comments for:

- Investigation steps taken
- Suricata rule changes made in response to the alert
- IOCs (Indicators of Compromise) identified
- Escalation notes or team member assignments
- Resolution and remediation actions

---

## Investigation Workflow

```
Alert appears in Kibana
        │
        ▼
Review alert details
(signature, src_ip, dst_ip, community_id, timestamp)
        │
        ▼
Group related alerts by community_id → Create Timeline
        │
        ▼
Analyze Timeline
(packet sequence, flow duration, protocol anomalies)
        │
        ▼
Create Case → Attach Timeline
        │
        ▼
Add individual alerts to Case
        │
        ▼
Document findings, remediation steps, and resolution
        │
        ▼
Close Case
```

---

## Summary

In this final guide you:

- Enabled Elasticsearch API key authentication for Kibana's SIEM functions
- Created a custom detection rule using Kibana Query Language (KQL)
- Added the `community_id` field to the alerts table for flow correlation
- Built a timeline grouping alerts by network flow
- Created a security case and linked it to the timeline and individual alerts
- Established a structured incident investigation workflow

---

## References

- [Elastic Security Documentation](https://www.elastic.co/guide/en/security/current/)
- [Kibana Detection Rules](https://www.elastic.co/guide/en/security/current/rules-ui-create.html)
- [Kibana Timelines](https://www.elastic.co/guide/en/security/current/timelines-ui.html)
- [Kibana Cases](https://www.elastic.co/guide/en/security/current/cases-overview.html)

---

## Navigation

| | |
|---|---|
| **← Previous** | [Part 4: Building a SIEM with Elastic Stack](04-build-siem.md) |
| **↑ Overview** | [README — Series Overview](README.md) |
