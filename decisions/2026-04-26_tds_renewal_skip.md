# Decision: Tick Data Suite renewal — SKIP

- Date: 2026-04-26
- Status: accepted
- Owner: OWNER
- Affected docs: `expenses/PUBLIC_EXPENSE_LOG.md`, `docs/ops/EPISODE_GUIDE.md`, `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md`

## Context

Tick Data Suite license expires ~2026-05-05. Three renewal options on the table:

- Monthly €32.90
- Yearly €189
- Lifetime €549
- (Skip)

Between 2026-04-25 and 2026-04-26 the operations Claude session bulk-exported ~30 V5-relevant symbols (all major FX pairs, indices including UK100/GDAXI/NDX/WS30, metals XAU/XAG, energies XTI/XNG) on T1 with verified US-DST + portable-mode. Total ~500 GB of raw tick CSVs in `D:\QM\reports\setup\tick-data-timezone\`. Per `docs/ops/DWX_IMPORT_AUTOMATION.md`, the hourly automation pipeline ingests these CSVs into `.DWX` custom symbols on T1, then T2-T5 inherit by copying `D:\QM\mt5\T1\Bases\Custom\`.

## Decision

**Skip renewal.** Existing exports cover V5 first-wave needs. Lapse the license at expiry.

## Rationale

1. **Sufficient coverage already in repo.** ~30 symbols across all market classes V5 needs.
2. **DWX import automation is operational.** The hourly cron processes existing CSVs; new EA backtests draw from `.DWX` symbols already on disk. No fresh ticks required for first V5 EA cohort.
3. **Re-buy availability.** TDS license can be re-acquired at any time (€32.90 monthly is the lowest re-entry cost) if fresh exports become needed.
4. **Cash-flow.** Skipping saves €32.90-€549 in Month 1 with low operational risk.

## Triggers To Revisit

Buy a fresh TDS license if any of these happen:

1. V5 needs symbols not already exported (e.g. crypto pairs, specific exotic forex)
2. V5 framework requires tick-level recalibration of slippage / latency JSON beyond what existing CSVs cover
3. Quality-Tech determines that tick freshness materially affects backtest validity (existing exports run through 2026-04-25; older period coverage from V4-era exports)
4. P10 Live Burn-In ever requires tick-level ground truth for KS-test reference distribution beyond the M1 OHLC level

## Alternatives Considered

- **Yearly €189** (best per-month rate). Rejected — V5 first-wave needs are covered. Locking in €189 for capacity not used is wasteful.
- **Lifetime €549** (commit-to-V5). Rejected — premature commitment before V5 has produced a single live EA.
- **Monthly €32.90** (max flexibility). Rejected — even monthly cost is unjustified when current exports are sufficient.

## Consequences

- Tick Data Suite stops working after expiry (~2026-05-05). T1 still has all the exported CSVs.
- DWX import automation continues to function — it doesn't depend on the live TDS service, only on CSVs already on disk.
- Episode Guide EP04 referenced "TDS renewal decision flagged for Month 1" — that decision is now SKIP. Episode content can document the call.
- Public Expense Log line for TDS renewal can be marked `SKIPPED 2026-04-26 — sufficient existing exports`.
- `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md` should reference this ADR in a footnote so future agents know the license-state.

## Sources

- OWNER conversation 2026-04-26 ("5d")
- `D:\QM\reports\setup\tick-data-timezone\` filesystem inventory (~30 symbols, ~500 GB CSV)
- `docs/ops/DWX_IMPORT_AUTOMATION.md` (hourly automation pipeline)
- `docs/ops/EPISODE_GUIDE.md` § EP04
- `expenses/PUBLIC_EXPENSE_LOG.md`
