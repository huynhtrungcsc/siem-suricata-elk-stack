---
title: "How To Build a SIEM with Suricata and Elastic Stack on Ubuntu 20.04"
description: "Install and configure Elasticsearch and Kibana with xpack security, deploy Filebeat on the Suricata server to forward EVE logs, and access Kibana SIEM dashboards."
author: "Jamon Camisso"
date: 2022-01-15
category: Security
series: "SIEM with Suricata and Elastic Stack"
part: 4
tags:
  - suricata
  - elasticsearch
  - kibana
  - filebeat
  - siem
  - ubuntu
  - elastic-stack
  - security
---

# Part 4 — How To Build a SIEM with Suricata and Elastic Stack

| | |
|---|---|
| **Series** | SIEM with Suricata and Elastic Stack |
| **Part** | 4 of 5 |
| **Difficulty** | Intermediate |
| **Time** | ~45 minutes |
| **OS** | Ubuntu 20.04 LTS (both servers) |

---

## Introduction

The previous guides covered installing and operating Suricata as an IDS/IPS. This guide integrates Suricata with the **Elastic Stack** to create a centralized SIEM for storing, visualizing, and investigating security events.

### Architecture

| Component | Server | Role |
|---|---|---|
| Suricata | Suricata Server | Generates `eve.json` event logs |
| Filebeat | Suricata Server | Ships `eve.json` to Elasticsearch |
| Elasticsearch | Elasticsearch Server | Indexes and stores all events |
| Kibana | Elasticsearch Server | Visualizes events; provides SIEM UI |

---

## Prerequisites

### Suricata Server
- Suricata installed, running, and generating EVE logs ([Parts 1–3](README.md))

### Elasticsearch Server *(new)*
- Ubuntu 20.04 with **4 GB RAM** and **2 CPUs** minimum
- Non-root user with `sudo` privileges
- Private IP address reachable from the Suricata server

---

## Step 1 — Installing Elasticsearch and Kibana

*Perform on the **Elasticsearch server**.*

Add the Elastic GPG signing key:

```bash
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
```

Add the Elastic 7.x repository:

```bash
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
```

Install both packages:

```bash
sudo apt update
sudo apt install elasticsearch kibana
```

Find your server's private IP address (note the interface name):

```bash
ip -brief address show
```

---

## Step 2 — Configuring Elasticsearch

### Networking

Open the configuration file:

```bash
sudo nano /etc/elasticsearch/elasticsearch.yml
```

Find `#network.host:` and add a bind host line beneath it:

```yaml
# /etc/elasticsearch/elasticsearch.yml

#network.host: 192.168.0.1
network.bind_host: ["127.0.0.1", "your_private_ip"]
```

Append the following to the end of the file:

```yaml
discovery.type: single-node
xpack.security.enabled: true
```

Allow traffic on the private network interface:

```bash
sudo ufw allow in on eth1
sudo ufw allow out on eth1
```

Replace `eth1` with your actual private interface name.

### Start Elasticsearch

```bash
sudo systemctl start elasticsearch.service
```

### Generate Passwords

```bash
cd /usr/share/elasticsearch/bin
sudo ./elasticsearch-setup-passwords auto
```

Press `y` to proceed. Example output:

```
Changed password for user kibana_system
PASSWORD kibana_system = 1HLVxfqZMd7aFQS6Uabl

Changed password for user elastic
PASSWORD elastic = 6kNbsxQGYZ2EQJiqJpgl
```

> **Important:** Save all generated passwords securely. This utility cannot be run again. You will need:
> - `kibana_system` password → Kibana configuration
> - `elastic` password → Filebeat configuration and Kibana login

---

## Step 3 — Configuring Kibana

### Generate Encryption Keys

```bash
cd /usr/share/kibana/bin/
sudo ./kibana-encryption-keys generate -q
```

Output example:

```
xpack.encryptedSavedObjects.encryptionKey: 66fbd85ceb3cba51c0e939fb2526f585
xpack.reporting.encryptionKey: 9358f4bc7189ae0ade1b8deeec7f38ef
xpack.security.encryptionKey: 8f847a594e4a813c4187fa93c884e92b
```

Open the Kibana configuration file:

```bash
sudo nano /etc/kibana/kibana.yml
```

**Append** the three encryption key lines to the end of the file:

