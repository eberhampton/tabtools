#!/bin/bash
# status-collector.sh — Collects system, security, service, and traffic data
# Writes JSON to /var/www/tabtools.dev/site/ops/d3x/data.json
# Run via cron every 5 minutes

OUTPUT_DIR="/var/www/tabtools.dev/site/ops/d3x"
OUTPUT_FILE="$OUTPUT_DIR/data.json"
GOATCOUNTER_KEY=$(cat /home/eber/.goatcounter-key 2>/dev/null)
GOATCOUNTER_SITE="tabtools"

mkdir -p "$OUTPUT_DIR"

# ── Timestamp ──
collected_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
local_time=$(date +"%Y-%m-%d %H:%M:%S %Z")

# ── System ──
uptime_seconds=$(cat /proc/uptime | awk '{print int($1)}')
uptime_days=$((uptime_seconds / 86400))
uptime_hours=$(( (uptime_seconds % 86400) / 3600 ))
uptime_pretty="${uptime_days}d ${uptime_hours}h"

load_1=$(cat /proc/loadavg | awk '{print $1}')
load_5=$(cat /proc/loadavg | awk '{print $2}')
load_15=$(cat /proc/loadavg | awk '{print $3}')

mem_total=$(free -m | awk '/^Mem:/{print $2}')
mem_used=$(free -m | awk '/^Mem:/{print $3}')
mem_percent=$((mem_used * 100 / mem_total))

disk_total=$(df -h / | awk 'NR==2{print $2}')
disk_used=$(df -h / | awk 'NR==2{print $3}')
disk_percent=$(df / | awk 'NR==2{print $5}' | tr -d '%')

# ── Services ──
nginx_active=$(systemctl is-active nginx 2>/dev/null)
webhook_active=$(systemctl is-active tabtools-webhook 2>/dev/null)

node_port=$(ss -tlnp | grep -c ":3100 " 2>/dev/null)
if [ "$node_port" -gt 0 ]; then
    node_status="listening"
else
    node_status="down"
fi

# ── SSL ──
ssl_expiry_raw=$(sudo certbot certificates 2>/dev/null | grep "Expiry Date:" | head -1 | sed 's/.*Expiry Date: //' | sed 's/ (.*//')
if [ -n "$ssl_expiry_raw" ]; then
    ssl_expiry_epoch=$(date -d "$ssl_expiry_raw" +%s 2>/dev/null)
    now_epoch=$(date +%s)
    ssl_days_left=$(( (ssl_expiry_epoch - now_epoch) / 86400 ))
    ssl_expiry="$ssl_expiry_raw"
else
    ssl_days_left=-1
    ssl_expiry="unknown"
fi

# ── Security: UFW ──
ufw_status=$(sudo ufw status | head -1 | awk '{print $2}')
ufw_ports=$(sudo ufw status | grep "ALLOW" | awk '{print $1}' | sort -u | tr '\n' ',' | sed 's/,$//')

# ── Security: Fail2ban ──
f2b_status=$(sudo fail2ban-client status sshd 2>/dev/null)
if [ $? -eq 0 ]; then
    f2b_running="true"
    f2b_current_banned=$(echo "$f2b_status" | grep "Currently banned:" | awk '{print $NF}')
    f2b_total_banned=$(echo "$f2b_status" | grep "Total banned:" | awk '{print $NF}')
    f2b_banned_ips=$(echo "$f2b_status" | grep "Banned IP list:" | sed 's/.*Banned IP list:\s*//')
    [ -z "$f2b_current_banned" ] && f2b_current_banned=0
    [ -z "$f2b_total_banned" ] && f2b_total_banned=0
else
    f2b_running="false"
    f2b_current_banned=0
    f2b_total_banned=0
    f2b_banned_ips=""
fi

