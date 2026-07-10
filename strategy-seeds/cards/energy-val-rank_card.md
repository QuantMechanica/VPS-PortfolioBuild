---
strategy_id: AMP-VALUE-2013_XTI_XNG_S01
source_id: AMP-VALUE-2013
ea_id: QM5_13123
slug: energy-val-rank
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Asness, Moskowitz, and Pedersen (2013), Value and Momentum Everywhere, The Journal of Finance 68(3), 929-985, DOI 10.1111/jofi.12021."
source_citations:
  - type: peer_reviewed_paper
    citation: "Asness, Clifford S.; Moskowitz, Tobias J.; and Pedersen, Lasse Heje (2013). Value and Momentum Everywhere. The Journal of Finance 68(3), 929-985."
    location: "Section I.A.5 and I.B-I.D, especially pp. 935-939; Table I Panel B pp. 943-945; Sections V-VI pp. 975-982; DOI https://doi.org/10.1111/jofi.12021"
    quality_tier: A
    role: primary
  - type: paper_supplement
    citation: "Asness, Clifford S.; Moskowitz, Tobias J.; and Pedersen, Lasse Heje (2013). Internet Appendix for Value and Momentum Everywhere."
    location: "Tables IA.I-IA.VIII; supporting information DOI 10.1111/jofi.12025"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/AMP-VALUE-2013]]"
concepts:
  - "[[concepts/commodity-value]]"
  - "[[concepts/energy-relative-value]]"
  - "[[concepts/cross-sectional-ranking]]"
indicators:
  - "[[indicators/long-horizon-price-ratio]]"
  - "[[indicators/atr]]"
strategy_type_flags: [atr-hard-stop, time-stop, symmetric-long-short]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [commodities, energy, crude_oil, natural_gas]
single_symbol_only: false
logical_symbol: QM5_13123_ENERGY_VALUE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "One paired package per broker month after the 66-month warm-up; approximately 12 completed packages/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds a source-backed long-horizon commodity-value driver to the XAU/SP500/NDX/XNG book. Paired XTI/XNG exposure reduces common energy direction by construction, but realized portfolio orthogonality remains unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_spot_proxy, narrow_cross_section, long_history]
g0_approval_reasoning: "OWNER mission 2026-07-10: R1 peer-reviewed Journal of Finance paper plus Internet Appendix and explicit WTI/natural-gas universe; R2 locked 54-66-month price anchor, two-leg value rank, monthly renewal, and deterministic exits; R3 registered XTI/XNG D1 with explicit long-history falsification risk; R4 no ML/banned/external/grid/martingale; pre-allocation dedup CLEAN."
---

# XTI/XNG Long-Horizon Commodity Value Rank

## Hypothesis

Commodity prices can overshoot over multi-year horizons. The source defines a
commodity as cheap when its current spot price is low relative to its average
spot price 4.5 to 5.5 years earlier, then earns the value spread by buying the
cheaper cross-sectional names and selling the more expensive names.

This card applies that structural signal to a paired XTI/XNG carrier. Opposite
positions reduce common energy direction, but the basket is not guaranteed
beta neutral or portfolio-uncorrelated. Q09 must measure orthogonality from a
surviving return stream.

## Source And Evidence Boundary

The primary source is Asness, Moskowitz, and Pedersen (2013), *The Journal of
Finance* 68(3), DOI `10.1111/jofi.12021`. The complete 57-page paper and its
11-page Internet Appendix were read end to end.

The paper uses 27 rolled commodity futures, including WTI crude and natural
gas, and monthly futures excess returns. Its signal uses spot prices, while
this card uses completed Darwinex CFD D1 closes as the only available native
spot proxy. The source's broad-universe returns, collateral, contract rolls,
rank weights, and transaction costs are not claims for this two-CFD carrier.

## Concept And Non-Duplicate Decision

On the first tradable `XTIUSD.DWX` D1 bar of each broker month:

