---
ea_id: TBD
slug: cs-spread-rev
type: strategy
strategy_id: CORWIN-SCHULTZ-HL-SPREAD-2012_S01
status: IN_REVIEW
created: 2026-06-26
created_by: Codex
source_id: CORWIN-SCHULTZ-HL-SPREAD-2012
source_citation: "Corwin, S. A. and Schultz, P. (2012), A Simple Way to Estimate Bid-Ask Spreads from Daily High and Low Prices, Journal of Finance, DOI https://doi.org/10.1111/j.1540-6261.2012.01729.x; supplementary thesis Avramov, Chordia and Goyal, SSRN 555968."
sources:
  - "[[sources/CORWIN-SCHULTZ-HL-SPREAD-2012]]"
concepts:
  - "[[concepts/liquidity-shock-reversal]]"
  - "[[concepts/high-low-spread-estimator]]"
  - "[[concepts/short-run-reversal]]"
indicators:
  - "[[indicators/corwin-schultz-spread]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX]
period: H1
expected_trade_frequency: "H1 liquidity-shock reversal; estimate 25-60 trades/year/symbol after filters."
expected_trades_per_year_per_symbol: 35
g0_status: REVIEW
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0_REVIEW
last_updated: 2026-06-26
strategy_type_flags:
  - n-period-min-reversion
  - atr-hard-stop
  - time-stop
  - vol-regime-gate
  - session-time-gate
  - symmetric-long-short
quality_gate:
  duplicate_family: "Near-duplicate risk versus QM5_10330_illiq-rev; approve only if high-low inferred spread adds independent behavior."
  build_blocker: "Developer must verify Corwin-Schultz formula and add unit test vectors before EA implementation."
---

# Corwin-Schultz Spread Shock Reversal

## Source

- Primary: Corwin, S. A. and Schultz, P. (2012), "A Simple Way to Estimate Bid-Ask Spreads from Daily High and Low Prices", Journal of Finance, DOI https://doi.org/10.1111/j.1540-6261.2012.01729.x.
- Supplement: Avramov, D., Chordia, T. and Goyal, A., "Liquidity and Autocorrelations in Individual Stock Returns", SSRN 555968, https://papers.ssrn.com/sol3/papers.cfm?abstract_id=555968.
- Local related card: `QM5_10330_illiq-rev`, which already covers short-run illiquidity reversal with broker spread and tick-volume percentiles.

## Concept

Trade short-run reversal after a one-bar price shock only when the prior two bars imply a transient liquidity shock through the Corwin-Schultz high-low spread estimator. The candidate is intended to be prop-firm compatible because it is flat quickly, uses hard ATR risk, avoids martingale/grid behavior, and does not depend on external feeds.

This is not a generic spike-fade. The qualifying feature is the combination of:

- outsized return in the just-closed H1 bar,
- unusually high inferred high-low spread over the prior two closed H1 bars,
- actual current broker spread still inside a conservative execution cap,
- no scheduled high-impact news exposure.

## Markets And Timeframe

