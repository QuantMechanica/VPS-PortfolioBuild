---
strategy_id: FMR-MOMTS-2010_XAU_XAG_S02
source_id: FMR-MOMTS-2010
ea_id: QM5_20050
slug: xauxag-xmom12
status: APPROVED
created: 2026-07-23
created_by: Research
last_updated: 2026-07-23
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Fuertes, Ana-Maria; Miffre, Joelle; and Rallis, Georgios (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "Complete 47-page accepted manuscript; momentum construction pp. 6-7 and 17-18, diversification pp. 21-22, robustness pp. 22-29; DOI https://doi.org/10.1016/j.jbankfin.2010.04.009"
    quality_tier: A
    role: primary
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20050_XAU_XAG_XMOM12_D1
period: D1
expected_trade_frequency: "One XAU/XAG cross-sectional-momentum package per broker month after 13 completed month-end closes; approximately 12 packages/year before Q02 validation."
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
review_focus: "Falsify a narrow two-metal translation of source cross-sectional commodity momentum; no profitability, neutrality, or book-correlation claim is imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, low_frequency, narrow_cross_section]
g0_approval_reasoning: "OWNER commodity-sleeve mission authorizes the build. R1 PASS peer-reviewed JBF paper and complete accepted manuscript in an institutional repository; R2 PASS locked prior-12-completed-month arithmetic-average return rank, monthly high-minus-low package, equal fixed risk, ATR stops, restart guard, and orphan cleanup; R3 PASS native registered XAU/XAG D1 data; R4 PASS no ML, banned indicator, external feed, grid, martingale, or pyramiding. Exact dedup CLEAN; same-source energy-momcarry fuzzy match manually rejected because it is XTI/XNG one-month momentum plus swap agreement, while this is XAU/XAG unconditional 12-month momentum."
---

# XAU/XAG Monthly 12-Month Cross-Sectional Momentum

## Hypothesis

Slow diffusion of commodity supply, demand, and hedging shocks can make relative
performance persist. Each month this card buys the stronger of gold and silver
over the prior twelve completed broker months and shorts the weaker metal.
Opposite legs reduce common precious-metal direction, but market neutrality and
low correlation to the certified book remain claims for later gates to test.

## Source And Evidence Boundary

Fuertes, Miffre, and Rallis (2010), *Journal of Banking & Finance* 34(10),
tests cross-sectional commodity-futures momentum with 1-, 3-, and 12-month
formation windows and a one-month hold. The complete accepted manuscript and
appendices are recorded in `strategy-seeds/sources/FMR-MOMTS-2010/source.md`.
The source uses a broad collateralized futures universe. This card narrows it
to two continuous broker CFDs and omits futures curves; it is a carrier
falsification, not a replication. No source return, Sharpe, drawdown,
correlation, or cost statistic is imported.

## Concept And Formula

On the first tradable host D1 bar of month `t`, collect the last close from
each of the 13 consecutive completed broker months ending at `t-1`:

```text
r_i[m]  = month_close_i[m] / month_close_i[m-1] - 1
avg12_i = sum(r_i[m], m=1..12) / 12
```

- `avg12_XAU > avg12_XAG`: BUY XAU, SELL XAG.
- `avg12_XAU < avg12_XAG`: SELL XAU, BUY XAG.
- Tie, missing month, invalid close, or nonfinite result: remain flat.

There is no ratio, z-score, mean reversion, breakout, quantile solver, RSI,
carry proxy, trend overlay, or adaptive parameter.

## Markets And Timeframe

- Logical basket: `QM5_20050_XAU_XAG_XMOM12_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1; second leg/slot 1: `XAGUSD.DWX`.
- Rebalance: first tradable D1 bar of every broker month.
- Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, weight 1; split risk equally.
- Runtime data: native MT5 D1 closes, ATR, spread, calendar, deals, positions,
  and contract metadata only.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. Anything not stated is out of scope.

## 4. Entry Rules

- Require exact XAU D1 host, magic slot 0, and 13 consecutive completed months.
- Calculate exactly twelve simple monthly returns and their arithmetic mean.
- Buy the higher average-return leg and short the lower; reject differences
  at or below `1e-10`.
- Reject invalid history, ATR, price, lot, spread, magic, existing-package, or
  already-attempted-month state.
- Scan positions and entry deals so restart or a stopped leg cannot re-enter.
- Split package risk equally; attach frozen `ATR(20) * 3.5` hard stops. If the
  second order fails, flatten the first immediately.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month.
- Close after 40 calendar days as a stale guard.
- Flatten an orphan or malformed package immediately.
- Friday close is disabled to preserve the monthly source hold.

## 6. Filters (No-Trade Module)

Framework kill switch remains authoritative. Host, window, history continuity,
finite arithmetic, spread, ATR, lot, magic, package, and attempt guards fail
closed. Q02 disables news axes; no external calendar is required.

## 7. Trade Management Rules

Exactly two opposite legs, equal fixed-risk halves, and at most one package per
month. No TP, trail, partial close, scale-in, grid, martingale, pyramiding,
external feed, futures chain, banned indicator, adaptive fit, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_return_window_months` | 12 | locked | completed monthly returns |
| `strategy_history_bars` | 500 | [400, 500, 600] | D1 retrieval buffer only |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen stop distance |
| `strategy_max_hold_days` | 40 | locked | stale guard |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XAU spread cap (legacy input name) |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XAG spread cap (legacy input name) |
| `strategy_deviation_points` | 20 | [10, 20, 50] | order deviation |

## Author Claim

The paper supports the existence and mechanical definition of cross-sectional
commodity momentum. It does not claim that a two-metal CFD subset is profitable.

## Risk And Kill Criteria

Retire below five completed packages/year or on nonpositive Q02 economics,
nondeterminism, invalid basket accounting, persistent orphan exposure, missing
history, or risk mismatch. Two-name concentration, metal co-movement, CFD basis,
financing, gaps, legging, and costs are binding falsification risks.

## Strategy Allowability Check

- [x] Reputable peer-reviewed source, fully reviewed and durably approved.
- [x] Deterministic structural D1/monthly rule with expected density >=5/year.
- [x] Native data only; no banned indicator, external feed, or ML.
- [x] RISK_FIXED backtest only; no live artifact or portfolio mutation.
- [x] Exact dedup clean; fuzzy match manually resolved by carrier and mechanic.

## Non-Duplicate Decision

`QM5_12577` is ratio z-score reversion, `QM5_12724` ratio breakout,
`QM5_12862` return-spread reversion, `QM5_13205` conditional-quantile reversion,
and `QM5_20012` conditional mean-threshold reversion. `QM5_12733` is XTI/XNG
momentum, not a precious-metals carrier. No existing XAU/XAG build ranks twelve
completed monthly returns and holds the winner-minus-loser package for a month.

## Framework Alignment

- no_trade: host/window/history/spread/ATR/lot/magic/package/attempt guards.
- trade_entry: monthly 12-return rank, paired orders, equal risk, hard stops.
- trade_management: month/time exit, restart guard, orphan cleanup.
- trade_close: framework close helper plus broker hard stops.

No T_Live, AutoTrading, live setfile, deploy manifest, portfolio gate, or
portfolio admission is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-23 | initial XAU/XAG 12-month momentum basket | Q02 | DRAFT_DEFECT: zero trades |
| v1.1 | 2026-07-23 | align history-buffer guard with approved 400-600 range; economics unchanged | Q01 | strict compile PASS; Q02 rerun deferred at CPU ceiling |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-23 | APPROVED under OWNER mission; R1-R4 PASS | this card |
| Q01 Build Validation | 2026-07-23 | PASS - strict compile 0 errors/0 warnings; build checks PASS | `docs/ops/evidence/2026-07-23_qm5_20050_xauxag_xmom12_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-23 | DRAFT_DEFECT: zero trades; repaired rerun deferred at CPU ceiling | work item `8a36f351-f5de-40fe-acfc-4b46aff0a4a2`; `docs/ops/evidence/2026-07-23_qm5_20050_zero_trades_recovery.md` |