1. Select the latest completed month-end D1 close for each leg.
2. Select the completed month-end D1 close at each inclusive lag from 54
   through 66 months and average the 13 anchors for each leg.
3. Compute `value = ln(anchor_average / latest_completed_close)`.
4. Buy the higher-value leg and sell the lower-value leg for one month.

This is mechanically distinct from six-month and 52-week reversal, raw
XTI/XNG momentum, return-spread z-score reversion, carry, same-calendar
seasonality, skewness, momentum/reversal disagreement, and trend-confirmed
momentum. It contains no RSI and is not `QM5_12567`.

It also differs from `QM5_12919_amp-value-momentum-xasset`: that EA combines
12-month momentum and 60-month value in an eight-instrument index/FX
long-only rank and explicitly excludes commodity legs. This card is pure
commodity value, a two-leg long-short package, and uses the source's stated
4.5-5.5-year anchor average rather than one 60-month endpoint.

## Rules

- Reconstruct completed month-end endpoints only; never use the current
  forming month.
- Average the inclusive 54-66-month anchors and rank
  `ln(anchor_mean/latest_close)` across XTI and XNG.
- Buy the higher-value leg, sell the lower-value leg, renew monthly, and stay
  flat on a tie or any fail-closed data/risk guard.

## Markets And Timeframe

- Logical basket: `QM5_13123_ENERGY_VALUE_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal cadence: first tradable D1 bar of each broker month.
- Formation: latest completed close plus 13 completed month-end anchors at
  lags 54-66 months; current month is excluded.
- Expected frequency: approximately 12 packages/year after warm-up.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across the legs.
- Runtime data: native MT5 D1 closes, ATR, spread, broker calendar, and
  position state only.

## Entry Rules

- Evaluate only on the first new host D1 bar of a broker month.
- For each leg, select the last valid completed D1 close before the current
  month boundary. Reject an endpoint more than ten calendar days stale.
- For each integer month lag from 54 through 66 inclusive, select the last
  valid completed D1 close before that lagged month boundary.
- Require all 13 anchor endpoints, positive prices, strictly descending
  endpoint timestamps, and no endpoint more than ten calendar days stale.
- Compute the arithmetic mean of the 13 anchor closes.
- Compute `value_score = ln(anchor_mean / latest_completed_close)`.
- Require finite scores and a score difference larger than `1e-12`.
- BUY XTI plus SELL XNG when `value_XTI > value_XNG`.
- SELL XTI plus BUY XNG when `value_XTI < value_XNG`.
- Split the fixed package-risk budget equally across the legs.
- Attach a frozen `ATR(20) * 3.5` hard stop to each leg.
- Do not enter on missing/stale history, invalid arithmetic/ATR/volume,
  excessive spread, an existing package, or a month already attempted.

## Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month,
  before evaluating the renewed value rank.
- Close both legs if the package exceeds `strategy_max_hold_days=35`.
- If either broker hard stop removes one leg, flatten the orphan immediately.
- Flatten any duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source's monthly hold.

## Filters And Trade Management

- Exact host guard: `XTIUSD.DWX`, D1, magic slot 0.
- Locked 54-66-month source window; parameter deviation fails closed.
- One paired package per EA; no same-month retry after an entry attempt.
- Bounded D1 history reads only on the monthly decision path.
- Framework kill switch and entry-only news compliance remain authoritative.
- No take profit, trailing stop, break-even, partial close, scale-in, grid,
  martingale, pyramiding, external data, adaptive fit, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_anchor_near_months` | 54 | [54] | source 4.5-year near boundary |
| `strategy_anchor_far_months` | 66 | [66] | source 5.5-year far boundary |
| `strategy_history_bars` | 1900 | [1800, 1900, 2100] | bounded D1 endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | [7, 10] | stale endpoint guard |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg hard-stop volatility |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The inclusive 54-66-month anchor average, log value score, higher-minus-lower
rank direction, monthly renewal, paired carrier, and no same-month retry are
locked. Replacing the anchor average with a single endpoint, shortening the
horizon, blending momentum, adding an adaptive threshold, or using a
single-leg signal requires a new card.

