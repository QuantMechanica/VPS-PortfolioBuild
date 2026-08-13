---
card_schema_version: 2
type: strategy
strategy_id: HOLLSTEIN-AGGJUMP-2021_XNG_TS_S03
variant_id: HOLLSTEIN-AGGJUMP-2021_XNG_TS_S03
source_id: HOLLSTEIN-XNG-JUMPBETA-REG-2026
ea_id: QM5_20306
slug: xng-jumpbeta-reg
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20306_xng-jumpbeta-reg_card.md
execution_contract_status: DRAFT
created: 2026-08-13
created_by: Research+Development
last_updated: 2026-08-13
g0_status: APPROVED
source_author: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_authors: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_citation: "Hollstein, Prokopczuk, and Tharann (2021), Anomalies in Commodity Futures Markets, Quarterly Journal of Finance 11(4), article 2150017, DOI 10.1142/S2010139221500178."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Hollstein, F., Prokopczuk, M., and Tharann, B. (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), 2150017."
    location: "DOI https://doi.org/10.1142/S2010139221500178; complete-paper evidence strategy-seeds/sources/HOLLSTEIN-AGGJUMP-2021/source.md; bounded extraction strategy-seeds/sources/HOLLSTEIN-XNG-JUMPBETA-REG-2026/source.md"
    quality_tier: A
    role: primary_aggregate_jump_beta_formula_direction_and_monthly_cadence
strategy_mechanic: monthly-xng-self-relative-two-disjoint-252-return-common-energy-jump-beta-low-minus-high-regime
sources:
  - "[[sources/HOLLSTEIN-XNG-JUMPBETA-REG-2026]]"
concepts:
  - "[[concepts/commodity-aggregate-jump-premium]]"
  - "[[concepts/natural-gas-common-energy-jump-sensitivity]]"
  - "[[concepts/energy-structural-premium]]"
indicators:
  - "[[indicators/common-energy-realized-jump-beta]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, natural-gas, common-jump-beta, time-series-regime, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 203060000
read_only_signal_symbols: [XTIUSD.DWX]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly XNG positions/year after the 505-rate warm-up because only a numerical tie or invalid state stays flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 40.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0_APPROVED
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify an XNG monthly common-energy jump-sensitivity state that is symmetric and slow, unlike certified QM5_12567's short-horizon long-only cumulative-RSI pullback. The paired jump-beta Q08 runs failure is adverse evidence; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_505_synchronized_completed_rates, two_disjoint_252_simple_return_blocks, block_local_inverse_vol_weights, inclusive_two_sigma_jump_factor, three_column_intercept_ols, minimum_six_jump_rows, xng_dependent_return, xti_read_only, monthly_attempt_state, risk_mode_dual, friday_close_disabled, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20306_xng_jumpbeta_reg_g0.md: R1 peer-reviewed QJF source with complete-read evidence, exact aggregate-jump orientation, option-to-realized proxy caveat, paired-family Q08 failure, and WTI carrier disclosed; R2 exact two-block synchronized estimator, block-local inverse-volatility factor, fixed two-sigma jump residual, intercept OLS, source low-beta direction, and monthly lifecycle; R3 registered XNG/XTI D1 close route with XTI read-only; R4 deterministic native arithmetic without trained output or prohibited signal indicator. No exact identity; four family neighbors were manually separated by topology, carrier, or statistic."
---

# QM5_20306 XNG Self-Relative Common-Jump-Beta Regime

## Hypothesis

The source's low aggregate-jump-beta commodity premium may have a time-series
analogue in natural gas: buy XNG when its recent sensitivity to a realized
common-energy jump residual is lower than in the immediately preceding
disjoint year, and sell XNG when that sensitivity is higher. The proposed
return driver is compensation for bearing common energy jump exposure in a
storage-, weather-, and infrastructure-sensitive market.

The candidate is deliberately unlike the certified `QM5_12567` XNG sleeve:
that incumbent is a short-horizon, long-only cumulative-RSI pullback; this
candidate is indicator-free, monthly, symmetric long/short, and uses two years
of synchronized XTI/XNG returns. Structural difference is not realized
decorrelation. Q09 remains authoritative.

## Source Traceability And Claim Boundary

Hollstein, Prokopczuk, and Tharann (2021) form prior-year commodity
characteristics, rebalance monthly, define aggregate jump beta as a regression
coefficient on an option-derived jump factor while controlling for market
return, and report a negative high-minus-low relationship. The governed
complete-read and bounded XNG packets are identified in the metadata.

