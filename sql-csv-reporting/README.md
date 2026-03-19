```markdown
# CSV Rule Viewer

Ein leichtgewichtiges Web‑Interface zur Anzeige und Filterung von CSV‑Daten auf Basis frei definierbarer Regeln.  
Das Tool besteht aus zwei Kernkomponenten:

- **index.php** – Anzeige, Filterung und Hervorhebung der CSV‑Daten  
- **rules.php** – Web‑Editor zum Erstellen, Bearbeiten und Speichern der Regeln  

Die Anwendung benötigt keine externen Bibliotheken und läuft auf jedem Standard‑PHP‑Webserver.

---

## ✨ Features

- **Regelbasiertes Filtern von CSV‑Daten**
  - Bedingungen pro Regel sind **UND‑verknüpft**
  - Mehrere Regeln sind **ODER‑verknüpft**
  - Zeilen werden angezeigt, wenn mindestens eine Regel zutrifft

- **CSV‑Spalten werden automatisch erkannt**
  - basierend auf der Kopfzeile der CSV
  - Spaltenauswahl für die Anzeige einstellbar

- **Regel‑Editor (rules.php)**
  - beliebig viele Regeln
  - pro Regel beliebig viele Bedingungen
  - Negation (`NOT`) pro Bedingung
  - Musterunterstützung:
    - `*` Wildcard  
    - `*text*` enthält  
    - `n/a` → leer oder „N/A“  
    - `+X` größer als X  
    - `-X` kleiner als X  
    - `X-Y` Wertebereich  

- **Optionaler automatischer CSV‑Download**
  - über `auto-download.php`
  - prüft HTTP‑Status, Content‑Type und grundlegende CSV‑Struktur
  - schreibt Logeinträge

- **keine Abhängigkeiten**, keine Datenbank, kein Framework

---

## 📁 Projektstruktur

```

/
├── index.php            # CSV-Ansicht + Regelanwendung
├── rules.php            # Webeditor für Regeln
├── rules.json           # gespeicherte Regeln (wird automatisch erzeugt)
├── rules\_backup/        # automatische Backups
├── auto-download.php    # optionaler CSV-Downloader
├── sample.csv           # neutrale Beispiel-CSV
└── README.md

```

---

## 🛠 Voraussetzungen

- PHP 7.4 oder neuer  
- Schreibrechte im Projektverzeichnis (für `rules.json` und Backups)  
- Eine CSV-Datei mit Kopfzeile (UTF‑8, ohne BOM empfohlen)

---

## 🚀 Verwendung

### 1. CSV-Datei ablegen  
Die CSV‑Datei (z. B. `sample.csv`) wird im selben Verzeichnis wie `index.php` erwartet.

### 2. Regeln anlegen  
`rules.php` im Browser öffnen:

```

http\://<server>/rules.php

```

Regeln können hinzugefügt, bearbeitet oder gelöscht werden.  
Speichern erzeugt bzw. aktualisiert `rules.json`.

### 3. Ansicht nutzen  

```

http\://<server>/index.php

````

Hier werden die CSV‑Daten anhand der Regeln gefiltert und hervorgehoben.

---

## 🧩 Aufbau einer Regel (rules.json)

```json
{
  "description": "Beispiel",
  "conditions": [
    { "column": "Status", "pattern": "Active", "negate": false },
    { "column": "ValueA", "pattern": "5-20", "negate": false }
  ]
}
````

*   Die Bedingung entspricht:
        Status == "Active"
        UND
        ValueA zwischen 5 und 20

*   Mehrere Regeln:
        (Regel 1 erfüllt)
        ODER
        (Regel 2 erfüllt)

***

## 🔽 Beispiel‑CSV (neutral)

    RecordID,Category,CreatedAt,ValueA,ValueB,ValueC,Status,Flag,Counter
    1,GroupA,2025-02-01 10:00:00,12.5,Alpha,True,Active,0,105
    2,GroupB,2025-02-03 09:15:23,7.8,Beta,False,Inactive,1,87

Dieses Sample ist bewusst neutral gehalten und erlaubt keine Rückschlüsse auf reale Systeme oder Daten.

***

## 🔧 Schreibrechte (Linux)

Damit Regeln gespeichert werden können:

```bash
sudo chown -R www-data:www-data /var/www/html/<projekt>
sudo find /var/www/html/<projekt> -type d -exec chmod 750 {} \;
sudo find /var/www/html/<projekt> -type f -exec chmod 640 {} \;
```

***

## 📜 Lizenz

Frei verwendbar zu Demonstrations‑, Analyse‑ und Entwicklungszwecken.  
Alle Datenbeispiele sind synthetisch.

```

---

# 👌 Diese README entspricht jetzt:

✔ GitHub‑Standards  
✔ professioneller Open‑Source‑Lesbarkeit  
✔ neutralen, anonymen Daten  
✔ klarer Struktur wie bei „Starred Repos“  
✔ deinem Funktionsumfang

Wenn du möchtest, erstelle ich dir zusätzlich:

- eine passende `.gitignore`  
- ein generisches `sample.csv` als Datei‑Text  
- ein Icon (`icon.svg`)  
- ein Repo‑Badge‑Block (shields.io)  
- Versionshinweise (CHANGELOG.md)  

Sag einfach Bescheid.
```
