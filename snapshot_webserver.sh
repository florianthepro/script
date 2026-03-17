#!/usr/bin/env bash
# micro chmod +x ./
# scp root@ip:/root/setup.sh .
set -euo pipefail

OUT_SCRIPT="${1:-setup.sh}"

shell_quote() {
  local s="$1"
  printf "'%s'" "${s//\'/\'\"\'\"\'}"
}

detect_packages() {
  echo "[INFO] Ermittele installierte Webserver-Pakete..." >&2

  local pkgs=("apache2")

  if ! command -v dpkg-query >/dev/null 2>&1; then
    echo "[WARN] dpkg-query nicht gefunden, nur apache2 wird installiert." >&2
    PKGS=("apache2")
    return
  fi

  local output
  if ! output=$(dpkg-query -f '${binary:Package}\n' -W 2>/dev/null); then
    echo "[WARN] Konnte dpkg-query nicht ausführen, nur apache2 wird installiert." >&2
    PKGS=("apache2")
    return
  fi

  local prefixes=("apache2" "libapache2-mod" "php" "php-" "php7" "php8")
  local line p

  while IFS= read -r line; do
    line="${line%% *}"
    [[ -z "$line" ]] && continue
    for p in "${prefixes[@]}"; do
      if [[ "$line" == "$p"* ]]; then
        pkgs+=("$line")
        break
      fi
    done
  done <<< "$output"

  local -A seen=()
  local unique=()
  for p in "${pkgs[@]}"; do
    [[ -n "${seen[$p]:-}" ]] && continue
    seen["$p"]=1
    unique+=("$p")
  done

  PKGS=("${unique[@]}")
  echo "[INFO] Erkannte Pakete: ${PKGS[*]}" >&2
}

detect_docroots() {
  echo "[INFO] Ermittele Apache DocumentRoots..." >&2
  DOCROOTS=()

  local sites_dir="/etc/apache2/sites-enabled"
  if [[ -d "$sites_dir" ]]; then
    while IFS= read -r conf; do
      [[ -f "$conf" ]] || continue
      while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue

        if [[ "$line" =~ ^[Dd]ocument[Rr]oot[[:space:]]+(.+)$ ]]; then
          local path="${BASH_REMATCH[1]}"
          path="${path%\"}"
          path="${path#\"}"
          path="${path%\'}"
          path="${path#\'}"
          [[ -z "$path" ]] && continue
          DOCROOTS+=("$path")
        fi
      done < "$conf"
    done < <(find "$sites_dir" -maxdepth 1 -type f -name '*.conf' -print)
  fi

  if [[ "${#DOCROOTS[@]}" -eq 0 ]]; then
    DOCROOTS+=("/var/www/html")
    echo "[INFO] Keine DocumentRoots in /etc/apache2/sites-enabled gefunden, Fallback: /var/www/html" >&2
  else
    echo "[INFO] Erkannte DocumentRoots:" >&2
    printf '  - %s\n' "${DOCROOTS[@]}" >&2
  fi
}

write_setup_header() {
  local out="$1"

  cat > "$out" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Automatisch erzeugtes Setup-Skript.
# Installiert Apache + Web-Pakete und stellt Dateien wieder her.

if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root ausführen (z.B. mit: sudo bash setup.sh)" >&2
  exit 1
fi

EOF
}

write_package_install() {
  local out="$1"
  shift
  local pkgs=("$@")

  echo 'echo "[INFO] Paketindex aktualisieren und Pakete installieren..."' >> "$out"
  echo "apt-get update" >> "$out"
  if ((${#pkgs[@]} > 0)); then
    printf 'DEBIAN_FRONTEND=noninteractive apt-get install -y' >> "$out"
    printf ' %q' "${pkgs[@]}" >> "$out"
    echo >> "$out"
  fi
  echo >> "$out"
}

write_docroots_comment() {
  local out="$1"
  shift
  local docroots=("$@")

  echo "# Bekannte DocumentRoots (aus der Quellmaschine):" >> "$out"
  for d in "${docroots[@]}"; do
    echo "#   - $d" >> "$out"
  done
  echo >> "$out"
}

snapshot_dirs_and_files() {
  local out="$1"
  shift
  local docroots=("$@")

  echo 'echo "[INFO] Lege Verzeichnisse an und setze Rechte..."' >> "$out"

  local root dir mode user group qdir
  for root in "${docroots[@]}"; do
    if [[ ! -d "$root" ]]; then
      echo "[WARN] DocumentRoot $root existiert nicht, überspringe..." >&2
      continue
    fi

    while IFS= read -r -d '' dir; do
      if ! stat_out=$(stat -c '%a %U %G' "$dir" 2>/dev/null); then
        continue
      fi
      mode=${stat_out%% *}
      stat_out=${stat_out#* }
      user=${stat_out%% *}
      group=${stat_out#* }

      qdir=$(shell_quote "$dir")

      echo "mkdir -p $qdir" >> "$out"
      echo "chmod $mode $qdir || true" >> "$out"
      echo "chown $user:$group $qdir || true" >> "$out"
    done < <(find "$root" -type d -print0)
  done

  echo >> "$out"
  echo 'echo "[INFO] Schreibe Dateien..."' >> "$out"

  local file stat_out fmode fuser fgroup qfile b64
  for root in "${docroots[@]}"; do
    if [[ ! -d "$root" ]]; then
      continue
    fi

    while IFS= read -r -d '' file; do
      if ! stat_out=$(stat -c '%a %U %G' "$file" 2>/dev/null); then
        continue
      fi
      fmode=${stat_out%% *}
      stat_out=${stat_out#* }
      fuser=${stat_out%% *}
      fgroup=${stat_out#* }

      qfile=$(shell_quote "$file")

      if ! b64=$(base64 -w0 "$file" 2>/dev/null); then
        echo "[WARN] Konnte Datei $file nicht lesen, überspringe..." >&2
        continue
      fi

      echo "# Datei: $file" >> "$out"
      echo "base64 -d > $qfile << 'EOF_B64'" >> "$out"
      echo "$b64" | fold -w76 >> "$out"
      echo "EOF_B64" >> "$out"
      echo "chmod $fmode $qfile || true" >> "$out"
      echo "chown $fuser:$fgroup $qfile || true" >> "$out"
      echo >> "$out"
    done < <(find "$root" -type f -print0)
  done

  echo 'echo "[INFO] Setup abgeschlossen."' >> "$out"
}


main() {
  if [[ -e "$OUT_SCRIPT" ]]; then
    echo "[WARN] $OUT_SCRIPT existiert bereits und wird überschrieben." >&2
  fi

  detect_packages
  detect_docroots

  local -a pkgs=("${PKGS[@]}")
  local -a docroots=("${DOCROOTS[@]}")

  write_setup_header "$OUT_SCRIPT"
  write_package_install "$OUT_SCRIPT" "${pkgs[@]}"
  write_docroots_comment "$OUT_SCRIPT" "${docroots[@]}"
  snapshot_dirs_and_files "$OUT_SCRIPT" "${docroots[@]}"

  chmod +x "$OUT_SCRIPT"

  echo "[OK] Snapshot abgeschlossen."
  echo "[OK] Setup-Skript erzeugt: $OUT_SCRIPT"
  echo "[HINWEIS] Auf Zielsystem: sudo $OUT_SCRIPT"
}

main "$@"
