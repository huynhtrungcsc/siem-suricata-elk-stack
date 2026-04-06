#!/usr/bin/env bash
# =============================================================================
#  setup-suricata.sh — Suricata IDS/IPS + Filebeat Setup
#  Repository: https://github.com/huynhtrungcsc/siem-suricata-elk-stack
#
#  RUN THIS SCRIPT ON: Suricata Server (NOT on the Elasticsearch server)
#
#  What this script does:
#    1. Installs Suricata from the official OISF PPA
#    2. Downloads the Emerging Threats Open ruleset
#    3. Configures Suricata (interface, Community Flow ID, eve.json)
#    4. Installs and configures Filebeat to ship logs to Elasticsearch
#    5. Enables and starts both services
#
#  Prerequisites:
#    - Ubuntu 20.04 LTS
#    - Non-root user with sudo privileges
#    - Elasticsearch server already running (run setup-elk.sh first)
#    - You have the 'elastic' user password from setup-elk.sh
#
#  Usage:
#    chmod +x setup-suricata.sh
#    sudo ./setup-suricata.sh
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

TOTAL_STEPS=9

# ── Helpers ───────────────────────────────────────────────────────────────────
banner() {
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║         Suricata IDS/IPS + Filebeat Setup Script         ║"
  echo "  ║     SIEM with Suricata and Elastic Stack — Part 1 & 4    ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${DIM}Run this script on the ${BOLD}Suricata Server${NC}${DIM}, not the ELK server.${NC}"
  echo ""
}

step() {
  echo -e "\n${BLUE}┌─ Step $1/${TOTAL_STEPS}: $2 ${NC}"
}

ok()     { echo -e "  ${GREEN}✔${NC}  $1"; }
warn()   { echo -e "  ${YELLOW}⚠${NC}  $1"; }
info()   { echo -e "  ${CYAN}ℹ${NC}  $1"; }
err()    { echo -e "  ${RED}✖${NC}  $1"; exit 1; }
divider(){ echo -e "${DIM}  ────────────────────────────────────────────────────────────${NC}"; }

manual_note() {
  echo -e "\n  ${YELLOW}┌─ MANUAL STEP ─────────────────────────────────────────────┐${NC}"
  while IFS= read -r line; do
    echo -e "  ${YELLOW}│${NC}  $line"
  done
  echo -e "  ${YELLOW}└───────────────────────────────────────────────────────────┘${NC}"
}

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    err "This script must be run as root. Use: sudo ./setup-suricata.sh"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
banner
check_root

# ─── Step 1: Gather information ───────────────────────────────────────────────
step 1 "Gathering required information"

# Detect available network interfaces (exclude loopback)
echo ""
info "Detected network interfaces:"
echo ""
ip -br link show | grep -v '^lo' | awk '{printf "    %-20s %s\n", $1, $2}'
echo ""

read -rp "  Enter the interface name Suricata should monitor (e.g. eth0, ens3): " IFACE
if ! ip link show "$IFACE" &>/dev/null; then
  err "Interface '$IFACE' not found. Run 'ip link show' to list available interfaces."
fi
ok "Interface: ${BOLD}$IFACE${NC}"

