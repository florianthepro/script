#!/usr/bin/env bash
set -euo pipefail
#Daten
KIOSK_USER="dash"
url1="https://monitoring.tcsoc.net/public/mapshow.htm?ids=15901:4C3A7306-367D-40E8-8CD6-A9EC9936D655,16089:577EA9F7-7D38-45C5-A52B-159D3800C66C,14848:6AD7B66E-A56E-4694-8296-D0A24FAC3AED"
url2="https://10.100.100.27/otrs/"
url1_S=60
url2_S=60
SCREEN_ON="08:00"
SCREEN_OFF="19:00"
is_positive_int() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}
#Check
if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root ausführen (z.B. mit: sudo bash setup.sh)" >&2
  exit 1
fi
if [[ -z "${url1}" ]]; then
  echo "url1 ist leer, bitte im Skript setzen." >&2
  exit 1
fi
if ! is_positive_int "${url1_S}"; then
  echo "url1_S muss eine positive ganze Zahl (Sekunden) sein." >&2
  exit 1
fi
if [[ -n "${url2}" ]] && ! is_positive_int "${url2_S}"; then
  echo "url2_S muss eine positive ganze Zahl (Sekunden) sein." >&2
  exit 1
fi
#Pakete
apt-get update
CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium || true)"
if [[ -z "${CHROMIUM_BIN}" ]]; then
  echo "Chromium nicht gefunden, versuche Installation..."
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
apt-get install -y unclutter cec-utils || true
#Dash user
if ! id -u "${KIOSK_USER}" >/dev/null 2>&1; then
  echo "Kiosk-Benutzer ${KIOSK_USER} existiert nicht, wird erstellt..."
  adduser --disabled-password --gecos "" "${KIOSK_USER}"
else
  echo "Kiosk-Benutzer ${KIOSK_USER} existiert bereits."
fi
usermod -aG audio,video,input,gpio,render "${KIOSK_USER}" || true
#rotation
DASHBOARD_START_URL="${url1}"
if [[ -n "${url2}" ]]; then
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
<iframe id="frame" src="${url1}"></iframe>
<script>
  const urls = [
    "${url1}",
    "${url2}"
  ];
  const durations = [
    ${url1_S} * 1000,
    ${url2_S} * 1000
  ];

  let idx = 0;
  const frame = document.getElementById("frame");

  function rotate() {
    idx = (idx + 1) % urls.length;
    frame.src = urls[idx];
    setTimeout(rotate, durations[idx]);
  }

  setTimeout(rotate, durations[0]);
</script>
</body>
</html>
EOF
  chown "${KIOSK_USER}:${KIOSK_USER}" "${ROTATOR_HTML}"
  DASHBOARD_START_URL="file:///home/${KIOSK_USER}/prtg-rotator.html"
fi
#Autostart
AUTOSTART_DIR="/home/${KIOSK_USER}/.config/autostart"
mkdir -p "${AUTOSTART_DIR}"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "/home/${KIOSK_USER}/.config"
cat > "${AUTOSTART_DIR}/prtg-kiosk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=PRTG Monitoring Kiosk
Exec=${CHROMIUM_BIN} --kiosk --incognito --noerrdialogs --disable-translate --disable-infobars --check-for-update-interval=31536000 --password-store=basic --no-first-run --no-default-browser-check --ignore-certificate-errors --allow-insecure-localhost --disable-features=WebContentsForceDark --force-color-profile=srgb "${DASHBOARD_START_URL}"
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
#powering
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
#rechte
if getent group sudo | grep -qE "\b${KIOSK_USER}\b"; then
  deluser "${KIOSK_USER}" sudo || true
fi
#Auto Login
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
#kEyring entfernen
KEYRING_DIR="/home/${KIOSK_USER}/.local/share/keyrings"
rm -f "${KEYRING_DIR}"/* 2>/dev/null || true
mkdir -p "${KEYRING_DIR}"
printf "[Keyring]\ndisplay-name=Login\nlock-on-idle=false\n" > "${KEYRING_DIR}/login.keyring"
chown -R "${KIOSK_USER}:${KIOSK_USER}" "/home/${KIOSK_USER}/.local"
echo "Setup abgeschlossen. System wird neu gestartet..."
reboot now
