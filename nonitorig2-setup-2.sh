#!/usr/bin/env bash
set -euo pipefail

# =========================
# Konfiguration
# =========================

# Kiosk-Benutzer (wird angelegt, falls nicht vorhanden)
KIOSK_USER="dash"

# Haupt-Dashboard (PRTG)
PRTG_DASHBOARD_URL="https://monitoring.tcsoc.net/public/mapshow.htm?ids=15901:4C3A7306-367D-40E8-8CD6-A9EC9936D655,16089:577EA9F7-7D38-45C5-A52B-159D3800C66C,14848:6AD7B66E-A56E-4694-8296-D0A24FAC3AED"

# Zweites Dashboard (anderes Monitoring-System, optional)
# Beispiel:
# MY_DASHBOARD_URL="https://anderes-monitoring.example.net/dashboard?id=123"
MY_DASHBOARD_URL=""

# Anzeigezeiten in Sekunden pro Dashboard
PRTG_DASHBOARD_URL_S=60   # Dauer Dashboard 1
MY_DASHBOARD_URL_S=60     # Dauer Dashboard 2 (nur relevant, wenn MY_DASHBOARD_URL != "")

# Pfad für Root-CA
CA_CERT_PATH="/usr/local/share/ca-certificates/tanum_root_CA.crt"

# Bildschirmzeiten (Mo-Fr)
SCREEN_ON="08:00"
SCREEN_OFF="19:00"

# =========================
# Hilfsfunktionen
# =========================

is_positive_int() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

# =========================
# Root-Check & Validierung
# =========================

if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root ausführen (z.B. mit: sudo bash setup.sh)" >&2
  exit 1
fi

if [[ -z "${PRTG_DASHBOARD_URL}" ]]; then
  echo "PRTG_DASHBOARD_URL ist leer, bitte im Skript setzen." >&2
  exit 1
fi

if ! is_positive_int "${PRTG_DASHBOARD_URL_S}"; then
  echo "PRTG_DASHBOARD_URL_S muss eine positive ganze Zahl (Sekunden) sein." >&2
  exit 1
fi

if [[ -n "${MY_DASHBOARD_URL}" ]] && ! is_positive_int "${MY_DASHBOARD_URL_S}"; then
  echo "MY_DASHBOARD_URL_S muss eine positive ganze Zahl (Sekunden) sein." >&2
  exit 1
fi

# =========================
# Root-CA ins System einspielen
# =========================

tee "${CA_CERT_PATH}" >/dev/null <<'EOF'
-----BEGIN CERTIFICATE-----
MIIFUDCCAzigAwIBAgIQW3mrZK3pPaWE8kW7g8my1jANBgkqhkiG9w0BAQsFADBC
MQswCQYDVQQGEwJERTEbMBkGA1UECgwSdGFudW0gY29uc3VsdCBHbWJIMRYwFAYD
VQQDDA10YW51bSByb290IENBMB4XDTI0MDQxNjEwMDIzM1oXDTQ5MDQxNzEwMDIz
M1owQjELMAkGA1UEBhMCREUxGzAZBgNVBAoMEnRhbnVtIGNvbnN1bHQgR21iSDEW
MBQGA1UEAwwNdGFudW0gcm9vdCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
AgoCggIBAM3eEKGLf67y7mnogYNQeANmPjh7P3CwFHM6OHkrnMh8zHdn/ENI/ZDH
HjxXSQSjBka4Tz+uK4WQrata7UTScsZDxFafi6qjwo4f59XVnaxD2Ieg6uzJTmng
fbkdb5uaGE0T7PNG4X6D632mQzZojhkCsbbeqQa0+vlJIbwsS9hmGngS9xEg5YVP
KPU36Bbjsq1TAKshf44MPaIhvMO0UUHxCmUbdsy0Gh3WonZMloxrNE3N0rHAVUW+
M6m2HaYvmWYrMLtKtEAWOjvZn1G5X1hZ4+CR5b+z8Y1RETgoR1UES/zqae9AZ8jM
yTEKEJUbvHsX0BF2XAo8/TaBCH80RRsD2v9tPeSRDHW0iIZnDSiS3bRudePe9UVm
nq2ddfcdIYOMq4PctyPb+AcEiAG00BfKdn87KqkqP8ZGzZtAsw+qj5jwKISVHt8g
Trf3kOWPQ8xUpX1VhcHwFgemqYd7C0v3zPTIVEOZj67k+rpUqMtlWzyfILUTB1Nv
A5kiRyRc0oy7VvypRtUSvjc6qoFFmHaZrqWUuwIXZcVlmV6mW0qeGTI2uhXNj2zY
9SVHWM/VEJ3ugRQA5BpgpEtUEXX6z4MnrVy/ZpbvwUbImRizO9tNjmrPw3qAaRjO
MkNLo/unLbRjMc3mIlIaySLCOl8MC0x9xUdU304MEJoP9219DLxZAgMBAAGjQjBA
MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgGGMB0GA1UdDgQWBBRAI6En
+aos0LRpujgeIQUEG37pdzANBgkqhkiG9w0BAQsFAAOCAgEAwuzvyV1r1ZP/p9df
TTo3GNTdoXpNHutEmzu4Hm/5NSSC/cb+dLpwtuFJd7JDuVnrnd2BLaDBhSfVpcH9
rYrFD9c3U4UX5vJx7K8d2qA/mRD+Rqfj3KbTyLGG0GMdNfaGFEq9flhb05tBXo7G
HSFh8VEWL93LpHyG6MTk5y7MnWBRY1bzf7OQFAjfePaJyD9+56JtNDzIueyauGzp
WouPw60E3W6WfprkJNv+7zrR6QReBBgzXe8PQiYzkPXG/FF6cDuJRPLExQNG1Ni3
loFVygxVAztr8/ENhUwrgo/HsNCp2kQGp3NaeP1Pp5RFfvxvF8sJdbYYIJe7C+VM
ZiiU9ZoT8x8te709jqWG2AYM9qv6qu4OcpmlxmdRONMnyJ/Ld8tryVQesW2zloiA
XaqjWX4wozC9ppmjDbvS93TVLW0rxfEamFfTe88UfyM48UtQf8/5Zjatdy2uCnhl
pnhNvFJDN9sV5+1uqnsgeR18T8DOqG6j/vRTlK5fy3b2nlKuFV79rK9tZVkmVz65
6VL/1R0gO0mmcoW5KO/uG/hPV51C2hpcHZcMxrtysYqP0e5YGIggrbEDJoKUzpAY
Llt2w0/ofBMr1dPIAiKApHx6G4zrTZ8B54S3gbuwW3gqLGMYqglGetV9rQ7ctRei
BzZgNRZTQ5ilbyZJ34tWCxfWynA=
-----END CERTIFICATE-----
EOF

