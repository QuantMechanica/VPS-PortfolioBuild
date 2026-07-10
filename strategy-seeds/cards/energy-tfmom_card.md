---
strategy_id: CLARE-TFMOM-2014_XTI_XNG_S01
source_id: CLARE-TFMOM-2014
ea_id: QM5_13121
slug: energy-tfmom
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Clare, Seaton, Smith, and Thomas (2014), Trend following, risk parity and momentum in commodity futures, International Review of Financial Analysis 31, 1-12, DOI 10.1016/j.irfa.2013.10.001."
source_citations:
  - type: peer_reviewed_paper
    citation: "Clare, Andrew; Seaton, James; Smith, Peter N.; and Thomas, Stephen (2014). Trend following, risk parity and momentum in commodity futures. International Review of Financial Analysis 31, 1-12."
    location: "Sections 2-6; especially 4.1, 4.2, 4.4 and Tables 4, 5, 9; DOI https://doi.org/10.1016/j.irfa.2013.10.001"
    quality_tier: A
    role: primary
sources:
  - "[[sources/CLARE-TFMOM-2014]]"
concepts:
  - "[[concepts/commodity-momentum]]"
  - "[[concepts/trend-confirmation]]"
  - "[[concepts/energy-relative-value]]"
indicators:
  - "[[indicators/monthly-moving-average]]"
  - "[[indicators/realized-volatility]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, cross-sectional-momentum, trend-confirmation, inverse-volatility-weighting, monthly-rebalance, low-frequency]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [commodities, energy, crude_oil, natural_gas]
single_symbol_only: false
logical_symbol: QM5_13121_ENERGY_TFMOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 5-9 eligible paired packages/year after warm-up; retire below five/year at Q02."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Source-backed trend-confirmed energy momentum; realized orthogonality to XAU/SP500/NDX/XNG remains unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, narrow_cross_section]
g0_approval_reasoning: "Mission-directed G0 2026-07-10: R1 peer-reviewed IRFA DOI/full paper and explicit crude-oil/natural-gas source instruments; R2 locked 12-month relative rank, 7-month trend agreement, 60-D1 inverse-volatility weights, and monthly hold; R3 registered XTI/XNG D1; R4 no ML/banned/external/grid/martingale; pre-allocation dedup CLEAN."
---

# XTI/XNG Trend-Filtered Momentum

## Hypothesis

Commodity momentum can suffer large reversals when a relative winner is not in
an absolute uptrend or a loser is not in an absolute downtrend. The source
combines cross-sectional momentum with each instrument's own trend direction
and inverse-volatility weighting. This card tests that structural interaction
in a paired energy carrier: follow the 12-month XTI/XNG winner only when the
winner is above its seven-month mean and the loser below its mean.

Opposite positions reduce common energy direction, but the basket is not
guaranteed beta neutral. Low correlation to the current portfolio is a design
goal only; Q09 must measure it from a surviving return stream.

## Source And Evidence Boundary

The primary source is Clare, Seaton, Smith, and Thomas (2014),
*International Review of Financial Analysis* 31, DOI
`10.1016/j.irfa.2013.10.001`. The complete 12-page paper was read, including
all methods, tables, risk adjustments, costs, conclusions, and references.

The source studies 28 rolled commodity-futures indices. Its combined rule uses
12-month momentum, a 6-12 month trend overlay (with seven months strongest in
the reported comparison), 60-day risk-parity weights, and a one-month hold.
No diversified source performance statistic is a claim for this two-CFD port.

## Concept And Non-Duplicate Decision

On the first tradable `XTIUSD.DWX` D1 bar of each broker month:

1. Reconstruct synchronized completed month-end closes for XTI and XNG.
2. Rank both legs by their 12-completed-month log returns.
3. Compute each leg's mean of the latest seven completed month-end closes.
4. Trade only when the winner is above its own mean and the loser below its own
   mean.
5. Divide the fixed risk budget using 60-D1 inverse-volatility weights.

This is mechanically distinct from raw relative momentum (`QM5_12733`),
return-spread reversion (`QM5_12840`), carry (`QM5_13089`), momentum plus
idiosyncratic volatility (`QM5_13113`), same-calendar ranking (`QM5_13115`),
skewness (`QM5_13118`), and 12/18-month momentum-reversal disagreement
(`QM5_13120`). It contains no RSI and is not `QM5_12567`.

## Markets And Timeframe

