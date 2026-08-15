---
card_schema_version: 2
type: strategy
strategy_id: CHAN-EIA-USGS-WTI-XCU-CADF-2026_S01
variant_id: CHAN-EIA-USGS-WTI-XCU-CADF-2026_S01
source_id: CHAN-EIA-USGS-WTI-XCU-CADF-2026
ea_id: QM5_21525
slug: wti-xcu-cadf
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21525_wti-xcu-cadf_card.md
execution_contract_status: APPROVED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-15
g0_status: APPROVED
source_author: "Ernest P. Chan; U.S. Energy Information Administration; CME Group; U.S. Geological Survey"
source_authors: "Ernest P. Chan; U.S. Energy Information Administration; CME Group; U.S. Geological Survey"
source_citation: "Chan (2009), Quantitative Trading, Wiley, Examples 3.6, 7.2, 7.3, 7.5; official EIA crude-oil driver, CME Copper Futures, and USGS Copper Statistics references."
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading."
    location: "ISBN 978-0-470-28488-9; complete bounded extraction strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md"
    quality_tier: A
    role: ols_cadf_spread_reversion_and_half_life_method
  - type: government_explainer
    citation: "U.S. Energy Information Administration. What drives crude oil prices: Spot Prices."
    location: "governed packet strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-BRK-2026/source.md"
    quality_tier: A
    role: physical_crude_oil_driver_context
  - type: exchange_reference
    citation: "CME Group. Copper Futures."
    location: "governed packet strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-BRK-2026/source.md"
    quality_tier: A
    role: benchmark_copper_carrier
  - type: government_reference
    citation: "U.S. Geological Survey. Copper Statistics and Information."
    location: "governed packet strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-BRK-2026/source.md"
    quality_tier: A
    role: industrial_base_metal_context
strategy_mechanic: rolling-252d-log-wti-on-copper-ols-residual-cadf-qualified-fresh-cross-reversion-two-leg-basket
sources:
  - "[[sources/CHAN-EIA-USGS-WTI-XCU-CADF-2026]]"
concepts:
  - "[[concepts/cointegration-pair-trade]]"
  - "[[concepts/energy-base-metal-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/ordinary-least-squares]]"
  - "[[indicators/cadf-residual-gate]]"
  - "[[indicators/residual-zscore]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, base-metal, relative-value, market-neutral-basket, cointegration-filter, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, base_metals]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_21525_WTI_XCU_CADF_D1
symbol: QM5_21525_WTI_XCU_CADF_D1
symbol_slot: 0
magic: 215250000
companion_symbol_slot: 1
companion_magic: 215250001
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to twelve completed two-leg packages per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a CADF-qualified WTI/copper price-level residual fade that removes some common commodity direction; Q09 alone may establish realized decorrelation from the XAU/SP500/NDX/XNG book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_completed_history, ols_singularity, cadf_proxy, aggregate_fixed_risk, beta_weighted_shares, fresh_crossing, magic_schema, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-15_qm5_21525_wti_xcu_cadf_g0.md after durable source approval at commit a16a01823: R1 complete CEO-ratified Wiley extraction plus governed official EIA/CME/USGS carrier evidence; R2 locked synchronized 252-D1 OLS, simple residual CADF proxy, beta/half-life bounds, fresh crossing, paired fade, aggregate fixed risk, stops, convergence/model/stale exits, and atomic repair; R3 registered WTI/copper routes; R4 deterministic native arithmetic only. Canonical dedup CLEAN across 4,397 registry rows and 493 root cards; same-pair return spread, channel, monthly momentum, oil/gas ECM, precious-metal OLS, and XNG oscillator families were manually separated."
---

# QM5_21525 WTI/Copper CADF Residual Reversion

## Hypothesis

WTI crude and copper both respond to global activity and broad commodity/USD
conditions, while their physical supply chains and shock sensitivities differ.
When a synchronized log-price relationship is statistically qualified as
mean-reverting, a fresh residual displacement may partially converge. The EA
fades that displacement with opposite WTI and copper legs instead of adding
another outright index, metal, or natural-gas position.

