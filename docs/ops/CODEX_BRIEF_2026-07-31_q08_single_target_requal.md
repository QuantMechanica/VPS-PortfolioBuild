# CODEX BRIEF — Single-Target-Q08-Requalifikations-Controller (OWNER-JA 2026-07-31)

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**OWNER-Entscheid 2026-07-31:** JA zum Bau des Ausnahme-Controllers. Die
globale MNT-007-Invariante (`q08_invalid_report_non_retryable` bleibt für
Waves kategorisch gesperrt) wird NICHT geschwächt — genau dein R1-Rahmen
(Ticket `695f5585`, Finding 3).

## Aufgaben (Design + Implementation; APPLY erst nach Claude-APPROVED)

1. **Controller** `tools/strategy_farm/q08_single_target_requal.py`:
   - Ein (ea_id, symbol)-Ziel je Aufruf; dry-run default.
   - **Ausnahme-Vertrag als Input:** eigenes JSON mit OWNER-Referenz
     (2026-07-31-Entscheid), Ziel-Row-ID, erwartetem Row-Zustand (CAS über
     status/phase/verdict/payload-SHA), Begründung (hier: Parser-Defekt-Klasse
     „strategy_-Zeilen ohne Marker", Fix-Commit-SHA des Fallbacks).
   - **Evidenz-Erhalt:** altes INVALID-Aggregat wird archiviert (verschoben
     unter `D:\QM\reports\work_items\_requal_archive\<row>\` o. ä.), nie
     gelöscht/überschrieben.
   - Bindet beim Requeue die aktuellen Code-/Build-/Setfile-Hashes in die
     Payload (Setfile-Bytes UNVERÄNDERT — base `08202827…`, abl00 `8d47c4cc…`,
     abl01 `f2bf459a…`, abl02 `477bc914…`).
   - Durable Snapshot + guarded revert; `BEGIN IMMEDIATE`; Farm-Event.
2. **Vorbedingungs-Gates im Tool:** (a) Parser-Fallback-Fix ist im kanonischen
   Baum committed (Ticket `1235062d`) und `parse_setfile_assignments` liefert
   >0 für alle vier Ziel-Setfiles; (b) Apply verlangt Factory-OFF-Flag +
   0 aktive Work-Items (Quittung ins Journal) — konsistent mit dem
   Requeue-Apply-Vertrag.
3. Tests: CAS-Fehlschlag, Archiv-Pflicht, Gate-Verweigerungen, Revert.
4. **KEIN Apply in diesem Ticket.** Erster echter Lauf (Ziel: 10582/XAUUSD
   Row `95015420`) erst nach Claudes Implementierungs-Review, im nächsten
   Factory-OFF-Fenster.

## Deliverable

`docs/ops/evidence/2026-07-31_q08_single_target_requal.md`: Design-Notiz,
Commits, Tests, Dry-Run-Beleg gegen die 10582-Row. Danach `update-task <id>
--state REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.
