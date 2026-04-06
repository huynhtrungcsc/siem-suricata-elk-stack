#!/usr/bin/env bash
# =============================================================================
#  setup-elk.sh — Elasticsearch + Kibana Setup
#  Repository: https://github.com/huynhtrungcsc/siem-suricata-elk-stack
#
#  RUN THIS SCRIPT ON: Elasticsearch Server (NOT on the Suricata server)
#
#  What this script does:
#    1. Installs Elasticsearch 7.x with xpack security enabled
#    2. Generates and displays all built-in user passwords (save them)
#    3. Installs and configures Kibana, sets credentials via keystore
#    4. Configures UFW firewall rules
#    5. Enables and starts both services
#
#  Prerequisites:
#    - Ubuntu 20.04 LTS
#    - Non-root user with sudo privileges
#    - Minimum 4 GB RAM (8 GB recommended)
#    - Run BEFORE setup-suricata.sh (Filebeat needs the 'elastic' password)
#
#  Usage:
#    chmod +x setup-elk.sh
#    sudo ./setup-elk.sh
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

TOTAL_STEPS=8

# ── Helpers ───────────────────────────────────────────────────────────────────
banner() {
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║       Elasticsearch + Kibana Setup Script                ║"
  echo "  ║     SIEM with Suricata and Elastic Stack — Part 4        ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${DIM}Run this script on the ${BOLD}Elasticsearch Server${NC}${DIM}, not the Suricata server.${NC}"
  echo ""
  echo -e "  ${YELLOW}Important:${NC} This script will display generated passwords."
  echo -e "  ${BOLD}You must save them before the script finishes.${NC}"
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

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    err "This script must be run as root. Use: sudo ./setup-elk.sh"
  fi
}

check_ram() {
  local ram_kb
  ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local ram_gb=$(( ram_kb / 1024 / 1024 ))
  if [[ "$ram_gb" -lt 3 ]]; then
    echo -e "  ${RED}✖  Warning: Only ${ram_gb} GB RAM detected.${NC}"
    echo -e "      Elasticsearch requires a minimum of 4 GB RAM."
    echo -e "      Continuing, but the service may fail to start."
    sleep 3
  else
    ok "RAM: ${ram_gb} GB detected (minimum: 4 GB)"
  fi
}

wait_for_elasticsearch() {
  local max_wait=90
  local waited=0
  info "Waiting for Elasticsearch to become available..."
  printf "    "
  until curl -s http://localhost:9200 > /dev/null 2>&1; do
    if [[ "$waited" -ge "$max_wait" ]]; then
      echo ""
      err "Elasticsearch did not start within ${max_wait}s. Check: sudo journalctl -u elasticsearch -n 50"
    fi
    printf "."
    sleep 2
    (( waited += 2 ))
  done
  echo ""
  ok "Elasticsearch is available (started in ~${waited}s)"
}

# ── Main ──────────────────────────────────────────────────────────────────────
banner
check_root
check_ram

# ─── Step 1: System dependencies ──────────────────────────────────────────────
step 1 "Installing system dependencies"

apt-get update -qq
apt-get install -y -qq apt-transport-https curl gnupg2 ufw jq > /dev/null
ok "Dependencies installed"

divider

# ─── Step 2: Install Elasticsearch ───────────────────────────────────────────
step 2 "Installing Elasticsearch 7.x"

if [[ ! -f /etc/apt/sources.list.d/elastic-7.x.list ]]; then
  curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    | gpg --dearmor -o /usr/share/keyrings/elastic-archive-keyring.gpg 2>/dev/null
  echo "deb [signed-by=/usr/share/keyrings/elastic-archive-keyring.gpg] \
    https://artifacts.elastic.co/packages/7.x/apt stable main" \
    | tee /etc/apt/sources.list.d/elastic-7.x.list > /dev/null
  apt-get update -qq
  ok "Elastic APT repository added"
else
  ok "Elastic APT repository already configured"
fi

apt-get install -y -qq elasticsearch > /dev/null
ok "Elasticsearch installed: $(dpkg -l elasticsearch | tail -1 | awk '{print $3}')"

divider

# ─── Step 3: Configure Elasticsearch ──────────────────────────────────────────
step 3 "Configuring Elasticsearch"

ES_CONF="/etc/elasticsearch/elasticsearch.yml"

