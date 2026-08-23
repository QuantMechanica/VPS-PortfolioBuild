# Farm-DB Schema-Härtung — drei Ergänzungen (Auftrag OWNER 2026-08-23)

**Auslöser:** OWNER-Frage beim Archivmatrix-Prototyp — „ist die Datenbank fehlerhaft, funktioniert
sie korrekt, ist es die beste existierende Lösung?"
**Messgrundlage:** `docs/ops/evidence/2026-08-23_strategy_archive_matrix_prototype.md` §2
**Datenbank:** `D:\QM\strategy_farm\state\farm_state.sqlite` (404 MB, WAL, `quick_check ok`)

## Ausgangslage in einem Satz

Die Engine ist gesund und SQLite bleibt die richtige Wahl — **das Schema ist der Defekt**: die
Wahrheit über eine Zeile entsteht in einer TEMP-Sicht zur Lesezeit, nicht in der Tabelle.

| Befund | Zeilen |
|---|---:|
| `invariant.valid` | **false** (107 unklassifizierbar) |
| gespeicherter Status widerspricht dem Verdikt | **9.381** |
| keine gespeicherte Taxonomie | **50.883** |
| gespeicherte Taxonomie widerspricht dem Verdikt | 786 |
| Fremdschlüssel-Waisen (`work_items→tasks` 71, `tasks→sources` 28) | **99** |
| `PRAGMA foreign_keys` | **0 — Durchsetzung aus** |
| Build-Identität je Lauf (`expected_ex5_sha256`) | **0,3 %** der Payloads |
| `candidate_qualifications` | **0 Zeilen** |

## SH-1 · Taxonomie materialisieren

**Problem.** `work_items_clean` (MNT-016) leitet Status und Taxonomie beim Lesen ab. Wer die
TEMP-Sicht nicht installiert, liest 9.381 Zeilen mit einem anderen Status. **Zwei Oberflächen
können dieselbe Datenbank abfragen, verschiedene Zahlen zeigen und beide „recht haben."**

**Umsetzung.** Zwei Spalten auf `work_items` (`verdict_taxonomy_stored`, `clean_status_stored`),
beim Schreiben des Ergebnisses gesetzt, Rückfüllung der Bestandszeilen in einem Lauf. Die Sicht
bleibt bestehen — **als Prüfer, nicht mehr als Quelle**: ein Test vergleicht gespeicherte gegen
abgeleitete Werte und schlägt bei jeder Abweichung an.

**Fail-closed.** Additiv. Keine bestehende Spalte wird überschrieben, kein Verdikt verändert.
Weicht die Rückfüllung für eine Zeile von der Sicht ab, wird die Zeile markiert statt korrigiert.

**Akzeptanz.** `invariant.valid = true`; `taxonomy_derived` = 0 bei neuen Zeilen;
Abweichungszähler gespeichert-vs-abgeleitet = 0; die 107 unklassifizierbaren Zeilen sind
namentlich disponiert (nicht stillschweigend umetikettiert).

## SH-2 · Artefakt-Identität je Lauf *(der teuerste und wichtigste)*

**Problem.** Kein Verdikt kann beantworten, welches `.ex5` es erzeugt hat. Seit „rebuilt EX5 =
neue Identität ab Q02" ist genau das die Voraussetzung dafür, nach einer Rebuild-Welle zu wissen,
welche PASS-Verdikte noch gelten. Ersatzmessungen scheitern beide: der Hash steht in 0,3 % der
Payloads, der Dateizeitstempel würde 73,6 % aller PASS-Zeilen als veraltet markieren, weil
Recompiles und Include-Spiegelung ihn anfassen, ohne den EA zu verändern.

**Umsetzung.** `ex5_sha256` (plus `ex5_built_at`) als **Pflichtfeld beim Schreiben eines
Gate-Ergebnisses**. Wer kein Artefakt nachweisen kann, schreibt kein Verdikt — die Zeile wird
`INVALID` mit eigenem Grund, nicht stillschweigend PASS. Bestandszeilen bleiben leer und werden
in den Oberflächen als „Identität unbekannt" ausgewiesen; **rückwirkendes Raten ist verboten.**

**Wirkung.** Erst damit ist F4 der Archivmatrix baubar (Stale-Pass hohl statt Warnbanner), und
erst damit ist die Frage „gilt dieses PASS noch?" überhaupt beantwortbar.

**Akzeptanz.** Jede nach der Aktivierung geschriebene Gate-Zeile trägt einen Hash; Anteil der
Zeilen ohne Hash sinkt monoton; ein Test weist nach, dass ein Schreibversuch ohne Artefakt
fehlschlägt statt zu passieren.

## SH-3 · Fremdschlüssel einschalten und Waisen bereinigen

**Problem.** Die Schlüssel sind deklariert, `PRAGMA foreign_keys` steht auf 0 — sie wurden nie
durchgesetzt. 99 Waisen sind so entstanden und der Bestand wächst weiter.

**Umsetzung.** `PRAGMA foreign_keys=ON` je Verbindung im Schreibpfad, die 99 Waisen einzeln
disponiert (Zeile mit Grund markieren — **nicht** löschen; Verdikte werden nicht vernichtet).

**Akzeptanz.** `foreign_key_check` = 0 neue Waisen nach Aktivierung; die 99 Bestandsfälle sind
namentlich abgelegt; kein Schreibpfad bricht (Regressionslauf über die Fabrik im OFF-Fenster).

## Reihenfolge und Zuschnitt

SH-3 → SH-1 → SH-2. SH-3 ist die billigste und stoppt den Zufluss. SH-1 beseitigt die
Doppelwahrheit. SH-2 ist der größte Eingriff, weil er den Schreibpfad jedes Gate-Runners berührt,
und braucht ein Factory-OFF-Fenster plus Claude-Review vor der Aktivierung.

**Nicht Teil dieses Auftrags:** die Visualisierung. Die Archivmatrix arbeitet mit dem, was die
Datenbank heute hergibt, und weist die Lücken sichtbar aus.

## Ausdrücklich verboten

Kein Verdikt wird gelöscht oder überschrieben (ROT-Zone). Keine Gate-Kriterien, keine Schwellen,
keine Kandidatenmengen werden berührt. Jede Migration ist additiv und im OFF-Fenster
rückrollbar; die TEMP-Sicht bleibt als unabhängiger Prüfer erhalten.
