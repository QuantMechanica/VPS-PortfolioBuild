# Decision: FINAL22 deployment DEFERRED — live book unchanged; activation window pulled forward

- Date: 2026-07-26 (afternoon chat)
- Status: accepted (OWNER: „Die offenen Punkte kannst du jetzt bereits umsetzen! Wir lassen
  das Fenster heute Abend lieber fallen (gibt ja noch keine große Abweichung zum
  existierenden Buch) und ändern das Buch erst, wenn wir signifikant bessere Buch Zahlen
  haben.")

## What this changes

1. **No T_Live deployment tonight.** The live DXZ book stays exactly as deployed 2026-07-19
   (24 sleeves, TOTAL_RISK 9.75, account 4000090541). The TOTAL_RISK-12.0 raise and every
   composition change (−10440, −12567/XNGUSD, −10939, +11422) are DEFERRED.
2. **FINAL22 remains the staged next-book candidate** (manifest + 22 presets + runbook all
   verified and Codex-reviewed). Deployment trigger: **significantly better book numbers**
   — e.g. density-motor admissions or requalified sleeves that materially raise the
   composite — an OWNER call at that time. The midday composition decisions
   (`2026-07-26_book_final22_owner_decisions.md`) remain accepted; only execution timing
   changed.
3. **The Factory-OFF activation window ran the same afternoon instead of the evening**
   (non-T_Live work only): all 8 Codex-approved patches merged (ac2477ca5..6f4c2eebc),
   requeue canary-50 applied (journal
   `D:/QM/reports/state/requeue_canary50_journal_20260726.json`), recovery classifier
   CAS-tagged 1,654 rows (manifest `recovery_class_manifest_20260726.json`, 0 mismatches),
   Q09 re-adjudication enqueued for the confirmed C1 flips, factory restarted, claim
   canary verified (0 recovery claims while 104 frontier rows pending), WS-E1 alarm state
   live.

## Still gated / open

- T_Live maintenance bundle (needs a brief OWNER-present or explicitly authorized terminal
  touch, market closed until Sunday ~23:00 broker): **12778 chart restore** (reboot damage
  to the RATIFIED deployed state — not a book change), KS-baseline deploy (midday „4: ja"),
  swap-rate capture (midday „5: ja"). Recommendation: one 10-minute maintenance session.
- Recency ENFORCEMENT wiring (shadow live now; verdict wiring = separate reviewed change
  per the merged module's design note).
- wse22/wsf2 round-4 micro-review; WS-G terminal phase; new FTMO trial account (OWNER).
