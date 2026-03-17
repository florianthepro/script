#!/usr/bin/env bash
set -euo pipefail

#
# test.sh – Analyse- und Vorschau-Skript für setup.sh
# Muss zusammen mit setup.sh im selben Ordner liegen.
#

SETUP="setup.sh"

if [[ ! -f "$SETUP" ]]; then
    echo "❌ setup.sh nicht gefunden!"
    exit 1
fi

echo "======================================="
echo "  🧪 TEST / ANALYSE FÜR setup.sh"
echo "======================================="
echo

##########################################
# 1) Allgemeine Setup.sh Informationen
##########################################

echo "📌 Allgemeine Informationen:"
echo "----------------------------"

PKGS=$(grep -oP "apt-get install -y \K.*" "$SETUP" | head -n1 || true)
DOCROOTS=$(grep -oP "#   - \K.*" "$SETUP" || true)
FILES_COUNT=$(grep -c "base64 -d" "$SETUP" || true)

echo "➡ Installierte Pakete:"
echo "$PKGS"
echo

echo "➡ DocumentRoots:"
echo "$DOCROOTS"
echo

echo "➡ Anzahl Base64-Dateien im Script: $FILES_COUNT"
echo


##########################################
# 2) Datei-Liste extrahieren
##########################################

echo "======================================="
echo "📄 Dateiübersicht (aus base64-Blöcken)"
echo "======================================="
echo

grep -n "base64 -d >" "$SETUP" | while read -r line; do
    LINENUM=$(echo "$line" | cut -d: -f1)
    PATHFILE=$(echo "$line" | sed -E 's/.*base64 -d > .([^ ]+).*/\1/' | tr -d "'")
    echo "• $PATHFILE (Zeile $LINENUM)"
done

echo


##########################################
# 3) Preview („Pages“) erstellen
##########################################

echo "======================================="
echo "📚 INHALTS-VORSCHAU (PAGES)"
echo "======================================="
echo

BLOCKS=$(grep -n "base64 -d >" "$SETUP" | cut -d: -f1)

for LINE in $BLOCKS; do
    FILEPATH=$(sed -n "${LINE}p" "$SETUP" \
        | sed -E 's/.*base64 -d > .([^ ]+).*/\1/' | tr -d "'")
    
    echo "---------------------------------------"
    echo "📄 Datei: $FILEPATH"
    echo "---------------------------------------"

    START=$((LINE+1))

    # Suche nach nächstem EOF
    END=$(sed -n "${START},999999p" "$SETUP" | grep -nm1 "EOF_B64" | cut -d: -f1)
    END=$((START + END - 2))

    BASE64DATA=$(sed -n "${START},${END}p" "$SETUP" | tr -d '\n')

    # Erkennen: Binär / Text?
    IS_TEXT=0
    if echo "$BASE64DATA" | base64 -d 2>/dev/null | grep -qP '[\x00-\x08\x0B\x0C\x0E-\x1F]'; then
        IS_TEXT=0
    else
        IS_TEXT=1
    fi

    echo "➡ Base64 Länge: ${#BASE64DATA} Zeichen"
    if [[ $IS_TEXT -eq 1 ]]; then
        echo "➡ Datentyp: TEXT"
        echo "📑 Vorschau:"
        echo "--------------------"
        echo "$BASE64DATA" | base64 -d 2>/dev/null | head -n 20
        echo "--------------------"
    else
        echo "➡ Datentyp: BINÄR / BILD / ICON"
        echo "🖼 Base64-Vorschau: $(echo "$BASE64DATA" | cut -c1-80)..."
    fi

    echo
done
