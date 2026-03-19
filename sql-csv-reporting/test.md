### Beispiel 1 — Zwei Mermaid Diagramme nebeneinander (HTML Tabelle)

Füge das folgende direkt in deine `README.md`. GitHub akzeptiert HTML und rendert die Mermaid‑Blöcke in den Zellen:

```html
<table>
  <tr>
    <td>

```mermaid
graph LR
A[index.php]
B[rules.php]
C[rules.json]
A --> B
B --> C
```

    </td>
    <td>

```mermaid
graph LR
FW1[Kopfzeile in CSV erforderlich]
FW2[Regeln = Bedingungen]
FW1 --> FW2
```

    </td>
  </tr>
</table>
```

**Hinweis:** Die drei Backticks und `mermaid` müssen exakt innerhalb der `<td>`‑Zellen stehen (wie oben). Keine zusätzlichen Leerzeilen vor `graph LR`.

---