```yaml
xpack.encryptedSavedObjects.encryptionKey: 66fbd85ceb3cba51c0e939fb2526f585
xpack.reporting.encryptionKey: 9358f4bc7189ae0ade1b8deeec7f38ef
xpack.security.encryptionKey: 8f847a594e4a813c4187fa93c884e92b
```

### Network Binding

Find `#server.host: "localhost"` and add the following line beneath it:

```yaml
#server.host: "localhost"
server.host: "your_private_ip"
```

### Authentication (Keystore Method)

Store credentials in Kibana's encrypted keystore (preferred over editing `kibana.yml` directly):

```bash
cd /usr/share/kibana/bin

# Add Elasticsearch username
sudo ./kibana-keystore add elasticsearch.username
# Enter: kibana_system

# Add Elasticsearch password
sudo ./kibana-keystore add elasticsearch.password
# Enter: <kibana_system password from Step 2>
```

### Start Kibana

```bash
sudo systemctl start kibana.service
```

---

## Step 4 — Installing and Configuring Filebeat

*Perform on the **Suricata server**.*

Add the Elastic GPG key and repository:

```bash
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update && sudo apt install filebeat
```

Open the Filebeat configuration:

```bash
sudo nano /etc/filebeat/filebeat.yml
```

**Configure the Kibana endpoint** (line ~100):

```yaml
setup.kibana:
  #host: "localhost:5601"
  host: "your_private_ip:5601"
```

**Configure the Elasticsearch output** (line ~130):

```yaml
output.elasticsearch:
  hosts: ["your_private_ip:9200"]

  username: "elastic"
  password: "your_elastic_password"
```

Enable the built-in Suricata module:

```bash
sudo filebeat modules enable suricata
```

Load SIEM dashboards and ingest pipelines into Elasticsearch:

```bash
sudo filebeat setup
```

Expected output:

```
Index setup finished.
Loading dashboards (Kibana must be running and reachable)
Loaded dashboards
Loaded Ingest pipelines
```

Start Filebeat:

```bash
sudo systemctl start filebeat.service
```

---

## Step 5 — Accessing Kibana SIEM Dashboards

### Create an SSH Tunnel

Since Kibana listens only on the private IP, create a local port forward from your workstation:

```bash
ssh -L 5601:your_private_ip:5601 your_user@your_public_ip -N
```

| Flag | Purpose |
|---|---|
| `-L 5601:...` | Forward local port 5601 to Kibana on the remote server |
| `-N` | Hold the connection open without executing a shell command |

Press `CTRL+C` to close the tunnel.

### Log In to Kibana

Open a browser and navigate to: `http://127.0.0.1:5601`

| Field | Value |
|---|---|
| Username | `elastic` |
| Password | *(generated in Step 2)* |

### Find Suricata Dashboards

In the Kibana global search bar, enter:

```
type:dashboard suricata
```

Two dashboards appear:

| Dashboard | Contents |
|---|---|
| **[Filebeat Suricata] Events Overview** | All logged Suricata events |
| **[Filebeat Suricata] Alerts** | Signature-triggered alerts |

### Security Network Dashboard

Navigate to **Security → Network** from the left-hand menu to view:
- A world map of event sources
- Aggregate traffic statistics
- Scrollable event tables

---

## Key Elasticsearch Index Fields

| Field | Description |
|---|---|
| `event.type` | Event type: `alert`, `flow`, `dns`, `http`, etc. |
| `suricata.eve.alert.signature` | Name of the triggered signature |
| `suricata.eve.alert.signature_id` | Suricata SID |
| `network.community_id` | Community Flow ID for cross-tool correlation |
| `source.ip` / `destination.ip` | Source and destination addresses |

---

## Summary

In this guide you:

- Installed Elasticsearch and Kibana with xpack security enabled
- Generated and securely stored passwords for built-in Elasticsearch users
- Configured Kibana with encryption keys and keystore credentials
- Installed Filebeat on the Suricata server and enabled the Suricata module
- Loaded SIEM dashboards and verified Suricata events appear in Kibana

---

## References

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/)
- [Filebeat Suricata Module](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-module-suricata.html)

---

## Navigation

| | |
|---|---|
| **← Previous** | [Part 3: Configuring Suricata as an IPS](03-configure-ips.md) |
| **Next →** | [Part 5: Kibana SIEM Rules, Timelines, and Cases](05-kibana-siem-apps.md) |
| **↑ Overview** | [README — Series Overview](README.md) |