## Author Claim

The source defines the signal: "For commodities, we define value as the log
of the spot price 5 years ago ... divided by the most recent spot price"
(p. 937). No performance number is imported.

## Initial Risk Profile And Kill Criteria

- `expected_pf: 1.05` is only a conservative queue-ordering prior.
- `expected_dd_pct: 25.0` reflects XNG gaps, legging, financing, and the
  narrow two-asset cross-section.
- Retire at Q02 below five completed packages/year after warm-up.
- Fail on zero trades, missing 66-month history, stale/misordered endpoints,
  non-deterministic reruns, orphan persistence, or risk-mode mismatch.
- Do not shorten the value horizon, substitute recent reversal, blend
  momentum, or widen the universe after a poor baseline.
- Treat the 27-future-to-two-CFD narrowing, CFD spot proxy, financing, and
  futures/CFD basis mismatch as falsification risks, not waiver grounds.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Fixed package risk is split equally across the two ATR-stopped legs.
No live risk mode, deployment, or portfolio admission is part of this card.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed *Journal of Finance* paper with DOI,
  author-hosted full text, Internet Appendix, and explicit source instruments.
- [x] R2 mechanical: fixed completed-window anchor average, log value rank,
  monthly lifecycle, equal fixed-risk split, and ATR hard stops.
- [x] R3 testable: registered `XTIUSD.DWX` and `XNGUSD.DWX` D1 history, with
  long-history sufficiency tested rather than assumed.
- [x] R4 compliant: no banned indicator, ML, external feed, adaptive fit,
  grid, martingale, or pyramiding.
- [x] Frequency prior exceeds the five-trades/year Q02 floor.
- [x] Repository dedup was clean before atomic EA-ID allocation.

## Framework Alignment

- no_trade: exact host/slot, locked source window, bounded completed-window
  history, endpoint freshness/order, arithmetic, spread, ATR, and package
  guards.
- trade_entry: source-defined 54-66-month commodity value score, two-asset
  rank, paired orders, equal fixed-risk allocation, and frozen ATR stops.
- trade_management: monthly reset, 35-day stale close, and orphan/side repair.
- trade_close: framework close helper plus broker-side hard stops.

`hard_rules_at_risk`:

- `basket_execution`: Q02 must evaluate one logical package, not standalone
  component legs.
- `friday_close`: disabled only for the source-aligned monthly hold; monthly
  rollover, stale close, orphan cleanup, and hard stops remain.
- `risk_mode_dual`: only a RISK_FIXED backtest setfile is authorized.
- `cfd_spot_proxy`: completed CFD closes proxy the unavailable spot series.
- `narrow_cross_section`: two energy legs are not the paper's 27-future rank.
- `long_history`: Q02 must expose insufficient 66-month DWX history cleanly.

## Implementation Notes

- target_modules.no_trade: exact XTI/D1/slot and fail-closed parameter,
  history, endpoint, spread, and ATR guards.
- target_modules.entry: bounded month-end reconstruction, 13-endpoint anchor
  average, log score, paired fixed-risk ATR-stopped orders.
- target_modules.management: monthly reset, orphan/side repair, and stale
  close.
- target_modules.close: `QM_TM_ClosePosition` plus broker stops.
- estimated_complexity: medium.
- estimated_test_runtime: one logical XTI/XNG D1 Q02 baseline.
- data_requirements: standard native DWX D1 history only.

No `T_Live`, AutoTrading setting, live setfile, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial source-backed XTI/XNG commodity-value build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `artifacts/qm5_13123_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | ENQUEUED | `docs/ops/evidence/2026-07-10_qm5_13123_energy_value_q02_enqueue.md` |