# ── Security: SSH config ──
ssh_password=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
ssh_root=$(grep -E "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
[ -z "$ssh_password" ] && ssh_password="yes"
[ -z "$ssh_root" ] && ssh_root="yes"

# ── Security: Unattended upgrades ──
if dpkg -l | grep -q unattended-upgrades 2>/dev/null; then
    unattended="installed"
    if grep -q "1" /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; then
        unattended="active"
    fi
else
    unattended="not installed"
fi

# ── Security: nginx hardening ──
nginx_conf="/etc/nginx/sites-enabled/tabtools.dev"
nginx_tokens=$(grep -c "server_tokens off" "$nginx_conf" 2>/dev/null)
# fgrep avoids shell backslash escaping issues
nginx_hidden=$(fgrep -c 'location ~ /\.' "$nginx_conf" 2>/dev/null)

# ── Backup & healthcheck timestamps ──
last_backup="never"
if [ -f /home/eber/backup.log ]; then
    last_backup_time=$(stat -c %Y /home/eber/backup.log 2>/dev/null)
    if [ -n "$last_backup_time" ]; then
        last_backup=$(date -d @"$last_backup_time" +"%Y-%m-%d %H:%M:%S")
    fi
fi

last_healthcheck="never"
for logfile in /home/eber/healthcheck.log /home/eber/healthcheck-results.log; do
    if [ -f "$logfile" ]; then
        hc_time=$(stat -c %Y "$logfile" 2>/dev/null)
        if [ -n "$hc_time" ]; then
            last_healthcheck=$(date -d @"$hc_time" +"%Y-%m-%d %H:%M:%S")
            break
        fi
    fi
done
if [ "$last_healthcheck" = "never" ] && [ -f /home/eber/healthcheck.sh ]; then
    last_healthcheck="no log found"
fi

# ── GoatCounter traffic ──
gc_total_views=0
gc_today_views=0
gc_daily_json="[]"
gc_paths_json="[]"

if [ -n "$GOATCOUNTER_KEY" ]; then
    # /api/v0/stats/total returns:
    #   { "total": N, "total_utc": N, "stats": [{"day":"YYYY-MM-DD","daily":N,"hourly":[...]}, ...] }
    gc_raw=$(curl -s --max-time 10 \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $GOATCOUNTER_KEY" \
        "https://${GOATCOUNTER_SITE}.goatcounter.com/api/v0/stats/total" 2>/dev/null)

    if echo "$gc_raw" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        gc_parsed=$(echo "$gc_raw" | python3 -c "
import sys, json
data = json.load(sys.stdin)
total = data.get('total', 0)
stats = data.get('stats', [])
today = stats[-1]['daily'] if stats else 0
daily = [{'day': s['day'], 'views': s.get('daily', 0)} for s in stats]
print(json.dumps({'total': total, 'today': today, 'daily': daily}))
" 2>/dev/null)

        if [ -n "$gc_parsed" ]; then
            gc_total_views=$(echo "$gc_parsed" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])" 2>/dev/null)
            gc_today_views=$(echo "$gc_parsed" | python3 -c "import sys,json; print(json.load(sys.stdin)['today'])" 2>/dev/null)
            gc_daily_json=$(echo "$gc_parsed" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['daily']))" 2>/dev/null)
        fi
    fi

    [ -z "$gc_total_views" ] && gc_total_views=0
    [ -z "$gc_today_views" ] && gc_today_views=0
    [ -z "$gc_daily_json" ] && gc_daily_json="[]"

    # /api/v0/paths returns list of tracked paths (no per-page counts)
    gc_paths_raw=$(curl -s --max-time 10 \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $GOATCOUNTER_KEY" \
        "https://${GOATCOUNTER_SITE}.goatcounter.com/api/v0/paths" 2>/dev/null)

    if echo "$gc_paths_raw" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        gc_paths_json=$(echo "$gc_paths_raw" | python3 -c "
import sys, json
data = json.load(sys.stdin)
paths = data.get('paths', [])
result = [{'path': p.get('path',''), 'title': p.get('title','')} for p in paths]
print(json.dumps(result))
" 2>/dev/null)
        [ -z "$gc_paths_json" ] && gc_paths_json="[]"
    fi
fi

# ── Recent auth failures (last 24h) ──
auth_failures=0
if [ -f /var/log/auth.log ]; then
    auth_failures=$(grep "Failed password\|authentication failure" /var/log/auth.log 2>/dev/null | \
        awk -v cutoff="$(date -d '24 hours ago' '+%b %e %H:%M')" '$0 >= cutoff' | wc -l 2>/dev/null)
    [ -z "$auth_failures" ] && auth_failures=0
fi

# ── Write JSON ──
cat > "$OUTPUT_FILE" << ENDJSON
{
  "collected_at": "$collected_at",
  "local_time": "$local_time",
  "system": {
    "uptime": "$uptime_pretty",
    "uptime_seconds": $uptime_seconds,
    "load": ["$load_1", "$load_5", "$load_15"],
    "memory": {
      "total_mb": $mem_total,
      "used_mb": $mem_used,
      "percent": $mem_percent
    },
    "disk": {
      "total": "$disk_total",
      "used": "$disk_used",
      "percent": $disk_percent
    }
  },
  "services": {
    "nginx": "$nginx_active",
    "webhook": "$webhook_active",
    "node_port_3100": "$node_status"
  },
  "ssl": {
    "expiry": "$ssl_expiry",
    "days_left": $ssl_days_left
  },
  "security": {
    "ufw": {
      "status": "$ufw_status",
      "open_ports": "$ufw_ports"
    },
    "fail2ban": {
      "running": $f2b_running,
      "current_banned": $f2b_current_banned,
      "total_banned": $f2b_total_banned,
      "banned_ips": "$f2b_banned_ips"
    },
    "ssh": {
      "password_auth": "$ssh_password",
      "root_login": "$ssh_root"
    },
    "unattended_upgrades": "$unattended",
    "nginx_hardening": {
      "server_tokens_off": $([ "$nginx_tokens" -gt 0 ] && echo "true" || echo "false"),
      "hidden_files_blocked": $([ "$nginx_hidden" -gt 0 ] && echo "true" || echo "false")
    },
    "auth_failures_24h": $auth_failures
  },
  "backups": {
    "last_backup": "$last_backup",
    "last_healthcheck": "$last_healthcheck"
  },
  "traffic": {
    "total_views": $gc_total_views,
    "today_views": $gc_today_views,
    "daily": $gc_daily_json,
    "tracked_paths": $gc_paths_json
  }
}
ENDJSON

echo "[$(date)] Status data collected → $OUTPUT_FILE"