echo ""
read -rp "  Enter the private IP of the Elasticsearch server (e.g. 10.0.0.2): " ELK_IP
if [[ ! "$ELK_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  err "Invalid IP address: $ELK_IP"
fi
ok "Elasticsearch server: ${BOLD}$ELK_IP${NC}"

echo ""
read -rsp "  Enter the 'elastic' user password (from setup-elk.sh): " ELASTIC_PASS
echo ""
ok "Credentials captured"

divider

# ─── Step 2: System update ────────────────────────────────────────────────────
step 2 "Updating package index"
apt-get update -qq
ok "Package index updated"

# ─── Step 3: Install Suricata ─────────────────────────────────────────────────
step 3 "Installing Suricata from OISF PPA"

apt-get install -y -qq software-properties-common > /dev/null
add-apt-repository -y ppa:oisf/suricata-stable > /dev/null 2>&1
apt-get update -qq
apt-get install -y -qq suricata suricata-update jq curl > /dev/null
ok "Suricata installed: $(suricata --build-info | grep 'Version' | awk '{print $2}')"

# ─── Step 4: Configure Suricata ───────────────────────────────────────────────
step 4 "Configuring suricata.yaml"

YAML="/etc/suricata/suricata.yaml"

# Set monitored interface (af-packet section)
# Default value in suricata.yaml is 'eth0'
CURRENT_IFACE=$(grep -E '^\s+- interface:' "$YAML" | head -1 | awk '{print $NF}')
if [[ -n "$CURRENT_IFACE" ]]; then
  sed -i "s/^  - interface: ${CURRENT_IFACE}/  - interface: ${IFACE}/" "$YAML"
  ok "af-packet interface set to: ${BOLD}$IFACE${NC}"
else
  # If the pattern is not found, append it
  warn "Could not auto-detect interface line in suricata.yaml — please set it manually"
  manual_note << 'EOF'
Open /etc/suricata/suricata.yaml and find the af-packet section:
  af-packet:
    - interface: eth0      ← change eth0 to your interface
EOF
fi

# Enable Community Flow ID (correlates with Elasticsearch/Kibana by 5-tuple hash)
if grep -q 'community-id: false' "$YAML"; then
  sed -i 's/community-id: false/community-id: true/' "$YAML"
  ok "Community Flow ID enabled"
elif grep -q 'community-id: true' "$YAML"; then
  ok "Community Flow ID already enabled"
else
  warn "community-id line not found in suricata.yaml — please enable it manually"
  manual_note << 'EOF'
In /etc/suricata/suricata.yaml, find the eve-log output section and add:
      community-id: true
EOF
fi

divider

# ─── Step 5: Update rulesets ──────────────────────────────────────────────────
step 5 "Downloading Emerging Threats Open ruleset"

suricata-update > /dev/null 2>&1
ok "Ruleset updated ($(ls /var/lib/suricata/rules/*.rules 2>/dev/null | wc -l) rule files)"
info "Schedule daily updates: sudo suricata-update (add to cron for production)"

divider

# ─── Step 6: Validate and start Suricata ──────────────────────────────────────
step 6 "Validating configuration and starting Suricata"

echo ""
info "Running configuration test..."
if suricata -T -c "$YAML" -v > /tmp/suricata_test.log 2>&1; then
  ok "Configuration test passed"
else
  echo -e "  ${RED}Configuration test failed. Log output:${NC}"
  tail -20 /tmp/suricata_test.log
  err "Fix the configuration error above before continuing."
fi

systemctl enable suricata > /dev/null 2>&1
systemctl restart suricata
sleep 3

if systemctl is-active --quiet suricata; then
  ok "Suricata is running"
else
  err "Suricata failed to start. Check: sudo journalctl -u suricata -n 50"
fi

divider

# ─── Step 7: Install Filebeat ─────────────────────────────────────────────────
step 7 "Installing Filebeat"

# Add Elastic APT repository (same one used on ELK server)
if [[ ! -f /etc/apt/sources.list.d/elastic-7.x.list ]]; then
  curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    | gpg --dearmor -o /usr/share/keyrings/elastic-archive-keyring.gpg 2>/dev/null
  echo "deb [signed-by=/usr/share/keyrings/elastic-archive-keyring.gpg] \
    https://artifacts.elastic.co/packages/7.x/apt stable main" \
    | tee /etc/apt/sources.list.d/elastic-7.x.list > /dev/null
  apt-get update -qq
fi

apt-get install -y -qq filebeat > /dev/null
ok "Filebeat installed: $(filebeat version | awk '{print $3}')"

divider

# ─── Step 8: Configure Filebeat ───────────────────────────────────────────────
step 8 "Configuring Filebeat for Suricata"

# Write minimal filebeat.yml
cat > /etc/filebeat/filebeat.yml << EOF
# Filebeat configuration — generated by setup-suricata.sh
filebeat.inputs: []

filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: false

setup.kibana:
  host: "http://${ELK_IP}:5601"

output.elasticsearch:
  hosts: ["http://${ELK_IP}:9200"]
  username: "elastic"
  password: "${ELASTIC_PASS}"
EOF

ok "filebeat.yml written (pointing to $ELK_IP)"

# Enable and configure Suricata module
filebeat modules enable suricata > /dev/null 2>&1
ok "Suricata module enabled"

# Configure EVE log path in suricata module
SURICATA_MODULE="/etc/filebeat/modules.d/suricata.yml"
if [[ -f "$SURICATA_MODULE" ]]; then
  # Ensure the eve log path is set to Ubuntu default
  if grep -q 'var.paths' "$SURICATA_MODULE"; then
    sed -i 's|#.*var.paths.*|    var.paths: ["/var/log/suricata/eve.json"]|' "$SURICATA_MODULE"
  fi
  ok "Suricata module configured (eve.json path: /var/log/suricata/eve.json)"
fi

# Load Kibana dashboards and Elasticsearch index templates
info "Running 'filebeat setup' — loading dashboards and index templates..."
info "This may take 60–90 seconds..."
if filebeat setup -e > /tmp/filebeat_setup.log 2>&1; then
  ok "Filebeat setup completed (dashboards and index templates loaded)"
else
  warn "Filebeat setup reported issues. Manual check may be needed."
  manual_note << 'EOF'
Run this manually to load dashboards after confirming ELK is accessible:
  sudo filebeat setup -e
Check /tmp/filebeat_setup.log for the full error output.
EOF
fi

systemctl enable filebeat > /dev/null 2>&1
systemctl restart filebeat
sleep 2

if systemctl is-active --quiet filebeat; then
  ok "Filebeat is running"
else
  warn "Filebeat failed to start. Check: sudo journalctl -u filebeat -n 50"
fi

divider

# ─── Step 9: Verify detection ─────────────────────────────────────────────────
step 9 "Verifying Suricata detection"

info "Triggering test alert (SID 2100498 — GPL ATTACK_RESPONSE id check returned root)..."
sleep 1
curl -s http://testmynids.org/uid/index.html > /dev/null 2>&1 || true
sleep 2

if grep -q "2100498" /var/log/suricata/fast.log 2>/dev/null; then
  ok "${GREEN}${BOLD}Test alert detected successfully!${NC}"
  info "Alert in fast.log: $(grep '2100498' /var/log/suricata/fast.log | tail -1)"
else
  warn "Test alert not found in fast.log yet (may take a few seconds)"
  info "Verify manually: grep 2100498 /var/log/suricata/fast.log"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║                   Setup Complete                         ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Services running:${NC}"
echo -e "    ${GREEN}✔${NC}  suricata.service   — monitoring interface: ${BOLD}$IFACE${NC}"
echo -e "    ${GREEN}✔${NC}  filebeat.service   — shipping logs to:     ${BOLD}$ELK_IP:9200${NC}"
echo ""
echo -e "  ${BOLD}Key files:${NC}"
echo -e "    ${DIM}/etc/suricata/suricata.yaml${NC}     — Suricata configuration"
echo -e "    ${DIM}/var/log/suricata/eve.json${NC}       — EVE JSON alert log (read by Filebeat)"
echo -e "    ${DIM}/var/log/suricata/fast.log${NC}       — Human-readable alert log"
echo -e "    ${DIM}/etc/filebeat/filebeat.yml${NC}        — Filebeat configuration"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    1. Open Kibana at ${CYAN}http://$ELK_IP:5601${NC} and log in as 'elastic'"
echo -e "    2. Go to ${BOLD}Security → Detections → Rules${NC} to create detection rules"
echo -e "    3. Read Part 3 to enable ${BOLD}IPS mode${NC} (active traffic blocking)"
echo ""
echo -e "  ${YELLOW}Note:${NC} IPS mode (Part 3) requires additional NFQUEUE configuration"
echo -e "  and must be planned carefully to avoid locking yourself out via SSH."
echo -e "  See: ${CYAN}docs/en/03-configure-ips.md${NC}"
echo ""