- Primary symbols: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`, `NDX.DWX`.
- Period: H1.
- Execution: next H1 bar after signal confirmation.
- Runtime data: Darwinex MT5 OHLC, ATR, current broker spread, V5 news guard. No external API.
- Evaluation uses only closed bars. Bar `1` is the just-closed H1 bar; bar `2` is the previous closed H1 bar.

## Estimator

Compute a two-bar Corwin-Schultz-style high-low spread proxy from closed H1 bars:

- `beta = log(High[1] / Low[1])^2 + log(High[2] / Low[2])^2`
- `gamma = log(max(High[1], High[2]) / min(Low[1], Low[2]))^2`
- `alpha = (sqrt(2 * beta) - sqrt(beta)) / (3 - 2 * sqrt(2)) - sqrt(gamma / (3 - 2 * sqrt(2)))`
- `cs_spread = 2 * (exp(max(alpha, 0)) - 1) / (1 + exp(max(alpha, 0)))`

Review verification 2026-06-27: this formula matches the Corwin-Schultz paper's beta/gamma/alpha/spread equations and the author sample SAS implementation for the unadjusted two-period high-low estimator. The EA must still include a deterministic unit-test fixture for `beta`, `gamma`, `alpha`, and `cs_spread`; use `beta=0.000043083869`, `gamma=0.000040606812`, `alpha=0.000462280697`, `cs_spread=0.000462280688` for `H1=1.1020`, `L1=1.0980`, `H2=1.1010`, `L2=1.0950`. Negative `alpha` must be clipped to zero before spread output. H1 use is a liquidity proxy, not a paper-claimed execution-cost estimate; skip weekend/reopen/gap bars rather than applying the paper's daily overnight adjustment mechanically.

## Entry Rules

At each new H1 bar, using closed bars only:

- Compute `ret1 = Close[1] / Close[2] - 1`.
- Compute `atr_pct = ATR(H1, 14)[1] / Close[1]`.
- Compute `cs_spread` from bars `1` and `2`.
- Compute `cs_pctile = percentile_rank(cs_spread, prior 250 closed H1 estimator values from the same symbol)`.
- Compute `same_direction_run = count of consecutive prior H1 closes in the direction of ret1`.

Enter long on the new bar if all conditions hold:

- `ret1 <= -0.80 * atr_pct`.
- `cs_pctile >= 85`.
- `same_direction_run <= 3`.
- `Close[1]` is not below the lowest low of the prior 20 H1 bars by more than `0.25 * ATR(H1,14)`.
- Current broker spread is below `0.08 * ATR(H1,14)` for FX and below the symbol-specific V5 cap for metals/indices.

Enter short symmetrically if:

- `ret1 >= 0.80 * atr_pct`.
- `cs_pctile >= 85`.
- `same_direction_run <= 3`.
- `Close[1]` is not above the highest high of the prior 20 H1 bars by more than `0.25 * ATR(H1,14)`.
- Current broker spread is inside the same execution cap.

Only one open position per symbol and magic is allowed.

## Exit Rules

- Hard stop: `1.20 * ATR(H1,14)` from entry.
- Time stop: close after 2 completed H1 bars.
- Optional profit exit: close at `+0.80R` if reached before the time stop.
- Session exit: close before Friday broker close under the V5 framework.
- Emergency exit: close immediately if current broker spread exceeds `0.20 * ATR(H1,14)` while the position is open and the trade is not already at or beyond the hard stop.

## Filters

- No entry during the first H1 bar after weekend reopen.
- No entry during the last two H1 bars before Friday close.
- No entry when V5 high-impact news blackout is active for the traded symbol or its primary currency.
- No entry if ATR(H1,14) is below the 20th percentile of the prior 250 H1 ATR values.
- No entry if the symbol has more than one missing H1 bar in the prior 48 bars.
- No entry if `cs_spread` has remained above its 80th percentile for 8 or more of the prior 12 H1 bars; that is persistent illiquidity, not a transient shock.

## Risk

- Baseline risk mode: V5 fixed-risk.
- Backtest set files: use `RISK_FIXED > 0` and `RISK_PERCENT = 0`; live percent risk is a later portfolio/OWNER decision. Never pyramid.
- Max one position per symbol.
- Max two simultaneous positions across the EA if implemented as a multi-symbol host.
- No grid, no martingale, no averaging down, no partial-close ladder.
- Prop-firm guard: daily-loss protection must be enforced by the framework, and the EA must not re-enter the same symbol after one stop-out on the same broker day.

## Parameters To Test

- name: `strategy_ret_atr_mult`
  default: 0.80
  sweep_range: [0.65, 0.80, 1.00]
- name: `strategy_cs_pctile_min`
  default: 85
  sweep_range: [80, 85, 90, 95]
- name: `strategy_cs_lookback_h1`
  default: 250
  sweep_range: [120, 250, 500]
- name: `strategy_hold_bars`
  default: 2
  sweep_range: [1, 2, 3, 4]
- name: `strategy_atr_sl_mult`
  default: 1.20
  sweep_range: [0.90, 1.20, 1.50]
- name: `strategy_take_profit_r`
  default: 0.80
  sweep_range: [0.50, 0.80, 1.00, 0.0]

Do not add trend filters, RSI filters, or optimizer-chosen session windows until the baseline either trades and fails cleanly or passes P2/P3. Otherwise the test becomes another overfit spike-reversal variant.

## Author Claims

- Corwin and Schultz are used for the high-low bid-ask spread estimator concept, not for a claimed H1 FX/CFD reversal strategy.
- Avramov, Chordia and Goyal are used for the liquidity/reversal thesis. The local `QM5_10330_illiq-rev` card records their abstract claim of a "strong relationship between short-run reversals and stock return illiquidity".
- No source claims this exact Darwinex H1 strategy has a published profit factor. The edge must be earned by P2/P3 evidence, not assumed from the papers.

## Duplicate And Distinctness Review

- Near duplicate: `QM5_10330_illiq-rev` uses short-run reversal plus broker spread and tick-volume percentiles on H1.
- Distinct proposed test: this card uses a two-bar high-low inferred spread estimator and explicitly requires current broker spread to normalize before entry. It should survive G0 only if that estimator adds different trades or materially different pass/fail behavior versus `QM5_10330_illiq-rev`.
- Related but distinct: `QM5_11071_spike-reversal` is a D1 spike reversal and does not require an inferred spread shock.
- Related but distinct: `QM5_10328_residual-rev` is a basket residual reversal and not a single-symbol liquidity shock fade.

## Falsification

- Reject at G0 if the reviewer decides the estimator is too close to `QM5_10330_illiq-rev` and should instead be an ablation of that EA.
- Reject before build if the Corwin-Schultz formula cannot be verified and unit-tested.
- Fail P2 if fewer than 10 valid trades occur across the five-symbol baseline after relaxing only `strategy_cs_pctile_min` from 85 to 80.
- Fail economically if expectancy is negative on at least four of five baseline symbols after costs.
- Fail as prop-firm unsuitable if losses cluster around news/slippage events despite the news and spread guards.

## Implementation Notes

- Use closed-bar indexing only. No signal may use the forming H1 bar.
- Implement `CorwinSchultzSpread2Bar()` as a pure function with unit tests before wiring trade logic.
- Log `ret1`, `atr_pct`, `cs_spread`, `cs_pctile`, `same_direction_run`, current broker spread, news-block state, and all skip reasons.
- The EA must expose a duplicate-audit mode that can dump signal timestamps for comparison with `QM5_10330_illiq-rev`.
- Backtests must use Model 4 / every real tick where available because current broker spread and stop execution matter.
- Default to no trade if any estimator input is invalid, if `High <= Low`, or if the percentile lookback is incomplete.