The card does not assert permanent cointegration or neutrality. The
stationarity gate is recalculated from broker CFD history and can fail closed.
Opposite sides and beta-weighted stop-risk shares do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns density and
economics; Q09 alone owns realized book correlation.

## Source Traceability And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/CHAN-EIA-USGS-WTI-XCU-CADF-2026/source.md`. Chan's
complete bounded extraction supplies OLS hedge fitting, a CADF qualification,
standardized spread fading, a mean-band exit, and mean-reversion-speed
discipline. The official EIA/CME/USGS packet establishes WTI and copper as
distinct physical commodity carriers.

Chan tests GLD/GDX, not WTI/copper. The official sources do not test a trading
rule or establish cointegration. This card uses Darwinex continuous CFDs, a
rolling synchronized fit, a simple one-lag residual CADF proxy, fixed model
bounds, ATR stops, spread caps, and package repair. No source coefficient,
return, Sharpe ratio, significance, drawdown, trade count, transaction cost,
neutrality, decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The canonical checker returned `CLEAN` for the slug, strategy ID, authors, and
complete mechanic across 4,397 registry rows and 493 root cards. Manual review
fixes the boundary:

- `QM5_13090_xti-xcu-rspread` fades a short-window D1 return difference. It
  never fits price levels or requires a residual stationarity test.
- `QM5_13094_xti-xcu-brk` follows a price-level channel. This card fades an
  OLS residual after a fresh standardized crossing.
- `QM5_21524_wti-xcu-relmom` follows a twelve-completed-month relative rank
  and renews monthly. This card evaluates daily residual convergence.
- `QM5_20237_xtixng-ecm-rv` models XNG on XTI with a deterministic trend under
  oil/gas-specific sources. This card models WTI on copper without a trend and
  requires the locked CADF proxy.
- `QM5_20161_xauxag-ols-rv` is a precious-metals carrier and does not express
  energy versus industrial base metal.
- `QM5_12567_cum-rsi2-commodity` is a long-only short-horizon XNG pullback.

The WTI/copper carrier, log orientation, 252-observation OLS, simple CADF
proxy, critical boundary, beta and half-life gates, fresh-cross direction, and
atomic lifecycle are jointly load-bearing. Verdict:
`CLEAN_WTI_COPPER_CADF_RESIDUAL_REVERSION_PACKAGE`.

## Markets, Timeframe, And Formula

- Logical basket: `QM5_21525_WTI_XCU_CADF_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `215250000`.
- Companion/traded slot 1: `XCUUSD.DWX`, D1, magic `215250001`.
- Decision: first processed tick of each new WTI D1 bar.
- Formation: exactly 252 synchronized completed D1 closes.

```text
y_i = log(WTI_i)
x_i = log(copper_i)
y_i = alpha + beta*x_i + residual_i

delta_residual_i = intercept_adf + rho*residual_(i-1) + error_i
phi = 1 + rho
half_life = -log(2) / log(phi)

