#!/bin/bash

# ┌───────────────────────────────────────────────┐
# │ Discord-VPN-DDoS-Attack-Alerts v3.0 by GunGameOG │
# └───────────────────────────────────────────────┘

# CONFIGURATION
INTERFACE="eth0"
DUMPDIR="/root/dumps"
WEBHOOK_URL="--WEBHOOK HERE--" # <-- Replace with your webhook
PACKET_THRESHOLD=100000    # PPS threshold for detection
DELAY_AFTER_ATTACK=120     # Time to sleep before stopping dump
PACKET_COUNT=1500          # Packets to capture per dump
LOG_PREFIX="[Net Protect Monitor]"

# Ensure dump directory exists
mkdir -p "$DUMPDIR"

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_PROVIDER=$(curl ipinfo.io/org | awk '{print $2,$3}')  # Replace or make dynamic if needed

# Function to get the top protocol from tcpdump output
get_top_protocol() {
  tshark -r "$1" -T fields -e _ws.col.Protocol 2>/dev/null \
    | sort | uniq -c | sort -nr | head -1 | awk '{print $2}'
}

# Functions
send_discord_alert() {
  local title="$1"
  local color="$2"
  local description="$3"
  local pps="$4"
  local mbps="$5"
  local protocol="$6"
  local image_url="$7"
  local footer_text="$8"

  curl -s -H "Content-Type: application/json" -X POST -d "{
    \"embeds\": [{
      \"title\": \"$title\",
      \"description\": \"$description\",
      \"color\": $color,
      \"fields\": [
        { \"name\": \"**Server Provider**\", \"value\": \"$SERVER_PROVIDER\", \"inline\": false },
        { \"name\": \"**IP Address**\", \"value\": \"$SERVER_IP\", \"inline\": false },
        { \"name\": \"**Protocol**\", \"value\": \"$protocol\", \"inline\": false },
        { \"name\": \"**Packets**\", \"value\": \"$pps PPS / $mbps Mbps\", \"inline\": false }
      ],
      \"thumbnail\": { \"url\": \"$image_url\" },
      \"footer\": {
        \"text\": \"$footer_text\",
        \"icon_url\": \"https://cdn.countryflags.com/thumbs/united-states-of-america/flag-800.png\"
      }
    }]
  }" "$WEBHOOK_URL" > /dev/null
}

echo -e "\e[97mDiscord-VPN-DDoS-Attack-Alerts \e[96mv2.0\e[0m"
echo -e "\e[93mNeed help? Contact GunGameOG#9082 on Discord.\e[0m"
echo

while true; do
  OLD_B=$(grep "$INTERFACE:" /proc/net/dev | awk '{print $2}')
  OLD_PS=$(grep "$INTERFACE:" /proc/net/dev | awk '{print $3}')
  sleep 1
  NEW_B=$(grep "$INTERFACE:" /proc/net/dev | awk '{print $2}')
  NEW_PS=$(grep "$INTERFACE:" /proc/net/dev | awk '{print $3}')

  PPS=$((NEW_PS - OLD_PS))
  BYTE_DIFF=$((NEW_B - OLD_B))

  KBPS=$((BYTE_DIFF / 1024))
  MBPS=$((BYTE_DIFF / 1024 / 1024))
  GBPS=$((BYTE_DIFF / 1024 / 1024 / 1024))

  echo -ne "\r\e[97mPackets/s: \e[96m$PPS \e[97m| MB/s: \e[96m$MBPS \e[97m| KB/s: \e[96m$KBPS\033[0K"

  if [[ $PPS -gt $PACKET_THRESHOLD ]]; then
    echo -e "\n$LOG_PREFIX Attack detected! Starting packet capture..."

    DUMP_FILE="$DUMPDIR/capture_$(date +"%Y%m%d-%H%M%S").pcap"
    tcpdump -nn -c "$PACKET_COUNT" -i "$INTERFACE" > /tmp/proto.log &
    TCPDUMP_PID=$!
    tcpdump -n -s0 -c "$PACKET_COUNT" -w "$DUMP_FILE" >/dev/null 2>&1 &


sleep 2  # Give tcpdump a second to write logs
PROTOCOL=$(get_top_protocol "$DUMP_FILE")



send_discord_alert \
      "🚨 DDoS Attack Detected" \
      15158332 \
      "High volume of incoming traffic detected. Automated mitigation initiated." \
      "$PPS" "$MBPS" "$PROTOCOL" \
      "https://imgur.com/yy4CBAr.png" \
      "Our system is attempting to mitigate the attack and automatic packet dumping has been activated."

    sleep "$DELAY_AFTER_ATTACK"

    echo "$LOG_PREFIX Attack ended. Stopping packet capture."
    kill -HUP "$TCPDUMP_PID" 2>/dev/null

    send_discord_alert \
      "✅ DDoS Attack Stopped" \
      3066993 \
      "Traffic levels have normalized. Mitigation complete." \
      "$PPS" "$MBPS" "$PROTOCOL" \
      "https://imgur.com/hfH0ca8.png" \
      "Our system has mitigated the attack and automatic packet dumping has been deactivated."

    echo "$LOG_PREFIX Monitoring resumed..."
  fi
done
