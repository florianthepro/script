```mermaid
graph LR

subgraph Projektstruktur
    A[index.php]
    B[rules.php]
    C[rules.json]
    D[auto-download.php]
    E[CSV-Datei empty.csv]
    F[README txt]
    G[LICENSE]
    H[rules_backup]
end

subgraph Funktionsweise
    FW1[Kopfzeile in CSV erforderlich]
    FW2[Regeln = Bedingungen: column + pattern + negate]
    FW3[Alle Bedingungen einer Regel = UND]
    FW4[Eine Regel genügt = ODER]
    FW5[Ohne Regeln keine Ausgabe]
    FW6[Anzeige auf Spalten begrenzbar]
end

subgraph Muster
    M1[* Wildcard]
    M2[*text* enthält text]
    M3[n/a = leer oder N/A]
    M4[+X Wert größer als X]
    M5[-X Wert kleiner als X]
    M6[X-Y Wert zwischen X und Y]
    M7[Standard Wildcards]
end

subgraph Voraussetzungen
    V1[PHP >= 7.4]
    V2[Apache oder kompatibler Webserver]
    V3[Schreibrechte für rules.json]
    V4[Schreibrechte für rules_backup]
    V5[Schreibrechte für CSV-Datei]
end

subgraph Installation
    I1[Dateien ins Webserververzeichnis kopieren]
    I2[CSV neben index.php ablegen]
    I3[Berechtigungen setzen]
    I4[rules.php öffnen und Regeln definieren]
    I5[index.php aufrufen]
end

A -->|nutzt| C
A -->|liest| E
B -->|schreibt| C
B -->|legt Backups an| H
D -->|lädt CSV| E
F -->|beschreibt| Projektstruktur
G -->|enthält| Lizenzinfo