z_now  = residual_newest / sqrt(SSE_ols / 250)
z_prev = residual_previous / sqrt(SSE_ols / 250)
```

The model is admissible only for `beta` in `[0.10,3.00]`, `rho<0`,
`t_rho<=-3.043`, `0<phi<1`, and half-life in `[2,60]` D1 observations.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. No signal or execution parameter sweep is authorized.

## 4. Entry Rules

1. Require exact EA ID `21525`, `XTIUSD.DWX` D1 host, slot 0, both registered
   magics, fixed-risk mode, and every locked input.
2. Process malformed-package repair and lifecycle exits before entry-only
   gates. Evaluate entry only on a genuine new host D1 bar with no owned leg.
3. Load exactly 252 synchronized completed WTI and copper closes. Require
   identical timestamps, strict chronology, positive finite prices, and a
   newest endpoint no more than ten calendar days stale.
4. Fit the locked intercept-plus-slope log-level OLS. Reject zero/ill-
   conditioned copper variance, nonfinite arithmetic, residual sigma at or
   below `1e-10`, or beta outside `[0.10,3.00]`.
5. Fit the locked one-lag residual-change regression with intercept. Reject
   zero lag variance, nonfinite standard error, `rho>=0`,
   `t_rho>-3.043`, `phi` outside `(0,1)`, or half-life outside `[2,60]`.
6. Use OLS residual sigma with exactly 250 degrees of freedom for both newest
   z-scores. Positive fresh cross: `z_now>+1.0` and `z_prev<=+1.0`, SELL WTI
   and BUY copper. Negative fresh cross: `z_now<-1.0` and `z_prev>=-1.0`, BUY
   WTI and SELL copper. All other states remain flat.
7. Require WTI/copper spreads in `[0,1500]` and `[0,1200]` points, executable
   quotes, completed `ATR(20,D1)`, valid stops, magics, contract metadata, and
   volume steps.
8. Split one aggregate `RISK_FIXED=1000` package budget between normalized
   relative weights `1.0` for WTI and `abs(beta)` for copper. Independently
   ATR-size each share and attach a frozen `3.5 * ATR(20,D1)` hard stop; no
   take-profit.
9. Open WTI first and copper second. Retain exposure only when exactly one
   correctly directed, opposite-side position exists in each slot with a
   valid stop. Flatten every owned leg after an order or final-package failure.

## 5. Exit Rules

1. On every new WTI D1 bar, close both legs when the current admissible model
   has `abs(z_now)<=0.5`.
2. Close both legs immediately when synchronized history, model arithmetic,
   beta, CADF statistic, AR coefficient, half-life, endpoint freshness, or
   package composition becomes invalid.
3. Close both legs after sixty elapsed calendar days.
4. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
5. Per-leg broker hard stops and the framework kill switch remain
   authoritative.
6. Friday close is disabled because the source-aligned convergence hold spans
   weekends. There is no target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact host, timeframe, EA, slot, fixed-risk, news,
  Friday, stress, or locked strategy contract.
- Reject owned exposure, incomplete/desynchronized/stale history, invalid log
  prices, OLS/CADF singularity, failed beta/statistic/half-life gates, no fresh
  crossing, excessive spread, invalid quote, ATR, stop, magic, contract, or
  volume state.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  and package repair run before entry-only gates.
- Runtime may not read a futures chain, external file or API, trained output,
  optimizer result, analyst forecast, or portfolio state.

## 7. Trade Management Rules

- Maintain exactly one WTI position and one oppositely directed copper
  position under their registered magics and original broker hard stops.
- One shared fixed-risk budget is split by frozen entry beta weights. Signal
  magnitude never scales risk.
- Evaluate convergence and model validity only on a new WTI D1 bar; repair a
  malformed package immediately on every management call.
- Close both legs together through framework close helpers. Do not mutate a
  stop, replace a missing leg, or retry a stale extreme.
- No randomness, PnL-adaptive fit, partial close, scale-in, grid, martingale,
  or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_ols_lookback_d1` | 252 | [252] | exact synchronized completed observations |
