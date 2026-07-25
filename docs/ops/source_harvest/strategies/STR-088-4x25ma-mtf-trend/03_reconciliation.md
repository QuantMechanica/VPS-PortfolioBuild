# STR-088 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements

H4 execution cadence; EMA(25, close) on M15/H1/H4/D1, all closed bars,
strict inequality (equality = no setup); confirmation depth N default 1
(sweep {2,3} — "closed bars(1-3)" is a source range); ATR(14, H4)
flagged interpretation (author names no ATR TF); SL 2×ATR, TP 3×ATR
(4× = labeled variant, no continuous optimization); market entry on the
new H4 bar; one position; no trailing/opposite/time exits, no spread
veto (prior QM5_10038's percentile-ATR gate, spread veto,
opposite-stack exit, 20-bar time exit stay excluded per ledger).

## Resolved differences

1. **Session window.** Claude: fixed UTC 07-21 (flagged provisional).
   Codex I-05: calendar-aware London-open→NY-close, no hard-coded
   year-round hours, fail closed if unresolvable. The events ARE
   DST-dependent (London open = 08:00 UK local; NY close = 17:00 New
   York local; UK and US DST switch on different dates). Tie-breaks
   2+3 → **codex adopted**, concretized: entries permitted from 08:00
   UK-local to 17:00 NY-local, both derived in-EA via the QM_DSTAware
   helper patterns (UK helper per QM5_20119 precedent, US helper
   native). Management runs 24h.
2. **MTF synchronization.** Codex I-03 (newest bar closed at the H4
   decision time per TF; missing/stale series invalidates the decision)
   is the rigorous formulation of Claude's intent → **codex adopted**.
3. **Cohort.** Claude: EURUSD/GBPUSD. Codex: ledger cohort "FX majors
   + JPY crosses". Final: **EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX**
   (test-design triple; author names no pair — flagged).
4. **Re-entry.** Both allow re-entry when flat while alignment persists
   (codex I-07: no episode lock is sourced) → adopted as stated.

## Outcome

Final spec = codex 02 with the session anchors concretized (08:00 UK /
17:00 NY local) and the 3-symbol cohort. No escalation.
