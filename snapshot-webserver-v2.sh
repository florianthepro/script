#!/usr/bin/env bash
set -euo pipefail
# micro snapshot-webserver-v2.sh   # Code einfügen
# chmod +x snapshot-webserver-v2.sh
# sudo ./snapshot-webserver-v2.sh
# ===========================================================
# snapshot_webserver_inkl_tst.sh
#
# 1) Erzeugt setup.sh (Snapshot deines Webservers)
# 2) Analysiert setup.sh:
#    - Pakete
#    - DocumentRoots
#    - pro User eine Rechte-Zeile (chown)
#    - Verzeichnisse, in denen Dateien liegen
#    - interaktiver Modus:
#         exit
#         normal
#         list
#         detail <pfad>
# ===========================================================

SETUP="setup.sh"

# -----------------------------------------------------------
# Helper
# -----------------------------------------------------------

shell_quote() {
    local s="$1"
    printf "'%s'" "${s//\'/\'\"\'\"\'}"
}

# globale Strukturen für Analyse
declare -A FILE_START FILE_END      # Pfad -> Start/End-Zeile (Base64)
declare -A DIR_HAS_FILES            # Verzeichnis -> 1
declare -A USER_COUNT USER_DIRS     # user -> count, dirs-list
declare -a ALL_FILES                # Liste aller Pfade

# -----------------------------------------------------------
# SNAPSHOT FUNKTION
# -----------------------------------------------------------

snapshot() {
    echo "🟦 Starte Snapshot des Webservers…"

    # 1) Pakete erkennen
    detect_packages() {
        local pkgs=("apache2")
        local prefixes=("apache2" "libapache2-mod" "php" "php-" "php7" "php8")

        if output=$(dpkg-query -f '${binary:Package}\n' -W 2>/dev/null); then
            while IFS= read -r name; do
                [[ -z "$name" ]] && continue
                for p in "${prefixes[@]}"; do
                    if [[ "$name" == "$p"* ]]; then
                        pkgs+=("$name")
                        break
                    fi
                done
            done <<< "$output"
        fi

        # Duplikate raus
        local -A seen=()
        local final=()
        for p in "${pkgs[@]}"; do
            [[ -n "${seen[$p]:-}" ]] && continue
            seen["$p"]=1
            final+=("$p")
        done

        PKGS=("${final[@]}")
    }

    # 2) DocumentRoots erkennen
    detect_docroots() {
        DOCROOTS=()
        local DIR="/etc/apache2/sites-enabled"

        if [[ -d "$DIR" ]]; then
            while IFS= read -r conf; do
                [[ -f "$conf" ]] || continue
                while IFS= read -r line; do
                    line="${line#"${line%%[![:space:]]*}"}"
                    [[ -z "$line" ]] && continue
                    [[ "$line" == \#* ]] && continue
                    if [[ "$line" =~ ^[Dd]ocument[Rr]oot[[:space:]]+(.+)$ ]]; then
                        local root="${BASHREMATCH[1]}"
                        root="${root%\"}"; root="${root#\"}"
                        root="${root%\'}"; root="${root#\'}"
                        [[ -n "$root" ]] && DOCROOTS+=("$root")
                    fi
                done < "$conf"
            done < <(find "$DIR" -maxdepth 1 -type f -name "*.conf" -print)
        fi

        if [[ "${#DOCROOTS[@]}" -eq 0 ]]; then
            DOCROOTS=("/var/www/html")
        fi
    }

    # 3) setup.sh schreiben
    write_snapshot() {
        local out="$1"
        local docroots=("${DOCROOTS[@]}")
        local pkgs=("${PKGS[@]}")

        cat > "$out" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# automatisch erzeugtes Setup-Skript

if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root ausführen (z.B. mit: sudo ./setup.sh)" >&2
  exit 1
fi

EOF

        echo "apt-get update" >> "$out"
        printf 'DEBIAN_FRONTEND=noninteractive apt-get install -y' >> "$out"
        printf ' %q' "${pkgs[@]}" >> "$out"
        echo >> "$out"
        echo >> "$out"

        echo "# Bekannte DocumentRoots (aus Quellmaschine):" >> "$out"
        for r in "${docroots[@]}"; do
            echo "#   - $r" >> "$out"
        done
        echo >> "$out"

        echo 'echo "[INFO] Verzeichnisse anlegen und Rechte setzen..."' >> "$out"

        # Verzeichnisse
        declare -A DIRS=()
        local root
        for root in "${docroots[@]}"; do
            [[ -d "$root" ]] || continue
            while IFS= read -r -d '' d; do
                local st
                st=$(stat -c '%a %U %G' "$d" 2>/dev/null || echo "")
                [[ -z "$st" ]] && continue
                DIRS["$d"]="$st"
            done < <(find "$root" -type d -print0)
        done

        local d
        for d in $(printf "%s\n" "${!DIRS[@]}" | sort -V); do
            local st="${DIRS[$d]}"
            local mode user group
            read -r mode user group <<< "$st"
            local q=$(shell_quote "$d")
            echo "mkdir -p $q" >> "$out"
            echo "chmod $mode $q || true" >> "$out"
            echo "chown $user:$group $q || true" >> "$out"
        done

        echo >> "$out"
        echo 'echo "[INFO] Dateien schreiben..."' >> "$out"

        # Dateien
        for root in "${docroots[@]}"; do
            [[ -d "$root" ]] || continue
            while IFS= read -r -d '' f; do
                local st
                st=$(stat -c '%a %U %G' "$f" 2>/dev/null || echo "")
                [[ -z "$st" ]] && continue
                local fmode fuser fgroup
                read -r fmode fuser fgroup <<< "$st"
                local b64
                b64=$(base64 -w0 "$f" 2>/dev/null || echo "")
                [[ -z "$b64" ]] && continue
                local qf
                qf=$(shell_quote "$f")

                echo "# Datei: $f" >> "$out"
                echo "base64 -d > $qf << 'EOF_B64'" >> "$out"
                echo "$b64" | fold -w76 >> "$out"
                echo "EOF_B64" >> "$out"
                echo "chmod $fmode $qf || true" >> "$out"
                echo "chown $fuser:$fgroup $qf || true" >> "$out"
                echo >> "$out"
            done < <(find "$root" -type f -print0)
        done

        echo 'echo "[INFO] Setup abgeschlossen."' >> "$out"

        chmod +x "$out"
    }

    detect_packages
    detect_docroots
    write_snapshot "$SETUP"

    echo "🟩 Snapshot OK – setup.sh erstellt"
}

# -----------------------------------------------------------
# ANALYSE-FUNKTIONEN
# -----------------------------------------------------------

index_setup() {
    # Base64-Blöcke indexieren
    while IFS= read -r line; do
        local lineno="${line%%:*}"
        local rest="${line#*:}"
        if [[ "$rest" =~ base64\ -d\ \>\ (.+)\ \<\<\ \'EOF_B64\' ]]; then
            local path="${BASH_REMATCH[1]}"
            path="${path//\'}"
            local start=$((lineno+1))
            local end_rel
            end_rel=$(sed -n "${start},999999p" "$SETUP" | grep -nm1 "EOF_B64" | cut -d: -f1)
            local end=$((start + end_rel - 2))
            FILE_START["$path"]=$start
            FILE_END["$path"]=$end
            ALL_FILES+=("$path")
            local dir
            dir=$(dirname "$path")
            DIR_HAS_FILES["$dir"]=1
        fi
    done < <(grep -n "base64 -d >" "$SETUP")

    # chown-Zeilen indexieren (User-Übersicht)
    while IFS= read -r line; do
        if [[ "$line" =~ chown[[:space:]]+([^:[:space:]]+):([^[:space:]]+)[[:space:]]+\'([^\']+)\' ]]; then
            local user="${BASH_REMATCH[1]}"
            local group="${BASH_REMATCH[2]}"
            local path="${BASH_REMATCH[3]}"
            USER_COUNT["$user"]=$(( ${USER_COUNT["$user"]:-0} + 1 ))
            local dir
            dir=$(dirname "$path")
            local current="${USER_DIRS["$user"]:-}"
            if [[ " $current " != *" $dir "* ]]; then
                USER_DIRS["$user"]="$current $dir"
            fi
        fi
    done < "$SETUP"
}

show_normal() {
    echo
    echo "====================================================="
    echo "🧪 TEST & ANALYSE VON setup.sh (NORMAL)"
    echo "====================================================="
    echo

    echo "📌 Pakete aus setup.sh:"
    grep -oP "apt-get install -y \K.*" "$SETUP" | head -n1
    echo

    echo "📁 DocumentRoots:"
    grep -oP "#   - \K.*" "$SETUP" || true
    echo

    echo "👤 Benutzer / chown-Zugriff (eine Zeile pro User):"
    local user
    for user in $(printf "%s\n" "${!USER_COUNT[@]}" | sort); do
        local count="${USER_COUNT[$user]}"
        local dirs="${USER_DIRS[$user]}"
        local shown=""
        local i=0
        for d in $dirs; do
            shown+="$d, "
            ((i++))
            [[ $i -ge 5 ]] && break
        done
        shown="${shown%, }"
        echo "  • $user: $count Pfade (z.B. $shown)"
    done
    echo

    echo "📂 Verzeichnisse mit Dateien:"
    for dir in $(printf "%s\n" "${!DIR_HAS_FILES[@]}" | sort -V); do
        echo "  • $dir"
    done
    echo
}

show_list() {
    echo
    echo "====================================================="
    echo "📚 LISTE – ALLE VERZEICHNISSE UND DATEIEN"
    echo "====================================================="
    echo

    echo "📂 Verzeichnisse mit Dateien:"
    for dir in $(printf "%s\n" "${!DIR_HAS_FILES[@]}" | sort -V); do
        echo "  • $dir"
    done

    echo
    echo "📄 Alle Dateien (aus setup.sh):"
    for f in "${ALL_FILES[@]}"; do
        echo "  • $f"
    done
    echo
}

show_detail() {
    local path="$1"
    if [[ -z "${FILE_START[$path]:-}" ]]; then
        echo "❌ Pfad nicht in setup.sh gefunden: $path"
        return
    fi

    local start="${FILE_START[$path]}"
    local end="${FILE_END[$path]}"

    local data raw
    data=$(sed -n "${start},${end}p" "$SETUP" | tr -d '\n')
    raw=$(echo "$data" | base64 -d 2>/dev/null || echo "")

    if [[ -z "$raw" ]]; then
        echo "❌ Fehler beim Decodieren von $path"
        return
    fi

    # Binär-Check
    if echo "$raw" | grep -qP '[\x00-\x08\x0B\x0C\x0E-\x1F]'; then
        local tmp="/tmp/setup_detail_$(basename "$path")"
        echo "$data" | base64 -d > "$tmp"
        echo "🖼 Binärdatei wurde nach $tmp geschrieben."
    else
        echo "-----------------------------"
        echo "📄 Inhalt von: $path"
        echo "-----------------------------"
        echo "$raw"
        echo "-----------------------------"
    fi
}

interactive_loop() {
    while true; do
        echo
        read -rp "[modus] Befehl (exit|normal|list|detail <pfad>): " line
        [[ -z "$line" ]] && continue
        local cmd arg
        cmd="${line%% *}"
        arg="${line#* }"
        [[ "$arg" == "$cmd" ]] && arg=""

        case "$cmd" in
            exit)
                echo "👋 Beende interaktiven Modus."
                break
                ;;
            normal)
                show_normal
                ;;
            list)
                show_list
                ;;
            detail)
                if [[ -z "$arg" ]]; then
                    echo "Bitte Pfad angeben: detail /var/www/html/datei"
                else
                    show_detail "$arg"
                fi
                ;;
            *)
                echo "Unbekannter Befehl: $cmd"
                echo "Mögliche Befehle: exit | normal | list | detail <pfad>"
                ;;
        esac
    done
}

# -----------------------------------------------------------
# MAIN
# -----------------------------------------------------------

main() {
    if [[ $EUID -ne 0 ]]; then
        echo "Bitte als root ausführen (z.B. mit: sudo ./snapshot_webserver_inkl_tst.sh)" >&2
        exit 1
    fi

    # 1) Snapshot erzeugen
    snapshot

    # 2) Index über setup.sh aufbauen
    index_setup

    # 3) Normalansicht anzeigen
    show_normal

    # 4) Interaktiver Modus
    interactive_loop
}

main "$@"
