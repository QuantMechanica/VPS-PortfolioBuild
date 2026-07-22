---
strategy_id: FMR-MOMTS-2010_XTI_XNG_S03
source_id: FMR-MOMTS-2010
ea_id: QM5_20051
slug: energy-xmom1
status: APPROVED
created: 2026-07-23
created_by: Research+Development
last_updated: 2026-07-23
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Fuertes, Miffre, and Rallis (2010), Tactical Allocation in Commodity Futures Markets, Journal of Banking & Finance 34(10), 2530-2548."
    location: "Complete accepted manuscript; momentum construction pp. 6-7 and 17-18; DOI 10.1016/j.jbankfin.2010.04.009"
    quality_tier: A
    role: primary
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20051_XTI_XNG_XMOM1_D1
period: D1
expected_trade_frequency: "One two-leg package per broker month; approximately 12 packages/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
g0_approval_reasoning: "OWNER commodity-sleeve mission authorizes the build. R1 peer-reviewed source and complete approved manuscript; R2 locked prior-completed-month return rank, monthly paired hold, equal fixed risk and ATR stops; R3 registered native XTI/XNG D1 data; R4 no ML, banned indicator, external feed, grid or martingale."
---

# XTI/XNG One-Month Cross-Sectional Momentum

## Hypothesis

Energy supply and hedging shocks may diffuse across crude oil and natural gas at different speeds. On the first tradable D1 bar of each month, buy the energy contract with the stronger immediately completed monthly return and short the weaker one. The paired carrier removes most broad USD/commodity direction and is structurally different from the certified XNG RSI pullback.

## Source And Evidence Boundary

Fuertes, Miffre, and Rallis (2010) test commodity-futures cross-sectional momentum with one-, three-, and twelve-month formation windows and a one-month hold. The complete accepted manuscript was reviewed in `strategy-seeds/sources/FMR-MOMTS-2010/source.md`. This two-CFD package is a narrow carrier falsification, not a replication; no source performance or correlation statistic is imported.

## Rules

### Entry Rules

- Host `XTIUSD.DWX` D1, slot 0; second leg `XNGUSD.DWX`, slot 1.
- On the first tradable D1 bar of a broker month, reconstruct the last closes of the two immediately completed consecutive broker months.
- Compute `r = newer_close / older_close - 1` for each leg.
- Buy the higher-return leg and sell the lower-return leg; stand down on ties within `1e-10`, missing months, invalid data, spread, ATR, lot, magic, existing-package, or prior-attempt state.
- Split `RISK_FIXED=1000` equally and freeze a `3.5 * ATR(20,D1)` hard stop on each leg. Flatten the first leg if the second order fails.

### Exit Rules

- Close both legs at the first tradable D1 bar of the next broker month.
- Close after 40 calendar days or immediately on an orphan/malformed package.
- Friday close is disabled to preserve the monthly holding period.

## Filters And Trade Management

Framework kill switch remains authoritative. At most one opposite-leg package may exist per month. There is no target, trail, scale-in, grid, martingale, pyramiding, external feed, futures curve, oscillator, adaptive fit, or ML.

## Parameters To Test

| parameter | default | authorized range |
|---|---:|---|
| `strategy_return_window_months` | 1 | locked |
| `strategy_history_bars` | 1200 | [900, 1200, 1600] |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] |
| `strategy_max_hold_days` | 40 | locked |

## Risk

The paper supports the rule family, not profitability of this pair. Retire below five packages/year, on nonpositive governed Q02 economics, nondeterminism, invalid basket accounting, persistent orphan exposure, or risk mismatch. CFD basis, energy-sector divergence, financing, gaps, legging and costs are binding risks.

## Strategy Allowability Check

- [x] Reputable peer-reviewed source, fully reviewed and durably approved.
- [x] Deterministic structural monthly rule with expected density above five/year.
- [x] Native data and RISK_FIXED backtest only; no banned indicator or ML.
- [x] Exact dedup clean; fuzzy siblings manually resolved.

## Non-Duplicate Decision

`QM5_13126_energy-momcarry` requires independent broker-swap/carry agreement; this rule is unconditional one-month momentum. `QM5_12733_xti-xng-xmom` uses 63-252 D1 lookbacks (default 126), a return-spread neutral band and Friday close; it does not implement a single completed broker month. `QM5_12567` is single-symbol cumulative-RSI2 mean reversion.

## Framework Alignment

- no_trade: host, locked parameter, history, spread, ATR, lot, magic, package and attempt guards.
- trade_entry: completed-month rank, paired orders, equal fixed risk and hard stops.
- trade_management: month/time exit and orphan cleanup.
- trade_close: framework helper and broker hard stops.

No T_Live, AutoTrading, live setfile, deploy manifest, portfolio gate or portfolio admission is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-23 | initial energy one-month momentum basket | Q02 | Q01 PASS; Q02 ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-23 | APPROVED; R1-R4 PASS | this card |
| Q01 Build Validation | 2026-07-23 | PASS - strict compile 0 errors/0 warnings | `docs/ops/evidence/2026-07-23_qm5_20051_energy_xmom1_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-23 | ENQUEUED as one logical basket | work item `448f4edd` |
