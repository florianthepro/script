#!/bin/bash
#Name: ai(made by ai with funktional testing)
#1 fill [emty]
#2 run script with sudo
START_ID=1
MAX_FAILS=3
FAIL_COUNT=0
TARGET_DIR="[emty]"
mkdir -p "$TARGET_DIR"
ID=$START_ID
while true; do
    URL="https://www.gutenberg.org/ebooks/${ID}.epub3.images"
    FILE="book_${ID}.epub"
    echo "Lade herunter: $URL"
    wget -q -O "$FILE" "$URL"
    if [ $? -ne 0 ] || [ ! -s "$FILE" ]; then
        echo "❌ Kein Buch gefunden bei ID $ID"
        rm -f "$FILE"
        FAIL_COUNT=$((FAIL_COUNT+1))
        if [ $FAIL_COUNT -ge $MAX_FAILS ]; then
            echo "3 Fehlversuche erreicht – Script stoppt."
            exit 0
        fi
    else
        echo "✔ Buch $ID erfolgreich geladen."
        mv "$FILE" "$TARGET_DIR/"
        FAIL_COUNT=0
    fi
    ID=$((ID+1))
done
