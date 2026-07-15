# Decision: resize the live book to ~10% real max-DD, hard 1%/sleeve cap (Option B)

- Date: 2026-07-15
- Status: accepted (methodology); final table locked in the Saturday v2 admission package with the final sleeve set
- Owner: OWNER (2026-07-15: "optimieren wir auf historisch max. knapp -10%" + "B, kein EA/Strategie/Symbol tradet höher als 1%")
- Supersedes the D2C same-sum 9.75% sizing target for the next book rebuild.

## Rationale (OWNER)

The book was sized so the WORST-CASE-if-all-sleeves-trade-simultaneously summed risk = 9.75%,
which left the REALIZED historical max-DD at only ~3.5% (the sleeves never all trade at once — a
decorrelated, multi-session, multi-timeframe design). That is under-levered. Resize so the
realized historical combined-equity max-DD approaches ~10%, accepting the all-simultaneous tail
(which never occurred historically) — bounded by the account-kill limits.

## Hard limits (DXZ, account-kill if breached)

- Daily DD 5% · Total DD 20%. The all-simultaneous tail (theoretical single day where every
  sleeve stops out = the summed sleeve risk) MUST stay <= 20%: a single such day exceeding 20%
  is account death, not a drawdown. This is the binding tail constraint, not just an accepted risk.

## Sizing method (ratified)

1. Inverse-vol weights over daily net-of-cost PnL (the book's own weighting).
2. **Hard per-sleeve cap: RISK_PERCENT <= 1.0%** — no EA/strategy/symbol ever trades a single idea
   above 1% risk-per-trade (OWNER, universal rule). Capped sleeves' excess redistributes pro-rata
   (by inverse-vol) to uncapped sleeves.
3. Scale the capped allocation up to the target summed risk, bounded by:
   `max( realized max-DD ) ~= 9.7% (just under OWNER's 10%)`, AND worst historical day <= ~4%
   (margin under the 5% daily-kill), AND all-simultaneous tail <= 20% (total-kill).
4. RISK_FIXED for backtest, RISK_PERCENT for live (unchanged).

## Computed result — current 23-sleeve book (2026-07-15, real streams, 1861 days)

| Policy | sum-risk | realized max-DD | worst day | all-simultaneous tail | sleeves at 1% cap |
|---|---|---|---|---|---|
| current (D2C) | 9.75% | 3.55% | -0.76% | 9.75% | (some) |
| **resized (Option B)** | **19.62%** | **9.70%** | **-1.91%** | **19.62%** | **12 / 23** |

- Binding = the ~10% max-DD target; tail lands at 19.62% (under the 20% kill with margin); worst
  day -1.91% has a 3.1-point buffer under the 5% daily-kill.
- Note the cap RAISES DD vs an uncapped 2.05x (7.3%): capping the low-vol commodity sleeves at 1%
  forces weight onto higher-vol sleeves. This is the deliberate OWNER trade-off (no concentration
  > 1% per idea), accepted.
- ~2x return vs current. Machine table: `D:\QM\reports\book_resize_2026-07-15\resize_B_final.json`.

## Application

- The FINAL RISK_PERCENT table is recomputed in the Saturday v2 admission package with the FINAL
  admitted sleeve set (current 23 + any of 1567/12474/13117/Balke/etc. that pass by then), same
  method, and shown to OWNER before the Sunday cutover.
- Sunday cutover applies via LIVE presets (ENV=live, RISK_PERCENT per table, RISK_FIXED=0), SHA
  verification, magic-registry check, flat-moment chart session. AutoTrading toggle = OWNER/Claude.