This card substitutes an endogenous realized two-energy-CFD jump factor for
the source option factor, translates a broad cross-sectional sort into an XNG
own-history comparison, and trades a continuous CFD. It is a falsification,
not a replication. No source return, significance, XNG-only efficacy, cost,
CFD equivalence, neutrality, or correlation result transfers.

Family evidence is explicit. The paired `QM5_13147` build passed Q02-Q07 but
failed Q08 hard on runs clustering, with negative low- and normal-volatility
regime P&L. `QM5_20304` implements the same estimator on WTI. Neither sibling
can transfer performance, correlation, or a waiver to this carrier.

## Concept And Formula

At the first processed `XNGUSD.DWX` D1 bar of a genuine broker-month
transition, load exactly 505 synchronized completed closes for XTI and XNG,
newest first. Convert them to 504 chronological simple returns and split them
into preceding offset 0 and recent offset 252 blocks. For each block:

```text
sd_XTI, sd_XNG = sample deviations of exactly 252 returns
w_i             = inverse(sd_i) / sum inverse deviations
m_t             = w_XTI * r_XTI,t + w_XNG * r_XNG,t
jump_t          = m_t - mean(m) when abs(m_t - mean(m)) >= 2 * sample_sd(m)
                  else 0
r_XNG,t          = alpha + beta_energy*m_t + beta_jump*jump_t + error_t
```

Use all 252 rows, including zero-jump rows, and require at least six nonzero
jump rows plus a nonsingular three-column normal equation in each block.

- BUY when `beta_jump_recent < beta_jump_preceding - 1e-12`.
- SELL when `beta_jump_recent > beta_jump_preceding + 1e-12`.
- Consume the month flat on a numerical tie or invalid state.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Require exact host `XNGUSD.DWX`, timeframe D1, registered slot 0, magic
   `203060000`, and read-only factor symbol `XTIUSD.DWX`.
2. Detect a genuine broker-month transition from the current and preceding
   host D1 bar.
3. Before history, signal, spread, quote, news, ATR, sizing, or order gates,
   write a terminal-persistent attempted-month marker. Any failure consumes
   the month; restart or a stopped position cannot retry.
4. Load exactly 505 completed D1 rates for each symbol, excluding current
   bars. Require exact timestamp equality at every index, strictly older
   timestamps as series index increases, and a newest synchronized endpoint
   before the decision bar and no more than ten calendar days stale.
5. Require positive finite closes and form exactly 504 chronological simple
   returns for each symbol. Preceding returns are `0..251`; recent returns are
   `252..503`; the blocks share only their boundary close.
6. In each block independently calculate sample deviations, inverse-volatility
   weights summing to one, the common-energy return, its mean and sample
   deviation, and the inclusive two-sigma jump residual.
7. Regress XNG return on intercept, common-energy return, and jump residual
   over all 252 rows. Require at least six jump rows, full rank, and a finite
   jump coefficient in each block.
8. Apply the locked low-beta-long/high-beta-short direction; consume a tie or
   invalid state flat.
9. Require no owned position, a valid quote, spread no greater than 3,000
   points, completed ATR(20,D1), and valid fixed-risk lot metadata.
10. Place exactly one XNG position with a frozen `3.5 * ATR(20,D1)` broker
    hard stop and no take-profit. Never order XTI.

## 5. Exit Rules

- On the first processed D1 bar of the next genuine broker month, close the
  prior position before consuming and evaluating the new month.
- Close any owned position after forty calendar days as a stale guard.
- Close malformed owned state before entry logic.
- The broker hard stop remains authoritative between D1 decisions.
- No take-profit, intramonth beta re-evaluation, opposite-price signal,
  trailing stop, break-even, partial close, or discretionary exit is allowed.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Exact host/timeframe/slot/magic, locked parameters, monthly transition,
  persistent attempt, synchronized completed history, endpoint chronology and
  freshness, positive closes, return/factor/OLS arithmetic, spread, ATR,
  quote, lot, position, and risk checks fail closed.
- News compliance may gate a new entry, but Q02 disables both news axes.
- Friday close is disabled only to preserve the source-aligned month hold;
  monthly renewal, stale close, malformed-state cleanup, and broker stop
  remain active.

## 7. Trade Management Rules

- Exactly one XNG position may exist for the registered magic; XTI remains
  read-only and has no magic row.
- A terminal-persistent month marker is written before every fallible entry
  gate and prevents same-month re-entry across restarts or stop-outs.
- Malformed duplicate or wrong-symbol owned state is flattened before new
  entry logic.
