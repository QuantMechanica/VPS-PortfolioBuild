# CODEX BRIEF — R2-Paket: Ablation-Präzedenz-Kontrakt + Pump-Gate-Revert + Rules-Hunk

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
Drei klar umrissene Folgearbeiten aus den close-reviews `1235062d` und `50b8dabe`.

## 1. Markerless Ablation-Präzedenz (Reviewer-Resolution aus 1235062d)

In `parse_setfile_assignments` NUR im markerlosen Fallback: akzeptiere das
exakte Ablation-Child-Muster — **zwei zusammenhängende strategy_-Blöcke mit
identischer Key-Menge, Basis-Block vor Override-Block — mit last-value-wins**
(MT5-Tester-Semantik: der Tester nutzte die Override-Werte; jede andere
Lesart verfälscht die Evidenz). JEDES andere Duplikat-Muster bleibt
fail-closed: falsche Reihenfolge nicht unterscheidbar? Dann strukturell:
ungleiche Key-Mengen, >2 Blöcke, Duplikat INNERHALB eines Blocks,
verschachtelte/nicht-zusammenhängende Blöcke → fail. Marker-Pfad unverändert.
Tests: die 3 realen 10582-Ablations parsen 6 (Override-Werte belegen!),
plus Negativfälle (ungleiche Keys, Triple-Block, In-Block-Duplikat,
Marker-Datei mit Duplikat weiterhin fail). Setfile-Bytes unverändert
(SHA-Tabelle erneut).

## 2. Pump-Gate-Revert (Finding aus 50b8dabe Item 1)

`7122eaf2b` teilweise zurücknehmen: `$factoryPostStartHealthTimeoutSeconds`
zurück auf **1800**, `ValidateRange(1, 600)` in `factory_restart_health.ps1`
zurück auf `(1, 1800)`. Begründung ist bindend (deine eigene Messung): 5/13
substantielle Läufe wurden am 600s-Ceiling gekillt ⇒ Erst-Versuch-Erfolg ist
unter Last unzuverlässig; das Gate muss die 5-min-Retry-Kadenz überspannen
können (Early-Exit bei Erfolg macht die große Schranke auf dem Happy-Path
gratis; ein False-Rollback kostet einen vollen OFF/Rebind/ON-Zyklus). Die
Messdaten (p50 550s, 5×@Ceiling) als Kommentar BEHALTEN — sie begründen jetzt
die Mehr-Versuch-Semantik. Test-Assertion entsprechend zurückziehen.

## 3. Operating-Rules-Hunk (aus 50b8dabe Item 5)

Der Edit an `docs/ops/OPERATING_RULES_2026-07-03.md` (Regel 11,
Kill-Recorder-Pflicht) wartet auf OWNER-Ratifikation (Anfrage läuft
2026-07-31). **Kein weiterer Edit an dem Dokument in diesem Ticket.** Falls im
Ticket-Fenster keine Ratifikationsnotiz in
`docs/ops/CONVERGENCE_LEDGER_WEEKEND_2026-07-31.md` erscheint: Hunk in
`docs/ops/proposals/2026-07-31_rule11_kill_recorder_amendment.md` verschieben
und das Rules-Doc auf den ratifizierten Stand zurücksetzen (Tool + Tests
bleiben unangetastet — nur die Regeltext-Frage).

## Randbedingungen

Factory läuft — keine Task-/Prozess-/Flag-Mutation; niemals T5/T_Live.
Commits mit Pathspecs. Hinweis: Punkt 2 berührt runtime-decision-gebundene
Dateien — der ohnehin fällige Decision-Rebind vor dem nächsten Factory ON ist
im Ledger vermerkt, nicht deine Aufgabe.

## Deliverable

`docs/ops/evidence/2026-07-31_r2_parser_precedence_and_pump_gate.md`:
Commits, Testlauf-Summaries, SHA-Tabelle, 10582-Parse-Werte (Override belegt).
Danach `update-task <id> --state REVIEW --artifact-path <deliverable>
--verdict "<kurz>"`.