- Logical basket: `QM5_13121_ENERGY_TFMOM_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal cadence: first tradable D1 bar of each broker month.
- Formation: completed month-end closes only; current month is excluded.
- Expected frequency: approximately 5-9 packages/year after warm-up.
- Q02 floor: retire below five completed packages/year.
- Runtime data: native MT5 D1 closes, ATR, spread, calendar, and position state.

## Entry Rules

- Evaluate only on the first new host D1 bar of a broker month.
- For each leg, select the last valid completed D1 close before the current
  broker-month boundary and before the boundary 12 months earlier.
- Reject an endpoint more than ten calendar days before its boundary.
- Compute `mom12 = ln(latest_completed_close / close_12_months_back)`.
- Winner is the leg with higher `mom12`; exact numerical ties stay flat.
- For each leg, select the last completed D1 close before each of the latest
  seven month boundaries and compute their arithmetic mean.
- Require the winner's latest close strictly above its mean and the loser's
  latest close strictly below its mean. Otherwise stay flat for that month.
- Compute the standard deviation of the latest 60 completed D1 log returns for
  each leg. Require finite, strictly positive variance.
- Allocate risk by `inverse_vol_leg / sum(inverse_vol_both_legs)`.
- BUY XTI plus SELL XNG when XTI is the confirmed winner.
- SELL XTI plus BUY XNG when XNG is the confirmed winner.
- Attach a frozen `ATR(20) * 3.5` hard stop to each leg.
- Do not enter on missing history, invalid arithmetic/ATR/volume, excess
  spread, an existing package, or a month already attempted.

## Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs when calendar hold exceeds 35 days.
- If either stop removes one leg, flatten the orphan immediately.
- Flatten any duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source's one-month hold.

## Trade Management And Filters

- Exact host guard: XTIUSD.DWX, D1, magic slot 0.
- One package per EA; no same-month retry after a completed entry.
- One bounded 450-bar history read per leg on the monthly signal path.
- Framework kill switch and entry-only news compliance remain authoritative.
- No take profit, trailing stop, break-even, partial close, scale-in, grid,
  martingale, pyramiding, external data, adaptive fit, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_momentum_months` | 12 | [12] | source formation rank |
| `strategy_trend_months` | 7 | [7] | selected source trend overlay |
| `strategy_volatility_days` | 60 | [60] | source risk-parity window |
| `strategy_history_bars` | 450 | [360, 450, 520] | bounded endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | [7, 10] | stale endpoint guard |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | hard-stop volatility |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | order deviation |

The 12-month rank, seven-month per-leg trend agreement, 60-day inverse-
volatility weighting, monthly renewal, paired carrier, and no same-month
re-entry are locked. Changing any of them requires a new card.

## Author Claim

The source says: "The addition of trend following to a momentum strategy
reduces the downside risk" (Section 4.4). No return figure is imported.

## Initial Risk Profile And Kill Criteria

- `expected_pf: 1.05` is only a conservative queue prior.
- `expected_dd_pct: 25.0` reflects XNG gaps, legging, and narrow-universe risk.
- Fail Q02 on fewer than five completed packages/year, zero trades, invalid
  endpoint construction, nondeterminism, orphan persistence, or risk mismatch.
- Do not loosen the trend confirmation, shorten the momentum horizon, widen
  the universe, or add a directional filter after a poor baseline.
- Treat the 28-future-to-two-CFD narrowing and futures/CFD basis mismatch as
  falsification risks, not waiver grounds.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed IRFA paper with DOI and full text.
- [x] R2 mechanical: fixed rank, trend, weighting, monthly lifecycle, stops.
- [x] R3 testable: registered XTIUSD.DWX and XNGUSD.DWX D1 history.
- [x] R4 compliant: no banned indicator, ML, external feed, grid, martingale.
- [x] Frequency prior meets the five-trades/year Q02 floor.
- [x] Repository dedup was clean before atomic ID allocation.

## Framework Alignment

- no_trade: exact host/slot, locked parameters, bounded completed-window
  history, endpoint freshness, arithmetic, variance, spread, ATR, and package
  guards.
- trade_entry: 12-month relative winner plus two-sided seven-month trend
  agreement, paired orders, inverse-volatility fixed-risk allocation, and
  frozen ATR stops.
- trade_management: monthly reset, 35-day stale close, and orphan/side repair.
- trade_close: framework close helper plus broker-side hard stops.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. No `T_Live`, AutoTrading, live setfile, deploy manifest, portfolio
gate, or admission artifact is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial source-backed XTI/XNG trend-momentum build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `artifacts/qm5_13121_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | ENQUEUED | `docs/ops/evidence/2026-07-10_qm5_13121_energy_tfmom_q02_enqueue.md` |
