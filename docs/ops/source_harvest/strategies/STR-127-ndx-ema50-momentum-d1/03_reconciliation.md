# STR-127 — Spec reconciliation (Claude 01 vs Codex 02)

Date: 2026-07-25. Tie-breaks per tranche protocol.

## Agreements (near-total convergence)

NDX.DWX D1; EMA(50, close) regime on the closed bar; one stop order at
the signal bar's extreme with SL at its opposite extreme, REPLACED at
every D1 close (no ladder — the source's "do the same tomorrow" under
the house no-stacking rule, FLAG-127-01, both specs identical);
cancel on regime flip; equality → cancel-and-flat (codex FLAG-127-02);
after fill: no new pendings, EMA flip does NOT close the position;
exit at the FIRST directionally profitable D1 close vs actual fill
(gross, FLAG-127-04), same-day close eligible (FLAG-127-05); no TP, no
time exit (FLAG-127-06); the later EMA-less/ATR-sizing forum variants
excluded.

## Resolved differences

1. **Gap handling.** Claude: unaddressed. Codex FLAG-127-03: live
   pendings keep real stop-order semantics through gaps; a newly
   calculated level already crossed at placement time → market-
   equivalent fill only with auditable next-tick pricing, else skip
   the signal; never backfill → **codex adopted**.
2. **Blackout interaction.** Codex: a blackout invalidating the
   pending's window removes the pending and consumes that D1 signal →
   adopted.

## Outcome

Final spec = codex 02 unchanged. The author's own structural critique
(negative R:R geometry, ~40% drawdowns) is recorded in the card R1 as
the explicit test hypothesis. No escalation.
