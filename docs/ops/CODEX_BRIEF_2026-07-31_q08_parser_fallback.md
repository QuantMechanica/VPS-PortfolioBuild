# CODEX BRIEF — Q08-8.5: Markerless strategy_-Parser-Fallback (Topic D, Stufe „Code-Fix")

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**Kontext:** Dein D-R1-Review (Ticket `695f5585`, Finding 2/3, von Claude
APPROVED übernommen): Die 10582-Setfiles tragen strategy_-Zeilen ohne den
Section-Header; Byte-Edits sind wegen Evidenz-Bindung
(`aggregate.json` sha `8d47c4…`, run_smoke/ingest-Hash-Doktrin) verboten.
Der Fix ist code-forward — implementiere deine eigene R1-Spezifikation:

## Aufgaben

1. `framework/scripts/q08_5_neighborhood_runner.py::parse_setfile_assignments`:
   Legacy-Fallback — NUR wenn der Marker `; strategy-specific params` fehlt,
   exakte `^strategy_[A-Za-z0-9_]+=`-Zuweisungen ernten; alle bestehenden
   fail-closed-Prüfungen (Duplikate, leere RHS, Optimizer-Zellen,
   Framework-Parameter) bleiben aktiv.
2. Regressionstests: markierte Dateien, legacy-unmarkierte, Duplikat-Keys,
   leere Werte, non-strategy-Zuweisung vor/nach dem Block, gemischte Fälle.
3. Beweis: die vier 10582-XAUUSD-Setfiles (base + ablation_00/01/02) bleiben
   byte-identisch (SHA vorher/nachher, gegen die R1-Tabelle: base `08202827…`,
   abl00 `8d47c4cc…`, abl01 `f2bf459a…`, abl02 `477bc914…`) und
   `parse_setfile_assignments` liefert für jede >0 Zuweisungen.
4. KEIN Requeue — die Q08-Row 95015420 ist `q08_invalid_report_non_retryable`
   (MNT-007); ihre Wiederzulassung braucht einen separat autorisierten
   Single-Target-Requal-Controller (eigenes Ticket nach OWNER-Entscheid).

## Do NOT

- Setfile-Bytes nicht anfassen. Keine DB-Writes, keine Requeues, kein
  Factory-Eingriff, niemals T5/T_Live.
- Marker-Pfad-Semantik nicht verändern (nur Fallback ergänzen).

## Deliverable

`docs/ops/evidence/2026-07-31_q08_parser_fallback.md`: Implementierungs-Commit,
Testlauf-Summary, SHA-Unverändert-Tabelle, parse-Zählungen. Danach
`update-task <id> --state REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.