| `strategy_entry_z` | 1.0 | [1.0] | fresh residual crossing boundary |
| `strategy_exit_z` | 0.5 | [0.5] | convergence boundary |
| `strategy_cadf_t_max` | -3.043 | [-3.043] | simple residual CADF critical boundary |
| `strategy_beta_min` | 0.10 | [0.10] | positive copper-beta floor |
| `strategy_beta_max` | 3.00 | [3.00] | positive copper-beta ceiling |
| `strategy_half_life_min_d1` | 2.0 | [2.0] | minimum admissible residual half-life |
| `strategy_half_life_max_d1` | 60.0 | [60.0] | maximum admissible residual half-life |
| `strategy_history_bars_d1` | 340 | [340] | bounded synchronized retrieval buffer |
| `strategy_max_endpoint_gap_days` | 10 | [10] | newest completed-endpoint freshness |
| `strategy_atr_period_d1` | 20 | [20] | completed per-leg stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_days` | 60 | [60] | stale package guard |
| `strategy_wti_max_spread_pts` | 1500 | [1500] | WTI entry spread ceiling |
| `strategy_xcu_max_spread_pts` | 1200 | [1200] | copper entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | basket order deviation |

Every carrier, timestamp rule, estimator, degrees of freedom, threshold,
direction, risk split, stop, hold, spread, and retry rule is locked.

## Author Claims

Chan demonstrates that OLS residual pair trades should be qualified by
cointegration rather than correlation and gives standardized entry/exit and
half-life methods. He does not claim WTI/copper is cointegrated or profitable.
EIA, CME, and USGS establish the distinct carrier contexts only.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the aggregate package. Risk is high: WTI/copper
cointegration is unproven and may be episodic; the simple CADF proxy has finite
sample uncertainty; both CFDs retain USD, growth, roll, financing, gap, and
liquidity exposure; synchronized history may be shallow; and legging, stop
desynchronization, or lot granularity may dominate the residual edge.

Opposite direction and beta-weighted stop-risk shares do not guarantee dollar,
beta, volatility, factor, market, or portfolio neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on wrong history count/timestamps, log orientation, OLS/CADF formula,
  degrees of freedom, critical value, beta/half-life gate, crossing direction,
  same-direction/orphan legs, aggregate-risk breach, hold beyond sixty days,
  missing stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing a window, test, threshold, direction,
  carrier, risk split, stop, hold, spread, or retry rule.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Complete CEO-ratified Wiley extraction plus governed official EIA, CME, and USGS carrier references. |
| R2 | PASS | Fixed synchronized OLS, residual CADF proxy, crossing, direction, aggregate risk, stops, lifecycle, and repair. |
| R3 | PASS | Registered WTI/copper D1 routes supply runtime inputs; Q02 validates synchronized history and fills. |
| R4 | PASS | Deterministic native log, OLS, regression, ATR risk, and trade-state arithmetic only; no trained output or banned signal indicator. |

- [x] Dedup: deterministic CLEAN; manual review separates all same-pair
  return-spread, channel, and monthly-momentum systems plus oil/gas ECM,
  precious-metal OLS, and the incumbent XNG oscillator.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, risk/news/Friday contract,
  magic, history, model, crossing, spread, ATR, and contract guards.
- trade_entry: synchronized OLS/CADF calculation, fresh crossing, opposite
  pair, beta-weighted fixed risk, hard stops, two orders, and atomic rollback.
- trade_management: package repair, current-model convergence/validity, and
  sixty-day stale exit before entry-only gates.
- trade_close: framework close helper, per-leg broker hard stops, and kill
  switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, one logical-basket `RISK_FIXED` backtest setfile, and one paced
non-live Q02 enqueue. It does not authorize a manual backtest; live, demo,
shadow, stress, or optimization artifact; AutoTrading; `T_Live`; deploy or
T_Live manifest; portfolio admission; portfolio-gate change; or correlation
waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-15 | initial WTI/copper CADF residual-reversion package | G0 | APPROVED; build pending |
| v2 | 2026-08-15 | implement CADF-qualified OLS basket and atomic lifecycle | Q01 | PASS; Q02 not enqueued |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-15 | APPROVED; R1-R4 PASS | `decisions/2026-08-15_qm5_21525_wti_xcu_cadf_g0.md`; governed composite source packet |
| Q01 Build Validation | 2026-08-15 | PASS | strict compile 0/0; build check 0/0; ten reference tests; P1 artifact PASS |
| Q02 Baseline Screening | - | NOT ENQUEUED | paced logical-basket enqueue pending |
