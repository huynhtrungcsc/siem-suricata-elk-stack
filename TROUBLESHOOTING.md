# Troubleshooting Guide

Common issues when running `setup-elk.sh` and `setup-suricata.sh`.

---

## Prerequisites Checklist

Before running either script, confirm:

| Requirement | Check |
|---|---|
| Ubuntu 20.04 LTS on both servers | `lsb_release -rs` → must show `20.04` |
| Non-root user with sudo | `sudo -v` → must not error |
| Internet access | `curl -s https://artifacts.elastic.co` → must respond |
| ELK server has ≥ 4 GB RAM | `free -h` → check `Mem:` row |
| Both servers on same private network | `ping <other-server-ip>` → must reply |

---

## Execution Order

**Always run in this order:**

```
1. sudo ./setup-elk.sh        ← on the Elasticsearch server
2. sudo ./setup-suricata.sh   ← on the Suricata server
```

Running `setup-suricata.sh` before `setup-elk.sh` will fail because Filebeat needs the `elastic` password and a running Elasticsearch endpoint.

---

## setup-elk.sh Issues

### ❌ Elasticsearch fails to start

**Symptoms:** `systemctl status elasticsearch` shows `failed` or `activating` for more than 2 minutes.

**Common causes and fixes:**

```bash
# Check the full error log
sudo journalctl -u elasticsearch -n 80 --no-pager

# Cause 1: Not enough RAM (need ≥ 4 GB)
free -h
# If less than 4 GB — add swap or use a larger server

# Cause 2: Port 9200 already in use
sudo ss -tlnp | grep 9200
# If occupied — stop the conflicting process before running the script

# Cause 3: JVM cannot allocate heap
# Look for: "OutOfMemoryError" or "Cannot allocate memory" in journalctl output
# Fix: reduce JVM heap in /etc/elasticsearch/jvm.options
#   -Xms1g
#   -Xmx1g
# (Not recommended for production — upgrade RAM instead)
```

---

### ❌ elasticsearch-setup-passwords fails

**Symptoms:** Password generation step errors or produces empty output.

**Cause:** Elasticsearch is not fully ready yet (green/yellow health required).

```bash
# Wait for cluster health
curl -s http://localhost:9200/_cluster/health | jq .status
# Must return "green" or "yellow" before passwords can be set

# Run manually once healthy
sudo /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto -b
```

---

### ❌ Kibana takes too long to start

**Symptoms:** The script warns `Kibana did not respond within 90s`.

**This is normal.** Kibana can take 1–3 minutes to fully initialize on first start.

```bash
# Check Kibana startup progress
sudo journalctl -u kibana -f

# Test manually when ready
curl -s http://localhost:5601/api/status | jq .status.overall.level
# Returns "available" when ready

# Start Kibana manually if it stopped
sudo systemctl start kibana
```

---

### ❌ Wrong Suricata server IP entered

**Symptom:** Filebeat cannot connect to Elasticsearch later; logs show connection refused on port 9200.

**Fix:** Re-run the UFW rule with the correct IP.

```bash
# On the ELK server — replace OLD_IP and NEW_IP
sudo ufw delete allow from OLD_IP to any port 9200
sudo ufw allow from NEW_IP to any port 9200
sudo ufw status | grep 9200
```

---

## setup-suricata.sh Issues

### ❌ Suricata starts but detects nothing

**Cause 1: Wrong network interface selected.**

```bash
# List interfaces and check which one carries live traffic
ip -br link show
tcpdump -i <interface> -c 5   # should show packets immediately

# Fix: update suricata.yaml with the correct interface
sudo nano /etc/suricata/suricata.yaml
# Find: af-packet:
#         - interface: <wrong>
# Change to the correct interface, then:
sudo systemctl restart suricata
```

**Cause 2: Suricata is running but rules are not loaded.**

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v 2>&1 | grep -E "rules|error"
# Should show: "X rule files processed"
```

**Verify detection manually:**

```bash
curl http://testmynids.org/uid/index.html
sleep 2
grep 2100498 /var/log/suricata/fast.log
# Should return at least one alert line
```

---

### ❌ Filebeat not shipping logs to Elasticsearch

**Check Filebeat service:**

```bash
sudo systemctl status filebeat
sudo journalctl -u filebeat -n 50 --no-pager
```

**Cause 1: Wrong elastic password.**

```bash
# Test the connection manually
curl -u elastic:<password> http://<ELK_IP>:9200
# Should return cluster info JSON — if 401, password is wrong

# Fix: update filebeat.yml with the correct password
sudo nano /etc/filebeat/filebeat.yml
# Find: password: "..."
# Update, then:
sudo systemctl restart filebeat
```

**Cause 2: Wrong ELK server IP.**

```bash
# Test connectivity from Suricata server
curl -v http://<ELK_IP>:9200
# "Connection refused" → wrong IP or Elasticsearch not running
# "Connection timed out" → firewall blocking port 9200

# Fix: update filebeat.yml output.elasticsearch.hosts
sudo nano /etc/filebeat/filebeat.yml
sudo systemctl restart filebeat
```

**Cause 3: Firewall blocking port 9200.**

```bash
# On the ELK server — check UFW allows the Suricata server IP
sudo ufw status | grep 9200
# Should show: ALLOW  from <suricata-ip>

# If missing, add the rule:
sudo ufw allow from <suricata-ip> to any port 9200
```

---

### ❌ EVE log file not found

**Symptom:** Filebeat module cannot find `/var/log/suricata/eve.json`.

```bash
# Check if Suricata is producing the eve.json file
ls -lh /var/log/suricata/
# If eve.json is missing, ensure eve-log is enabled in suricata.yaml:
grep -A5 'eve-log' /etc/suricata/suricata.yaml | grep enabled
# Must show: enabled: yes

sudo systemctl restart suricata
```

---

### ❌ filebeat setup fails

**Cause:** Kibana was not reachable when the script ran.

```bash
# Test Kibana from the Suricata server
curl -s http://<ELK_IP>:5601/api/status | jq .status.overall.level

# Once Kibana responds with "available", re-run setup:
sudo filebeat setup -e
```

---

## Verifying the Full Pipeline

Run these checks in order to confirm every stage is working:

```bash
# 1. Suricata is running and detecting
sudo systemctl status suricata
curl http://testmynids.org/uid/index.html && sleep 2
grep 2100498 /var/log/suricata/fast.log

# 2. EVE log is being written
tail -5 /var/log/suricata/eve.json | jq .event_type

# 3. Filebeat is running and connected
sudo systemctl status filebeat
sudo filebeat test output

# 4. Elasticsearch is receiving data
curl -u elastic:<password> \
  "http://<ELK_IP>:9200/filebeat-*/_count" | jq .count
# Should increase over time as events arrive

# 5. Open Kibana and verify
# http://<ELK_IP>:5601 → Security → Events
```