- Risk is one `RISK_FIXED=1000` XNG position in backtest; no signal scaling.
- No scale-in, pyramid, grid, martingale, partial close, trained output,
  prohibited signal indicator, external runtime feed, or adaptive P&L fit.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_returns_per_block` | 252 | [252] | returns and OLS rows per block |
| `strategy_recent_block_offset` | 252 | [252] | recent chronological return offset |
| `strategy_history_bars_d1` | 505 | [505] | synchronized completed close count |
| `strategy_jump_z` | 2.0 | [2.0] | inclusive realized-jump threshold |
| `strategy_min_jump_days` | 6 | [6] | minimum nonzero jump rows per block |
| `strategy_max_endpoint_gap_days` | 10 | [10] | latest endpoint freshness |
| `strategy_beta_tolerance` | 1e-12 | [1e-12] | symmetric comparison tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_days` | 40 | [40] | missed-rollover stale guard |
| `strategy_max_spread_points` | 3000 | [3000] | XNG entry spread ceiling |

All parameters are locked. No optimization, alternate estimator, direction,
filter, rescue window, carrier, or risk scale is authorized.

## Non-Duplicate Decision

- `QM5_13147_energy-jumpbeta` is a concurrent two-energy rank and two-leg
  package; this EA compares two XNG history blocks and owns one position.
- `QM5_20304_wti-jumpbeta-reg` is the predeclared same-method WTI carrier.
  This XNG extension changes the traded return stream and imports no sibling
  result; it is not a parameter variant.
- `QM5_20303_wti-volbeta-reg` uses a smooth common-volatility-change
  coefficient, not the extreme-day jump residual.
- `QM5_12567_cum-rsi2-commodity` is short-horizon and long-only oscillator
  pullback logic, not a monthly symmetric common-jump-sensitivity state.
- XNG ALIQ, skew, kurtosis, volatility-of-volatility, seasonality, weekday,
  storage-event, trend, variance-ratio, and relative-value families use other
  inputs or clocks.

The pre-allocation checker found no exact identity and returned only expected
family/carrier matches. Manual verdict:
`CLEAN_AUTHORIZED_XNG_TIME_SERIES_COMMON_JUMP_BETA_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Risk

## Initial Risk Profile And Kill Criteria

- `expected_pf: 1.01` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 40.0` reflects XNG gaps, common-factor endogeneity, CFD
  roll/basis, long warm-up, monthly holds, and adverse family runs evidence.
- Expected density is eleven to twelve positions/year after warm-up. Retire
  below five completed positions/year under the binding Q02 floor.
- Fail on timestamp mismatch, wrong return type, overlapping blocks, pooled or
  equal weights, wrong deviation denominator, wrong jump threshold, fewer
  than six jump rows, singular OLS acceptance, XTI order, reversed direction,
  repeated attempt, missing stop, hold beyond forty days, risk mismatch, or
  nondeterminism.
- Do not change the estimator, direction, carrier, cadence, stop, hold, spread,
  or retry rule to rescue a failed baseline.
- Treat paired-family Q08 failure, factor endogeneity, futures/CFD basis, and
  realized book overlap as kill risks, not waivers.

## Strategy Allowability Check

- [x] Mechanical structural commodity jump-risk premium.
- [x] One peer-reviewed primary source, DOI, complete-read governed packet,
      exact direction, and evidence limitations.
- [x] No trained output, prohibited signal indicator, external runtime feed,
      grid, martingale, pyramiding, or adaptive P&L fitting.
- [x] D1/monthly expected density exceeds the five-trades/year Q02 floor.
- [x] Backtests use `RISK_FIXED`; no live setfile is authorized.
- [x] Manual topology/carrier/statistic dedup review is clean.

## Framework Alignment

- no_trade: exact host/slot, locked parameters, monthly transition and
  persistent attempt, synchronized history, endpoint chronology/freshness,
  positive closes, factor/jump/OLS arithmetic, spread, ATR, quote, lot, magic,
  position, and risk guards.
- trade_entry: exact two-block XNG jump-beta comparison, one fixed-risk order,
  and frozen hard stop; XTI remains read-only.
- trade_management: malformed-state repair, next-month replacement, and
  forty-day stale close.
- trade_close: framework close helper plus broker-side hard stop.

No `T_Live`, AutoTrading setting, live/demo/shadow/stress/optimization setfile,
deploy manifest, portfolio gate, portfolio admission, or correlation waiver is
authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-13 | initial XNG self-relative common-jump-beta carrier | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | `decisions/2026-08-13_qm5_20306_xng_jumpbeta_reg_g0.md`; bounded source packet |
| Q01 Build Validation | - | PENDING | - |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |
