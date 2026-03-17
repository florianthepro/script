#!/usr/bin/env bash
set -euo pipefail

# ===========================================================
# snapshot_webserver_inkl_tst.sh
#
# Dieses Skript:
#   1) erzeugt eine setup.sh (Snapshot deines Webservers)
#   2) analysiert die setup.sh
#   3) zeigt:
#        - Pakete
#        - DocumentRoots
#        - ALLE Dateien
#        - ALLE chmod/chown Angaben
#        - sichere Vorschau
# 
# ===========================================================

OUT="setup.sh"

# -----------------------------------------------------------
# Helper
# -----------------------------------------------------------

shell_quote() {
    local s="$1"
    printf "'%s'" "${s//\'/\'\"\'\"\'}"
}

# -----------------------------------------------------------
# SNAPSHOT FUNKTION
# -----------------------------------------------------------

snapshot() {
    echo "🟦 Starte Snapshot des Webservers…"

    # (1) Pakete scannen
    detect_packages() {
        local pkgs=("apache2")
        local prefixes=("apache2" "libapache2-mod" "php" "php-" "php7" "php8")

        if output=$(dpkg-query -f '${binary:Package}\n' -W 2>/dev/null); then
            while IFS= read -r name; do
                for p in "${prefixes[@]}"; do
                    if [[ "$name" == "$p"* ]]; then
                        pkgs+=("$name")
                        break
                    fi
                done
            done <<< "$output"
        fi

        # deduplicate
        local -A uniq=()
        local final=()
        for p in "${pkgs[@]}"; do
            [[ -n "${uniq[$p]:-}" ]] && continue
            uniq["$p"]=1
            final+=("$p")
        done

        PKGS=("${final[@]}")
    }

    # (2) DocumentRoots suchen
    detect_docroots() {
        DOCROOTS=()
        local DIR="/etc/apache2/sites-enabled"
        if [[ -d "$DIR" ]]; then
            while IFS= read -r conf; do
                while IFS= read -r line; do
                    line="${line#"${line%%[![:space:]]*}"}"
                    [[ "$line" == \#* ]] && continue
                    if [[ "$line" =~ ^[Dd]ocument[Rr]oot[[:space:]]+(.+)$ ]]; then
                        local root="${BASH_REMATCH[1]}"
                        root="${root%\"}"
                        root="${root#\"}"
                        root="${root%\'}"
                        root="${root#\'}"
                        DOCROOTS+=("$root")
                    fi
                done < "$conf"
            done < <(find "$DIR" -maxdepth 1 -type f -name "*.conf")
        fi
        if [[ "${#DOCROOTS[@]}" -eq 0 ]]; then
            DOCROOTS=("/var/www/html")
        fi
    }

    # (3) Snapshot schreiben
    write_snapshot() {
        local out="$1"
        local docroots=("${DOCROOTS[@]}")
        local pkgs=("${PKGS[@]}")

        echo "#!/usr/bin/env bash" > "$out"
        echo "set -euo pipefail" >> "$out"
        echo "" >> "$out"
        echo "# automatisch erzeugtes Setup-Skript" >> "$out"
        echo "" >> "$out"
        echo "if [[ \$EUID -ne 0 ]]; then echo 'Bitte als root ausführen'; exit 1; fi" >> "$out"
        echo "" >> "$out"

        # Pakete
        echo "apt-get update" >> "$out"
        echo -n "DEBIAN_FRONTEND=noninteractive apt-get install -y" >> "$out"
        printf " %s" "${pkgs[@]}" >> "$out"
        echo "" >> "$out"
        echo "" >> "$out"

        echo "# DocumentRoots:" >> "$out"
        for r in "${docroots[@]}"; do
            echo "#   - $r" >> "$out"
        done
        echo "" >> "$out"

        echo 'echo "[INFO] Verzeichnisse…"' >> "$out"

        # Verzeichnisse erfassen
        declare -A DIRS=()
        for root in "${docroots[@]}"; do
            if [[ ! -d "$root" ]]; then continue; fi

            while IFS= read -r -d '' d; do
                local st
                st=$(stat -c '%a %U %G' "$d")
                DIRS["$d"]="$st"
            done < <(find "$root" -type d -print0)
        done

        # Verzeichnisse sortiert ausgeben
        for d in $(printf "%s\n" "${!DIRS[@]}" | sort -V); do
            read -r mode user group <<< "${DIRS[$d]}"
            q="$(shell_quote "$d")"
            echo "mkdir -p $q" >> "$out"
            echo "chmod $mode $q || true" >> "$out"
            echo "chown $user:$group $q || true" >> "$out"
        done

        echo "" >> "$out"
        echo 'echo "[INFO] Dateien…"' >> "$out"

        # Dateien
        for root in "${docroots[@]}"; do
            [[ -d "$root" ]] || continue

            while IFS= read -r -d '' f; do
                local st b64
                st=$(stat -c '%a %U %G' "$f" 2>/dev/null || echo "")
                [[ -n "$st" ]] || continue

                read -r fmode fuser fgroup <<< "$st"
                b64=$(base64 -w0 "$f")

                qf=$(shell_quote "$f")
                echo "# Datei: $f" >> "$out"
                echo "base64 -d > $qf << 'EOF_B64'" >> "$out"
                echo "$b64" | fold -w76 >> "$out"
                echo "EOF_B64" >> "$out"
                echo "chmod $fmode $qf || true" >> "$out"
                echo "chown $fuser:$fgroup $qf || true" >> "$out"
                echo "" >> "$out"
            done < <(find "$root" -type f -print0)
        done

        chmod +x "$out"
    }

    detect_packages
    detect_docroots
    write_snapshot "$OUT"

    echo "🟩 Snapshot OK – setup.sh erstellt"
}


# -----------------------------------------------------------
# TESTER für setup.sh (inkl. RECHTE)
# -----------------------------------------------------------

tester() {
    echo
    echo "====================================================="
    echo "🧪 TEST & ANALYSE VON setup.sh"
    echo "====================================================="
    echo

    if [[ ! -f "$OUT" ]]; then
        echo "❌ setup.sh existiert nicht."
        exit 1
    fi

    # Pakete
    echo "📌 Pakete aus setup.sh:"
    grep -oP "apt-get install -y \K.*" "$OUT" | head -n1
    echo

    # DocumentRoots
    echo "📁 DocumentRoots:"
    grep -oP "#   - \K.*" "$OUT" || true
    echo

    # Rechte auslesen
    echo "🔐 RECHTE (chmod/chown):"
    echo

    grep -nE "chmod|chown" "$OUT" \
        | sed 's/^/  • /'
    echo

    # Dateien zählen
    COUNT=$(grep -c "base64 -d" "$OUT")
    echo "📦 Dateien gesamt: $COUNT"
    echo

    # sichere Vorschau
    echo "📚 Vorschau der ersten 10 Dateien:"
    echo

    grep -n "base64 -d" "$OUT" | head -n 10 | while read -r line; do
        LINENUM=$(echo "$line" | cut -d: -f1)
        FILEPATH=$(echo "$line" | sed -E 's/.*base64 -d > .([^ ]+).*/\1/' | tr -d "'")
        echo "-----------------------------------"
        echo "📄 Datei: $FILEPATH"
        echo "Zeile: $LINENUM"

        # Base64 extrahieren
        START=$((LINENUM+1))
        END=$(sed -n "${START},500000p" "$OUT" | grep -nm1 "EOF_B64" | cut -d: -f1)
        END=$((START + END - 2))

        DATA=$(sed -n "${START},${END}p" "$OUT" | tr -d '\n')

        RAW=$(echo "$DATA" | base64 -d 2>/dev/null || echo "")

        if echo "$RAW" | grep -qP '[\x00-\x1F]'; then
            echo "➡ Binärdatei – Vorschau unterdrückt"
        else
            echo "➡ Text – Vorschau:"
            echo "$RAW" | head -n 5 | sed 's/</\&lt;/g; s/>/\&gt;/g'
        fi

        echo
    done
}


# -----------------------------------------------------------
# MAIN
# -----------------------------------------------------------

snapshot
tester
