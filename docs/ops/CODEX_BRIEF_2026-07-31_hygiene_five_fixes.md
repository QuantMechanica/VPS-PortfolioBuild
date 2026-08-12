# CODEX BRIEF — Hygiene-Fünferpack aus den 07-31-Review-Verdikten

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
Fünf in Verdikten festgehaltene, bisher nicht umgesetzte Punkte. Jeder Punkt =
eigener Commit mit Pathspecs; Tests wo sinnvoll. Keine Factory-/Task-/T_Live-
Mutation; reine Quell-/Test-/Kalibrierarbeit.

1. **Pump-Gate-Kalibrierung:** Health-Gate-Timeout (1800 s, Factory_ON.ps1)
   gegen gemessene Kalt-Perzentilen bzw. das Task-ExecutionTimeLimit (PT10M)
   ableiten statt Punktschätzung; Begründung + ggf. Wertänderung dokumentieren.
2. **Last-Line-Protokoll:** Runtime-/Restore-Validator-Ausgabe von
   „letzte non-empty Zeile = JSON" auf getrennte Streams oder gerahmten Record
   heben (Factory_ON/OFF-Aufrufseiten + factory_runtime_activation-Ausgabe);
   Tests für Noise-Fälle behalten.
3. **batch_coder.py:246:** direkter INSERT umgeht `enqueue_task` — auf den
   kanonischen Enqueue-Pfad umstellen (Validierung/Defaults nicht duplizieren).
4. **list_tasks-Ordnung:** fehlende Tests für Router-Sortierung (priority DESC
   seit b65ec9eb7) inkl. Tie-Breaker — festschreiben, damit die
   ASC-Regression nicht zurückkommt.
5. **Manuelle Prozess-Kills:** Evidenz-Logging-Pfad (wer/wann/warum, Zielpfad
   D:\QM\reports\state o. ä.) für manuelle Terminal-/Worker-Kills gemäß
   Operating-Rules-Beleg-Pflicht.

## Deliverable

`docs/ops/evidence/2026-07-31_hygiene_five_fixes.md`: je Punkt Commit +
Test-/Laufnachweis oder begründetes DEFER. Danach `update-task <id> --state
REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.
