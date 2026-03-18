#!/usr/bin/env bash
set -uo pipefail
SETUP="setup.sh"
shell_quote() {
    local s="$1"
    printf "'%s'" "${s//\'/\'\"\'\"\'}"
}
declare -A FILE_START FILE_END
declare -A DIR_HAS_FILES
declare -A USER_COUNT USER_DIRS
declare -a ALL_FILES
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
    local -A seen=()
    local final=()
    for p in "${pkgs[@]}"; do
        [[ -n "${seen[$p]:-}" ]] && continue
        seen["$p"]=1
        final+=("$p")
    done

    PKGS=("${final[@]}")
}
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
                    local root="${BASH_REMATCH[1]}"
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
    local r
    for r in "${docroots[@]}"; do
        echo "#   - $r" >> "$out"
    done
    echo >> "$out"
    echo 'echo "[INFO] Verzeichnisse anlegen und Rechte setzen..."' >> "$out"
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
        local st mode user group q
        st="${DIRS[$d]}"
        read -r mode user group <<< "$st"
        q=$(shell_quote "$d")
        echo "mkdir -p $q" >> "$out"
        echo "chmod $mode $q || true" >> "$out"
        echo "chown $user:$group $q || true" >> "$out"
    done
    echo >> "$out"
    echo 'echo "[INFO] Dateien schreiben..."' >> "$out"
    # Dateien
    local f
    for root in "${docroots[@]}"; do
        [[ -d "$root" ]] || continue
        while IFS= read -r -d '' f; do
            local st fmode fuser fgroup b64 qf
            st=$(stat -c '%a %U %G' "$f" 2>/dev/null || echo "")
            [[ -z "$st" ]] && continue
            read -r fmode fuser fgroup <<< "$st"
            b64=$(base64 -w0 "$f" 2>/dev/null || echo "")
            [[ -z "$b64" ]] && continue
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
snapshot() {
    echo "🟦 Starte Snapshot des Webservers…"
    detect_packages
    detect_docroots
    write_snapshot "$SETUP"
    echo "🟩 Snapshot OK – setup.sh erstellt"
}
index_setup() {
    while IFS= read -r line; do
        local lineno rest path start end_rel end dir
        lineno="${line%%:*}"
        rest="${line#*:}"
        path=$(printf '%s\n' "$rest" | sed -E "s/.*base64 -d > '([^']+)'.*/\1/")
        [[ -z "$path" ]] && continue
        start=$((lineno+1))
        end_rel=$(sed -n "${start},999999p" "$SETUP" | grep -nm1 "EOF_B64" | cut -d: -f1 || true)
        [[ -z "$end_rel" ]] && continue
        end=$((start + end_rel - 2))
        FILE_START["$path"]=$start
        FILE_END["$path"]=$end
        ALL_FILES+=("$path")
        dir=$(dirname "$path")
        DIR_HAS_FILES["$dir"]=1
    done < <(grep -n "base64 -d >" "$SETUP" || true)
    while IFS= read -r line; do
        if [[ "$line" =~ chown[[:space:]]+([^:[:space:]]+):([^[:space:]]+)[[:space:]]+\'([^\']+)\' ]]; then
            local user group path dir current
            user="${BASH_REMATCH[1]}"
            group="${BASH_REMATCH[2]}"
            path="${BASH_REMATCH[3]}"
            USER_COUNT["$user"]=$(( ${USER_COUNT["$user"]:-0} + 1 ))
            dir=$(dirname "$path")
            current="${USER_DIRS["$user"]:-}"
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
    local pkg_line
    pkg_line=$(grep "apt-get install -y" "$SETUP" || true)
    pkg_line=${pkg_line#*apt-get install -y }
    echo "$pkg_line"
    echo

    echo "📁 DocumentRoots:"
    grep "#   - " "$SETUP" | sed 's/^#   - //' || true
    echo

    echo "👤 Benutzer / chown-Zugriff (eine Zeile pro User):"
    if [[ ${#USER_COUNT[@]} -eq 0 ]]; then
        echo "  • (keine spezifischen Benutzer gefunden – keine chown-Zeilen oder alles root)"
    else
        local user
        for user in $(printf "%s\n" "${!USER_COUNT[@]}" | sort || true); do
            local count dirs shown i d
            count="${USER_COUNT[$user]}"
            dirs="${USER_DIRS[$user]}"
            shown=""
            i=0
            for d in $dirs; do
                shown+="$d, "
                ((i++))
                [[ $i -ge 5 ]] && break
            done
            shown="${shown%, }"
            echo "  • $user: $count Pfade (z.B. $shown)"
        done
    fi
    echo
    echo "📂 Verzeichnisse mit Dateien:"
    if [[ ${#DIR_HAS_FILES[@]} -eq 0 ]]; then
        echo "  • (keine gefunden)"
    else
        local dir
        for dir in $(printf "%s\n" "${!DIR_HAS_FILES[@]}" | sort -V || true); do
            echo "  • $dir"
        done
    fi
    echo
}
show_list() {
    echo
    echo "====================================================="
    echo "📚 LISTE – ALLE VERZEICHNISSE UND DATEIEN"
    echo "====================================================="
    echo

    echo "📂 Verzeichnisse mit Dateien:"
    local dir
    for dir in $(printf "%s\n" "${!DIR_HAS_FILES[@]}" | sort -V || true); do
        echo "  • $dir"
    done
    echo
    echo "📄 Alle Dateien (aus setup.sh):"
    local f
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
    local start end data raw
    start="${FILE_START[$path]}"
    end="${FILE_END[$path]}"
    data=$(sed -n "${start},${end}p" "$SETUP" | tr -d '\n')
    raw=$(echo "$data" | base64 -d 2>/dev/null || echo "")
    if [[ -z "$raw" ]]; then
        echo "❌ Fehler beim Decodieren von $path"
        return
    fi
    if printf '%s' "$raw" | LC_ALL=C grep -q '[^[:print:][:space:]]'; then
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
        read -rp "[modus] Befehl (exit|normal|list|detail <pfad>): " line || break
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
main() {
    if [[ $EUID -ne 0 ]]; then
        echo "Bitte als root ausführen (z.B. mit: sudo ./snapshot-webserver.sh)" >&2
        exit 1
    fi
    snapshot
    index_setup
    show_normal
    interactive_loop
}
main "$@"