chmod 644 "${CA_CERT_PATH}"
update-ca-certificates

# =========================
# Pakete installieren
# =========================

apt-get update
apt-get install -y libnss3-tools

# =========================
# Kiosk-User anlegen
# =========================

if ! id -u "${KIOSK_USER}" >/dev/null 2>&1; then
  echo "Kiosk-Benutzer ${KIOSK_USER} existiert nicht, wird erstellt..."
  adduser --disabled-password --gecos "" "${KIOSK_USER}"
else
  echo "Kiosk-Benutzer ${KIOSK_USER} existiert bereits."
fi

# Gruppenrechte für Kiosk-User
usermod -aG audio,video,input,gpio,render "${KIOSK_USER}" || true

# =========================
# CA in NSS-Store des Kiosk-Users
# =========================

mkdir -p "/home/${KIOSK_USER}/.pki/nssdb"
certutil -d "sql:/home/${KIOSK_USER}/.pki/nssdb" \
  -A -t "C,," -n "Tanum Root CA" \
  -i "${CA_CERT_PATH}"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "/home/${KIOSK_USER}/.pki"

# =========================
# Chromium installieren/finden
# =========================

CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium || true)"

if [[ -z "${CHROMIUM_BIN}" ]]; then
  echo "Chromium nicht gefunden, versuche Installation..."
  apt-get update
  INSTALL_OK=0
  for PKG in chromium chromium-browser; do
    if apt-get install -y "$PKG"; then
      INSTALL_OK=1
      break
    fi
  done
  if [[ "${INSTALL_OK}" -ne 1 ]]; then
    echo "Konnte Chromium nicht installieren." >&2
    exit 1
  fi
  CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium || true)"
  if [[ -z "${CHROMIUM_BIN}" ]]; then
    echo "Chromium nach Installation nicht gefunden." >&2
    exit 1
  fi
fi

# =========================
# Zusätzliche Tools
# =========================

apt-get update
apt-get install -y unclutter cec-utils || true

# =========================
# Dashboard-Rotation (bei 2 URLs)
# =========================

DASHBOARD_START_URL="${PRTG_DASHBOARD_URL}"

if [[ -n "${MY_DASHBOARD_URL}" ]]; then
  ROTATOR_HTML="/home/${KIOSK_USER}/prtg-rotator.html"
  cat > "${ROTATOR_HTML}" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Dashboard Rotator</title>
<style>
  html, body {
    margin: 0;
    padding: 0;
    height: 100%;
    overflow: hidden;
    background: #000;
  }
  iframe {
    border: 0;
    width: 100%;
    height: 100%;
  }
</style>
</head>
<body>
<iframe id="frame" src="${PRTG_DASHBOARD_URL}"></iframe>
<script>
  const urls = [
    "${PRTG_DASHBOARD_URL}",
    "${MY_DASHBOARD_URL}"
  ];
  const durations = [
    ${PRTG_DASHBOARD_URL_S} * 1000,
    ${MY_DASHBOARD_URL_S} * 1000
  ];

  let idx = 0;
  const frame = document.getElementById("frame");

  function rotate() {
    idx = (idx + 1) % urls.length;
    frame.src = urls[idx];
    setTimeout(rotate, durations[idx]);
  }

  // erster Wechsel nach Dauer des ersten Dashboards
  setTimeout(rotate, durations[0]);
