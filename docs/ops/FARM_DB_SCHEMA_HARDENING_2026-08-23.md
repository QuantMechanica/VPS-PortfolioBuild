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

## Umsetzungsstand 2026-08-23 abends

Werkzeug: `tools/strategy_farm/schema_hardening.py` (`check` = read-only, `migrate --apply`).

### SH-1 — **erledigt und aktiv**

Zwei additive Spalten auf `work_items` (`verdict_taxonomy_stored`, `clean_status_stored`),
befüllt aus denselben Funktionen, die die Sicht benutzt.

- Zuerst auf einer **Kopie** der Datenbank getestet (`_sh1_test.sqlite`, aus der Sicherung von
  11:46 Uhr): 111.624 Zeilen in 6,1 s, **0 Drift**, Validator `valid: true`.
- Danach live: **111.399 Zeilen in 5,2 s, 0 Drift**, `unfilled: 0`, `mismatch: {}`.
- Blast Radius benannt und geprüft: `ALTER TABLE … ADD COLUMN` ist in SQLite reine Metadaten,
  die Spalten hängen hinten an, und **jeder Lesezugriff im Code erfolgt namentlich**
  (`_work_item_value(row, key)`, `row_factory`, `dict(r)`) — kein positionsbasiertes Entpacken.
  Rückrollung: Spalten ignorieren oder `DROP COLUMN`; keine bestehende Spalte wurde verändert.
- **Die Sicht bleibt Prüfer, nicht Quelle:** der Validator vergleicht gespeichert gegen
  abgeleitet und meldet jede Abweichung. Ein bereits abweichender gespeicherter Wert wird
  **gemeldet, nicht stillschweigend überschrieben**.
- Nachlauf für neu geschriebene Zeilen: Task `QM_StrategyFarm_TaxonomyMaterialize_Hourly`
  (SYSTEM, stündlich) füllt nur `NULL`-Werte. Der Schreibpfad selbst bleibt unangetastet —
  das ist SH-2-Arbeit.

### SH-3 — **Annahme widerlegt, als Monitor ausgeliefert**

Die Auflage lautete „Fremdschlüssel einschalten und die 99 Waisen bereinigen". **Gemessen ist
das falsch:** die deklarierten Schlüssel beschreiben nicht, wie die Spalten benutzt werden.

| Spalte | deklariert | tatsächlich |
|---|---|---|
| `work_items.parent_task_id` | `REFERENCES tasks(id)` | **polymorph** — von 71 hängenden Werten zeigen **39 auf `work_items`** (Eltern/Kind-Linie), **14 auf `agent_tasks`**, 18 ins Leere |
| `tasks.source_id` | `REFERENCES sources(id)` | hält **EA-IDs** wie `QM5_12108` (10 der 28 Fälle eindeutig EA-förmig) |

`PRAGMA foreign_keys=ON` würde die Fabrik beim nächsten Schreibvorgang dieser Formen
**fail-closed stellen** — und die Waisen entstehen weiter (jüngste 2026-08-14, 38 der 71 aus
August). Eine Bereinigung der 99 Zeilen wäre zudem sinnlos, solange das Ziel der Referenz
polymorph ist.

Ausgeliefert ist deshalb `schema_hardening.py check`: es zählt die Verletzungen, **klassifiziert
sie nach tatsächlichem Ziel** und sagt ausdrücklich `safe_to_enforce: false` mit Begründung.

**Was SH-3 jetzt wirklich braucht** (eigener Auftrag, eigenes OFF-Fenster): getrennte Spalten
`parent_work_item_id` / `parent_agent_task_id` statt einer polymorphen, und für `tasks.source_id`
entweder eine Umbenennung auf das, was drinsteht, oder die Streichung der irreführenden
Deklaration. Erst danach ist Durchsetzung überhaupt eine sinnvolle Frage.

### SH-2 — unverändert offen

Braucht den Schreibpfad jedes Gate-Runners und damit ein Factory-OFF-Fenster plus Review vor
der Aktivierung. Nichts daran hat sich durch SH-1/SH-3 verschoben.