# Enable xpack security and bind to localhost
# (Filebeat connects via private network using the node's IP, but we bind
#  Elasticsearch to localhost and let the firewall handle external access)
if ! grep -q 'xpack.security.enabled' "$ES_CONF"; then
  cat >> "$ES_CONF" << 'EOF'

# --- Added by setup-elk.sh ---
network.host: localhost
xpack.security.enabled: true
EOF
  ok "xpack.security.enabled: true"
  ok "network.host: localhost"
else
  ok "Elasticsearch already configured"
fi

systemctl daemon-reload > /dev/null
systemctl enable elasticsearch > /dev/null 2>&1
systemctl start elasticsearch
ok "Elasticsearch service started"

wait_for_elasticsearch
divider

# ─── Step 4: Generate built-in user passwords ─────────────────────────────────
step 4 "Generating built-in user passwords (xpack security)"

PASS_FILE="/tmp/elastic_passwords_$(date +%Y%m%d_%H%M%S).txt"

info "Running elasticsearch-setup-passwords auto..."
/usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto -b 2>&1 \
  | tee "$PASS_FILE"

# Extract passwords we need
ELASTIC_PASS=$(grep "PASSWORD elastic " "$PASS_FILE" | awk '{print $NF}')
KIBANA_SYSTEM_PASS=$(grep "PASSWORD kibana_system " "$PASS_FILE" | awk '{print $NF}')

if [[ -z "$ELASTIC_PASS" ]] || [[ -z "$KIBANA_SYSTEM_PASS" ]]; then
  err "Could not extract passwords from output. Check $PASS_FILE manually."
fi

echo ""
echo -e "  ${YELLOW}┌─ SAVE THESE PASSWORDS ────────────────────────────────────┐${NC}"
echo -e "  ${YELLOW}│${NC}"
echo -e "  ${YELLOW}│${NC}  ${BOLD}elastic${NC}         →  ${GREEN}${BOLD}$ELASTIC_PASS${NC}"
echo -e "  ${YELLOW}│${NC}  ${BOLD}kibana_system${NC}   →  ${GREEN}${BOLD}$KIBANA_SYSTEM_PASS${NC}"
echo -e "  ${YELLOW}│${NC}"
echo -e "  ${YELLOW}│${NC}  Full password list saved to:"
echo -e "  ${YELLOW}│${NC}  ${DIM}$PASS_FILE${NC}"
echo -e "  ${YELLOW}│${NC}"
echo -e "  ${YELLOW}│${NC}  You will need the ${BOLD}elastic${NC} password when running"
echo -e "  ${YELLOW}│${NC}  setup-suricata.sh on the Suricata server."
echo -e "  ${YELLOW}└───────────────────────────────────────────────────────────┘${NC}"
echo ""

divider

# ─── Step 5: Install Kibana ───────────────────────────────────────────────────
step 5 "Installing Kibana"

apt-get install -y -qq kibana > /dev/null
ok "Kibana installed: $(dpkg -l kibana | tail -1 | awk '{print $3}')"

divider

# ─── Step 6: Configure Kibana ─────────────────────────────────────────────────
step 6 "Configuring Kibana"

KIBANA_CONF="/etc/kibana/kibana.yml"

# Bind Kibana to all interfaces so it can be accessed from outside
if ! grep -q '^server.host' "$KIBANA_CONF"; then
  cat >> "$KIBANA_CONF" << 'EOF'

# --- Added by setup-elk.sh ---
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://localhost:9200"]
elasticsearch.username: "kibana_system"
EOF
  ok "server.host: 0.0.0.0"
  ok "elasticsearch.hosts: localhost:9200"
  ok "elasticsearch.username: kibana_system"
else
  ok "Kibana already configured"
fi

# Store kibana_system password in Kibana keystore (avoids plaintext in yml)
info "Adding kibana_system password to Kibana keystore..."

# Create keystore if it does not exist yet
if ! /usr/share/kibana/bin/kibana-keystore list > /dev/null 2>&1; then
  /usr/share/kibana/bin/kibana-keystore create > /dev/null 2>&1
fi

echo "$KIBANA_SYSTEM_PASS" \
  | /usr/share/kibana/bin/kibana-keystore add elasticsearch.password --stdin > /dev/null 2>&1

