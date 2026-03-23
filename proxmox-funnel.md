Um Tailscale Funnel für Proxmox pve einzurichten folgenden befehl kopiren und einfügen:
```
# 1) Setze DNAT Regel falls noch nicht vorhanden
iptables -t nat -C OUTPUT -d 127.0.0.1 -p tcp --dport 8006 -j DNAT --to-destination 100.75.203.51:8006 2>/dev/null || \
iptables -t nat -A OUTPUT -d 127.0.0.1 -p tcp --dport 8006 -j DNAT --to-destination 100.75.203.51:8006

# 2) Stelle sicher, dass /etc/iptables existiert und speichere Regeln
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# 3) Falls netfilter-persistent installiert ist, speichere und aktiviere es
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save || true
else
  apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y netfilter-persistent iptables-persistent || true
  netfilter-persistent save || true
fi

# 4) Erstelle systemd Unit für TCP Funnel (Tailscale) und starte sie
cat >/etc/systemd/system/tailscale-funnel-tcp.service <<'UNIT'
[Unit]
Description=Tailscale Funnel TCP for Proxmox
After=tailscaled.service
Requires=tailscaled.service

[Service]
Type=simple
ExecStart=/usr/bin/tailscale funnel --bg --tcp=443 tcp://127.0.0.1:8006
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now tailscale-funnel-tcp.service || true

# 5) Optional sofortiges Ausführen des Wartungs‑Scripts falls vorhanden
[ -x /usr/local/bin/proxmox-funnel-maint.sh ] && /usr/local/bin/proxmox-funnel-maint.sh || true

# 6) Kurze Statusausgabe
echo "---- quick status ----"
ss -tulpn | grep :8006 || true
iptables -t nat -L OUTPUT --line-numbers
systemctl status tailscale-funnel-tcp.service --no-pager || true
tailscale funnel status 2>/dev/null || true