</script>
</body>
</html>
EOF

  chown "${KIOSK_USER}:${KIOSK_USER}" "${ROTATOR_HTML}"
  DASHBOARD_START_URL="file:///home/${KIOSK_USER}/prtg-rotator.html"
fi

# =========================
# Autostart-Einträge für Kiosk-User
# =========================

AUTOSTART_DIR="/home/${KIOSK_USER}/.config/autostart"
mkdir -p "${AUTOSTART_DIR}"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "/home/${KIOSK_USER}/.config"

cat > "${AUTOSTART_DIR}/prtg-kiosk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=PRTG Monitoring Kiosk
Exec=${CHROMIUM_BIN} --kiosk --incognito --noerrdialogs --disable-translate --disable-infobars --check-for-update-interval=31536000 --password-store=basic --no-first-run --no-default-browser-check --ignore-certificate-errors --allow-insecure-localhost "${DASHBOARD_START_URL}"
X-GNOME-Autostart-enabled=true
EOF

cat > "${AUTOSTART_DIR}/unclutter.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Hide Mouse Cursor (unclutter)
Exec=/usr/bin/unclutter -idle 3 -root
X-GNOME-Autostart-enabled=true
EOF

chown "${KIOSK_USER}:${KIOSK_USER}" \
  "${AUTOSTART_DIR}/prtg-kiosk.desktop" \
  "${AUTOSTART_DIR}/unclutter.desktop"

# =========================
# Monitor-Power-Skript (CEC)
# =========================

cat > /usr/local/bin/monitor-power.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CMD="${1:-status}"
case "$CMD" in
  on)
    /usr/bin/cec-ctl --to 0 --image-view-on >/dev/null 2>&1 || true
    ;;
  off)
    /usr/bin/cec-ctl --to 0 --standby >/dev/null 2>&1 || true
    ;;
  status)
    /usr/bin/cec-ctl --to 0 --status 2>/dev/null || true
    ;;
  *)
    exit 1
    ;;
esac
EOF

chmod +x /usr/local/bin/monitor-power.sh

# Cronjob für Monitor EIN/AUS
ON_HOUR="${SCREEN_ON%:*}"
ON_MIN="${SCREEN_ON#*:}"
OFF_HOUR="${SCREEN_OFF%:*}"
OFF_MIN="${SCREEN_OFF#*:}"

cat > /etc/cron.d/tco-monitor-power <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
${ON_MIN} ${ON_HOUR} * * 1-5 root /usr/local/bin/monitor-power.sh on
${OFF_MIN} ${OFF_HOUR} * * 1-5 root /usr/local/bin/monitor-power.sh off
EOF

chmod 644 /etc/cron.d/tco-monitor-power

# =========================
# Kiosk-User aus sudo-Gruppe entfernen
# =========================

if getent group sudo | grep -qE "\b${KIOSK_USER}\b"; then
  deluser "${KIOSK_USER}" sudo || true
fi

# =========================
# LightDM Autologin konfigurieren (falls vorhanden)
# =========================

if [[ -f /etc/lightdm/lightdm.conf ]]; then
  if grep -q '^autologin-user=' /etc/lightdm/lightdm.conf; then
    sed -i "s/^autologin-user=.*/autologin-user=${KIOSK_USER}/" /etc/lightdm/lightdm.conf
  else
    sed -i "/^\[Seat:\*\]/a autologin-user=${KIOSK_USER}" /etc/lightdm/lightdm.conf || \
    sed -i "\$a autologin-user=${KIOSK_USER}" /etc/lightdm/lightdm.conf
  fi

  if grep -q '^autologin-user-timeout=' /etc/lightdm/lightdm.conf; then
    sed -i "s/^autologin-user-timeout=.*/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf
  else
    sed -i "/^autologin-user=${KIOSK_USER}/a autologin-user-timeout=0" /etc/lightdm/lightdm.conf || \
    sed -i "\$a autologin-user-timeout=0" /etc/lightdm/lightdm.conf
  fi
fi

# =========================
# Keyring des Kiosk-Users "stummschalten"
# =========================

KEYRING_DIR="/home/${KIOSK_USER}/.local/share/keyrings"
rm -f "${KEYRING_DIR}"/* 2>/dev/null || true
mkdir -p "${KEYRING_DIR}"
printf "[Keyring]\ndisplay-name=Login\nlock-on-idle=false\n" > "${KEYRING_DIR}/login.keyring"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "/home/${KIOSK_USER}/.local"

# =========================
# Neustart
# =========================

echo "Setup abgeschlossen. System wird neu gestartet..."
reboot now