ok "Kibana keystore: elasticsearch.password stored (not in plaintext)"

systemctl daemon-reload > /dev/null
systemctl enable kibana > /dev/null 2>&1
systemctl start kibana
ok "Kibana service started"

divider

# ─── Step 7: Configure UFW firewall ───────────────────────────────────────────
step 7 "Configuring firewall (UFW)"

# Ensure UFW is enabled
if ! ufw status | grep -q "Status: active"; then
  ufw --force enable > /dev/null 2>&1
fi

# Allow SSH (critical — must not be blocked)
ufw allow OpenSSH > /dev/null 2>&1
ok "SSH (OpenSSH) — allowed"

# Allow Kibana web UI from anywhere (restrict to specific IPs in production)
ufw allow 5601/tcp > /dev/null 2>&1
ok "Kibana port 5601 — allowed"

# Elasticsearch port 9200 is NOT opened to the internet on purpose.
# Filebeat connects over the private network; Kibana connects via localhost.
ok "Elasticsearch port 9200 — NOT exposed (localhost only — correct for security)"

divider

# ─── Step 8: Verify services ──────────────────────────────────────────────────
step 8 "Verifying services"

# Wait for Kibana to become available (it takes longer than Elasticsearch)
info "Waiting for Kibana to become available (this can take up to 90 seconds)..."
max_wait=90
waited=0
printf "    "
until curl -s http://localhost:5601/api/status > /dev/null 2>&1; do
  if [[ "$waited" -ge "$max_wait" ]]; then
    echo ""
    warn "Kibana did not respond within ${max_wait}s — it may still be starting."
    warn "Check: sudo journalctl -u kibana -n 50"
    break
  fi
  printf "."
  sleep 3
  (( waited += 3 ))
done
echo ""

# Final service status check
ES_STATUS=$(systemctl is-active elasticsearch 2>/dev/null || echo "inactive")
KB_STATUS=$(systemctl is-active kibana 2>/dev/null || echo "inactive")

[[ "$ES_STATUS" == "active" ]] && ok "elasticsearch.service — running" \
  || warn "elasticsearch.service — $ES_STATUS (check journalctl -u elasticsearch)"

[[ "$KB_STATUS" == "active" ]] && ok "kibana.service — running" \
  || warn "kibana.service — $KB_STATUS (check journalctl -u kibana)"

# Test Elasticsearch API with authentication
ES_HEALTH=$(curl -s -u "elastic:${ELASTIC_PASS}" \
  "http://localhost:9200/_cluster/health" 2>/dev/null \
  | jq -r '.status' 2>/dev/null || echo "unknown")

[[ "$ES_HEALTH" == "green" || "$ES_HEALTH" == "yellow" ]] \
  && ok "Elasticsearch cluster health: ${BOLD}$ES_HEALTH${NC}" \
  || warn "Elasticsearch cluster health: $ES_HEALTH (a single-node cluster is always yellow — this is normal)"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║                   Setup Complete                         ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

ELK_IP=$(hostname -I | awk '{print $1}')

echo -e "  ${BOLD}Services running on this server (${ELK_IP}):${NC}"
echo -e "    ${GREEN}✔${NC}  elasticsearch.service  — http://localhost:9200"
echo -e "    ${GREEN}✔${NC}  kibana.service         — http://${ELK_IP}:5601"
echo ""
echo -e "  ${BOLD}Passwords saved to:${NC}"
echo -e "    ${DIM}$PASS_FILE${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    1. Open Kibana:   ${CYAN}http://${ELK_IP}:5601${NC}"
echo -e "       Login:         username ${BOLD}elastic${NC}, password from above"
echo ""
echo -e "    2. On the ${BOLD}Suricata server${NC}, run:"
echo -e "       ${CYAN}sudo ./setup-suricata.sh${NC}"
echo -e "       You will be asked for the ${BOLD}elastic${NC} password and this server's IP."
echo ""
echo -e "    3. Note the ${BOLD}private IP${NC} of this server to provide to setup-suricata.sh:"
echo -e "       ${CYAN}ip -br addr show${NC}"
echo ""
echo -e "  ${YELLOW}Security note:${NC} In production, restrict port 5601 to specific"
echo -e "  IPs: ${DIM}ufw allow from <your-ip> to any port 5601${NC}"
echo ""
