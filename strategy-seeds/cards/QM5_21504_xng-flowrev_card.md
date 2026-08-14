---
ea_id: QM5_21504
slug: xng-flowrev
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XNG_S03
source_id: 28681f5d-aa78-584e-9698-750d1402e485
source_citation: "Zhao, Ding, Yu, and Kang (2026), Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets, DOI 10.2139/ssrn.6425598."
strategy_type_flags: [atr-hard-stop, time-stop, news-blackout, friday-close-flatten, symmetric-long-short]
markets: [XNGUSD.DWX]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_21504_XNG_FLOWREV_D1
status: APPROVED
g0_status: APPROVED
g0_decision: decisions/2026-08-14_qm5_21504_xng_flowrev_g0.md
r1_track_record: PASS
r1_reasoning: "Single attributable SSRN paper with DOI and durable bounded source packet; accessible material is explicitly limited to metadata and abstract/methodology summaries."
r2_mechanical: PASS
r2_reasoning: "Deterministic weekly return, non-overlapping tick-volume percentile, direction, ATR stop, time exit, and fail-closed lifecycle rules."
r3_data_available: PASS
r3_reasoning: "XNGUSD.DWX D1 close and native tick volume are available in MT5; no position, COT, CSV, API, or external signal feed is required."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed arithmetic and thresholds only; no model training, opaque transform, PnL adaptation, grid, or martingale."
pipeline_phase: Q02_ENQUEUED
expected_trades_per_year_per_symbol: 12
expected_trade_frequency: "One attempted evaluation per broker-week bucket; high-volume gate prior is roughly one quarter of weeks, about 10-14 trades/year. This is not test evidence."
expected_pf: 1.10
expected_dd_pct: 25.0
risk_class: high
ml_required: false
created: 2026-08-13
last_updated: 2026-08-14
created_by: Research
build_owner: Development
review_focus: "Adds a weekly XNG flow-proxy reversal driver, distinct from the book's cumulative-RSI XNG pullback; Q09 must still reject or challenger-test realized correlation."
---

# QM5_21504 XNG weekly high-volume flow-reversal

## hypothesis

The source associates its investor-position-derived speculative-flow component
with next-week commodity reversal. QM cannot reproduce that decomposition with
approved runtime data. This card instead tests whether a five-D1 XNG move made
during unusually high native tick volume is more likely to be flow-dominated
and reverse during the following week.

Tick volume is a disclosed proxy, not the paper's signal. The falsifiable edge
is: fade the sign of the latest five-bar return only when the same five bars'
tick-volume sum is in the top quartile of 40 earlier non-overlapping five-bar
windows. Average- and low-volume weeks stay flat.

This creates a weekly, symmetric, price/volume structural driver. It is not a
claim of decorrelation from the certified XAU/SP500/NDX/XNG book; later
portfolio evidence must establish that.

## source

- Single source: Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin (2026),
  "Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity
  Markets," SSRN 6425598, DOI `10.2139/ssrn.6425598`.
- URL: `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598`.
- Bounded source packet:
  `strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`.
- Access limitation: the governed packet contains metadata and accessible
  abstract/methodology summaries, not inaccessible full text. The 2026-08-14
  deterministic source-reader result is `DEFERRED:SOURCE_POLICY`.

The source provides the weekly reversal direction for its speculative-flow
component. It does not provide this tick-volume proxy, XNG carrier, stop,
spread ceiling, or expected result.

## rules

### Market, clock, and data

- Host and trade only `XNGUSD.DWX` on D1, magic slot 0.
- Use only completed D1 bars and their native `close`, `time`, and
  `tick_volume` fields.
- On a new D1 bar, evaluate only when the framework `PERIOD_W1` key differs
  between the current and preceding D1 bars.
- Persist the new week key before all fallible gates. Exactly one attempt is
  allowed per week across restarts, stop-outs, and order failures.
- Require exactly `strategy_vol_lookback * 5 + 5` completed bars: 205 at the
  Q02 default. Require strictly descending timestamps, positive finite closes,
  and positive tick volume.

### Entry

With series index 0 equal to the latest completed D1 bar:

```text
weekly_return = Close[0] / Close[5] - 1
current_volume = sum(TickVolume[0..4])

for j in 0..39:
    baseline_volume[j] = sum(TickVolume[5 + 5*j .. 9 + 5*j])

volume_percentile = 100 * count(baseline_volume <= current_volume) / 40
```

- Require `volume_percentile >= 75` with ties included.
- If `weekly_return > 0`, sell XNG.
- If `weekly_return < 0`, buy XNG.
- If the return is exactly zero, volume rank is below threshold, any input is
  invalid, or a position is already owned, remain flat for that week.
- Apply the standard two-axis news gate and reject entry above the configured
  spread ceiling.
- Place one market order with a frozen hard stop at
  `strategy_atr_sl_mult * ATR(strategy_atr_period,D1)` from entry and no
  take-profit.

### Exit

- Close after `strategy_max_hold_bars` completed D1 bars from entry.
- The broker hard stop and framework Friday close remain authoritative.
- No opposite-signal exit, neutral-band exit, take-profit, trailing stop,
  break-even move, or partial close is authorized.

### Trade management and no-trade rules

- One open position per registered magic and symbol.
- No same-week re-entry, scale-in, grid, martingale, pyramid, or signal-sized
  risk.
- Wrong symbol, timeframe, EA ID, slot, parameter domain, missing history,
  malformed time order, nonpositive data, invalid ATR, spread, quote, or stop
  fails closed.
- Framework kill switch, news handling, risk sizing, and Friday close remain
  unchanged.

## parameters to test

Q02 uses the defaults. Ranges are predeclared for later governed sweeps only;
they do not authorize rescue tuning after a failed baseline.

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_vol_lookback` | 40 | [26, 40, 60] | prior non-overlapping five-bar volume windows |
| `strategy_vol_percentile` | 75 | [67, 75, 85] | empirical high-volume gate |
| `strategy_atr_period` | 14 | [10, 14, 20] | completed-D1 hard-stop estimator |
| `strategy_atr_sl_mult` | 2.5 | [2.0, 2.5, 3.0, 3.5] | frozen stop multiple |
| `strategy_max_hold_bars` | 5 | [3, 5, 7] | completed-D1 time stop |
| `strategy_max_spread_points` | 600 | [300, 600, 1000] | entry execution ceiling |

The five-bar return/volume window, non-overlapping baseline construction,
tick-volume field, weekly cadence, fade direction, and one-attempt rule are
locked and have no sweep range.

## reputable-source criteria

| gate | status | evidence |
|---|---|---|
| R1 | PASS | One source ID, URL, DOI, bounded material, retrieval status, and porting gap are preserved. |
| R2 | PASS | Entry, exit, risk, lifecycle, and invalid-state behavior are fully mechanical. |
| R3 | PASS | XNG D1 close/tick-volume data are native to MT5; no position, COT, API, CSV, or external signal feed is used. |
| R4 | PASS | Deterministic native arithmetic, one position per magic, and no trained output or PnL-dependent adaptation. |

## non-duplicate boundary

- `QM5_12567_cum-rsi2-commodity`: long-only cumulative-RSI pullback plus slow
  trend filter. This card is symmetric, weekly, raw-return based, and gated by
  non-overlapping tick-volume rank.
- `QM5_13102_xng-1w-rev-vol`: minimum five-day shock plus high realized-
  volatility percentile and neutral-band exit. This card has no shock-size
  threshold, realized-volatility state, or neutral exit. Its only conditioner
  is tick-volume rank. The sibling's Q02 PASS/Q04 FAIL is adverse evidence,
  not inherited validation.
- `QM5_12817_xng-volshock-fade`: generic volatility shock fade, not a
  flow-proxy volume-tail rule.
- XNG event, seasonality, weekday, trend, carry, expiry, and relative-value
  sleeves use different data objects or clocks.

Dedup verdict:
`CLEAN_XNG_WEEKLY_TICK_VOLUME_CONDITIONED_REVERSAL_AFTER_FAMILY_REVIEW`.

## risk

- Backtest risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- `expected_pf` and expected frequency are queue-ordering priors, not results.
- Natural-gas gaps, roll/basis behavior, tick-volume instability, the weak
  connection between tick volume and investor positions, news gating, and the
  related Q04 family failure are material kill risks.
- Retire below five completed trades per full post-warm-up year or on
  nonpositive governed economics. Do not loosen the volume gate or change the
  return window to manufacture frequency.
- Fail on overlapping baseline windows, inclusion of the current window in its
  own baseline, use of real volume instead of tick volume, daily retry, wrong
  direction, missing stop, wrong risk mode, or nondeterminism.
- Q09 alone may establish realized book correlation. No correlation waiver or
  portfolio admission is implied by G0 or build PASS.

## framework alignment

- no_trade: exact EA/symbol/timeframe/slot and parameter guards, completed
  history, timestamp, close, tick-volume, percentile, spread, quote, stop,
  position, risk, and persistent weekly-attempt checks.
- trade_entry: cached weekly fade direction, one fixed-risk XNG market order,
  and a frozen ATR hard stop.
- trade_management: completed-D1-bar time stop; no modification logic.
- trade_close: framework close helper, broker hard stop, and Friday close.

No live/demo/shadow/stress setfile, manual backtest, `T_Live`, AutoTrading
change, deploy manifest, portfolio-gate edit, or portfolio admission is
authorized.

## pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-14 | initial canonical XNG tick-volume-conditioned weekly reversal | Q02 | Q01 PASS; Q02 enqueued |

## pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS | `decisions/2026-08-14_qm5_21504_xng_flowrev_g0.md` |
| Q01 Build Validation | 2026-08-14 | PASS; compile 0/0, build check 0/0 | `artifacts/qm5_21504_build_result.json` |
| Q02 Baseline Screening | 2026-08-14 | ENQUEUED, pending | work item `3231be16-d309-46c8-945f-d3dc30d03136` |
