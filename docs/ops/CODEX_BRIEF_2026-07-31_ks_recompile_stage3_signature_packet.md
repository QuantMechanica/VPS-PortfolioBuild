# CODEX BRIEF — KS-Recompile Stufe 3: Registry-Cleanup + Lineage-Beweis + OWNER-Signatur-Paket

**Ticket-Klasse:** ops_issue · **Reviewer danach:** Claude
**Autorisierung:** close-review APPROVED auf Stufe 2 (`45da1fa0`) inkl.
Reviewer-Gate-Revision; Entscheidung
`decisions/2026-07-31_t_live_ks_vintage_recompile_plan_approval.md`.

## Aufgaben

1. **12567-Registry-Cleanup (minimal, eigener Commit):** In
   `ea_id_registry.csv` NUR die spätere redundante Zeile 3515 löschen (beide
   Zeilen identisch: `12567,cum-rsi2-commodity,ee172909…,active`). KEINE
   Änderung an `magic_numbers.csv` oder am Resolver. Validator-Nachweis: der
   `duplicate_ea_id:12567`-Befund verschwindet, die globale Issue-Zahl sinkt
   exakt um diesen Befund, nichts anderes ändert sich.
2. **Include-Lineage-Beweis (Kern der Gate-Revision):** Zeige mit
   `git log -L` / Region-Diff, dass die Baseline-Pfadkonstruktion und der
   Lade-Pfad in `QM_KillSwitchKS.mqh` (Konstruktion `QM\baselines\QM5_%d_%s.json`,
   terminal-local FileOpen + FILE_COMMON-Retry, ABSENT-Emission) zwischen dem
   Pin der 07-13-Live-Builds (die 14 heute ladenden Sleeves, z. B. Commit
   `cf2264bb` DXZ-23-Rebuild) und dem Stage-2-Pin `386151841` **unverändert**
   ist. Falls sich die Region DOCH geändert hat: exakte Diffs + Bewertung, ob
   funktionsneutral — ehrlich, nicht wegargumentieren.
3. **OWNER-Signatur-Paket** als EIN kompaktes Dokument
   (`docs/ops/evidence/2026-07-31_ks_recompile_signature_packet.md`):
   - Deploy-Manifest-Referenz (Stage-2-UNSIGNED + finale Hash-Kette
     source→closure→EX5→Stage→T_Live-Ziel, Preimages, Rollback);
   - **Verhaltens-Mitfahrer explizit:** 10911 neuer 1,0 %-Per-Trade-Cap,
     News-Gating-Änderungen, Execution-Contracts (Init-Fail statt
     Stilllauf), Risk-/Order-Härtungen;
   - **Registry-Ausnahme-Text:** globaler Validator-FAIL (Alt-Backlog,
     Zahlen nach Cleanup) als exakte Baseline-Ausnahme zum Mitzeichnen;
   - **Gate-Revision:** Tester-Smoke-Beleg + Lineage-Beweis (Punkt 2) +
     „KS_BASELINE_LOADED 9/9 als ERSTE Post-Deploy-Verifikation im
     Sonntags-Fenster, Rollback-Preimages bereit" — mit dem Quellzitat, warum
     off-live unmöglich (MQL_TESTER-Guard);
   - MNT-043/044-Bill-Referenz + Q06/Q07-Rerun-Liste;
   - Signaturfelder (OWNER-Datum/Wortlaut) leer.
4. **Sonntags-Runbook-Abschnitt** im Paket: exakte Deploy-Schritte (file-side,
   SHA-verifiziert, Standing-Prozedur), Verifikations-Grep-Kommandos,
   Rollback-Kommandos.

## Do NOT

- Kein Deploy, kein T_Live-Write, kein Overlay-Append, kein Factory-Zyklus,
  keine weiteren Registry-Zeilen. Staging-Artefakte unangetastet lassen.

## Deliverable

Signatur-Paket + Cleanup-Commit + Lineage-Beweis. Danach `update-task <id>
--state REVIEW --artifact-path <deliverable> --verdict "<kurz>"`.
