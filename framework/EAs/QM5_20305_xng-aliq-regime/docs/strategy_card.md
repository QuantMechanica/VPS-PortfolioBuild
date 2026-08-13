---
card_schema_version: 2
type: strategy
strategy_id: YIYI-ALIQ-2025_XNG_TS_S03
variant_id: YIYI-ALIQ-2025_XNG_TS_S03
source_id: YIYI-XNG-ALIQ-REGIME-2026
ea_id: QM5_20305
slug: xng-aliq-regime
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20305_xng-aliq-regime_card.md
execution_contract_status: DRAFT
created: 2026-08-13
created_by: Research+Development
last_updated: 2026-08-13
g0_status: APPROVED
source_author: "Yiyi Qin; Jun Cai; Jie Zhu; Robert Webb"
source_authors: "Yiyi Qin; Jun Cai; Jie Zhu; Robert Webb"
source_citation: "Qin, Cai, Zhu, and Webb (2025), Commodity Futures Characteristics and Asset Pricing Models, Journal of Futures Markets 45(3), 176-207, DOI 10.1002/fut.22559."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Qin, Y., Cai, J., Zhu, J., and Webb, R. (2025). Commodity Futures Characteristics and Asset Pricing Models. Journal of Futures Markets 45(3), 176-207."
    location: "DOI https://doi.org/10.1002/fut.22559; complete-paper evidence strategy-seeds/sources/YIYI-ALIQ-2025/source.md; bounded extraction strategy-seeds/sources/YIYI-XNG-ALIQ-REGIME-2026/source.md"
    quality_tier: A
    role: primary_aliq_formula_high_minus_low_direction_and_monthly_cadence
strategy_mechanic: monthly-xng-self-relative-two-disjoint-252-log-return-tick-volume-amihud-illiquidity-high-minus-low-regime
sources:
  - "[[sources/YIYI-XNG-ALIQ-REGIME-2026]]"
concepts:
  - "[[concepts/commodity-illiquidity-premium]]"
  - "[[concepts/natural-gas-activity-price-impact]]"
  - "[[concepts/energy-structural-premium]]"
indicators:
  - "[[indicators/amihud-illiquidity-proxy]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, natural-gas, illiquidity, tick-volume-proxy, time-series-regime, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 203050000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly XNG positions/year after the 505-rate warm-up because only a numerical tie or invalid state stays flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0_APPROVED
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify an XNG monthly activity-price-impact state that is symmetric and slow, unlike certified QM5_12567's short-horizon long-only cumulative-RSI pullback. The paired ALIQ sibling's Q08 runs failure and WTI carrier's thin Q02 PF remain adverse evidence; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_505_completed_rates, two_disjoint_252_log_return_blocks, same_bar_tick_volume_alignment, strictly_positive_tick_volume, fixed_one_million_scale, source_high_aliq_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, tick_volume_dollar_volume_proxy, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20305_xng_aliq_regime_g0.md: R1 peer-reviewed Journal of Futures Markets source with complete-read evidence, exact ALIQ transform, proxy caveat, paired-family Q08 failure, and WTI-carrier Q02 result preserved; R2 exact two-block 252-log-return/activity estimator, fixed scale, source high-ALIQ map, and monthly lifecycle; R3 registered XNG D1 close/tick-volume route; R4 deterministic native arithmetic without trained output or prohibited signal indicator. No exact identity; three fuzzy neighbors were manually separated by topology, carrier, or statistic."
---

# QM5_20305 XNG Self-Relative ALIQ Regime

## Hypothesis

The source's high-illiquidity commodity premium may have a time-series analogue
in natural gas: buy XNG when recent price impact per unit of quote activity is
higher than in the immediately preceding disjoint year, and sell XNG when it
is lower. The proposed return driver is compensation for bearing activity-
scaled price-impact risk in a structurally storage- and weather-sensitive
energy market.

The candidate is deliberately unlike the certified `QM5_12567` XNG sleeve:
that incumbent is a short-horizon, long-only cumulative-RSI pullback; this
candidate is indicator-free, monthly, symmetric long/short, and uses two years
of activity-scaled returns. Structural difference is not realized
decorrelation. Q09 remains authoritative.

## Source Traceability And Claim Boundary

Qin, Cai, Zhu, and Webb (2025), *Journal of Futures Markets* 45(3), define
prior-year ALIQ as the average of absolute daily return divided by dollar
volume, multiply by one million, sort a broad futures cross-section monthly,
and report a positive high-minus-low relation. The governed complete-read and
bounded XNG packets are identified in the metadata.

This card substitutes MT5 quote-tick counts for dollar volume, translates a
broad cross-sectional sort into an XNG own-history comparison, and trades a
continuous CFD. It is a falsification, not a replication. No source return,
significance, XNG-only efficacy, cost, CFD equivalence, neutrality, or
correlation result transfers.

Family evidence is explicit. The paired `QM5_13140` ALIQ build passed Q02-Q07
but failed Q08 hard on runs clustering. The same-estimator WTI carrier
`QM5_20302` passed Q02 with 39 trades but only PF 1.01. Neither result can be
used as XNG performance evidence or as a rescue rationale.

## Concept And Formula

At the first processed `XNGUSD.DWX` D1 bar of a genuine broker-month
transition, load exactly 505 completed rates, newest first. For block offset
`b`, compute:

```text
r[b,k]       = ln(close[b+k] / close[b+k+1]), k = 0..251
aliq[b,k]    = abs(r[b,k]) / tick_volume[b+k] * 1,000,000
ALIQ[b]      = arithmetic_mean(aliq[b,0..251])

recent block b=0:       close pairs 0/1..251/252; volumes 0..251
preceding block b=252:  close pairs 252/253..503/504; volumes 252..503
```

The blocks share only close index 252 and share no return or volume
observation.

- BUY when `ALIQ[0] > ALIQ[252] + 1e-12`.
- SELL when `ALIQ[0] < ALIQ[252] - 1e-12`.
- Consume the month flat on a numerical tie or invalid state.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Require exact host `XNGUSD.DWX`, timeframe D1, registered slot 0, and
   magic `203050000`.
2. Detect a genuine broker-month transition from the current and preceding
   host D1 bar.
3. Before history, signal, spread, quote, news, ATR, sizing, or order gates,
   write a terminal-persistent attempted-month marker. Any failure consumes
   the month; restart or a stopped position cannot retry.
4. Load exactly 505 completed D1 rates, excluding the current bar. Require
   timestamps to be strictly older as series index increases, and require the
   newest endpoint to precede the decision bar and be no more than ten
   calendar days stale.
5. Require positive finite closes and strictly positive tick volume for the
   504 ending bars used by the two ALIQ blocks.
6. Calculate exactly 252 log-return/activity terms at offset 0 and exactly
   252 at offset 252, with the ending-bar volume aligned to each return.
7. Multiply every term by exactly 1,000,000 and average all terms in its
   block. Reject any nonfinite term or mean.
8. Buy on the locked high-ALIQ state and sell on the locked low-ALIQ state;
   remain flat inside the `1e-12` tolerance.
9. Require no owned position, a valid quote, spread no greater than 3,000
   points, completed ATR(20,D1), and valid fixed-risk lot metadata.
10. Place exactly one XNG position with a frozen `3.5 * ATR(20,D1)` broker
    hard stop and no take-profit.

## 5. Exit Rules

- On the first processed D1 bar of the next genuine broker month, close the
  prior position before consuming and evaluating the new month.
- Close any owned position after forty calendar days as a stale guard.
- Close malformed owned state before entry logic.
- The broker hard stop remains authoritative between D1 decisions.
- No take-profit, intramonth ALIQ re-evaluation, opposite-price signal,
  trailing stop, break-even, partial close, or discretionary exit is allowed.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Exact host/timeframe/slot/magic, locked parameters, monthly transition,
  persistent attempt, history count, chronology, endpoint freshness, price,
  tick-volume, ALIQ arithmetic, position, quote, spread, ATR, lot, and risk
  checks fail closed.
- News compliance may gate a new entry, but Q02 disables both news axes.
- Friday close is disabled only to preserve the source-aligned month hold;
  monthly renewal, stale close, malformed-state cleanup, and broker stop
  remain active.

## 7. Trade Management Rules

- Exactly one XNG position may exist for the registered magic.
- A terminal-persistent month marker is written before every fallible entry
  gate and prevents same-month re-entry across restarts or stop-outs.
- Malformed duplicate or wrong-symbol owned state is flattened before new
  entry logic.
- Risk is one `RISK_FIXED=1000` position in backtest; no signal scaling.
- No scale-in, pyramid, grid, martingale, partial close, trained output,
  prohibited signal indicator, external runtime feed, or adaptive PnL fit.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_returns_per_block` | 252 | [252] | ALIQ terms per history block |
| `strategy_preceding_block_offset` | 252 | [252] | older block return offset |
| `strategy_history_bars_d1` | 505 | [505] | completed D1 rate count |
| `strategy_aliq_scale` | 1000000.0 | [1000000.0] | source ALIQ scale |
| `strategy_state_tolerance` | 1e-12 | [1e-12] | symmetric comparison tolerance |
| `strategy_max_endpoint_gap_days` | 10 | [10] | latest endpoint freshness |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_days` | 40 | [40] | missed-rollover stale guard |
| `strategy_max_spread_points` | 3000 | [3000] | XNG entry spread ceiling |

All parameters are locked. No optimization, alternate estimator, direction,
filter, rescue window, carrier, or risk scale is authorized.

## Non-Duplicate Decision

- `QM5_13140_energy-aliq-rank` is a concurrent two-energy rank and two-leg
  package; this EA compares two XNG history blocks and owns one position.
- `QM5_20302_wti-aliq-regime` is the predeclared same-method WTI carrier.
  This XNG carrier extension changes the traded return stream and imports no
  sibling result; it is not a parameter variant.
- `QM5_12567_cum-rsi2-commodity` is short-horizon, long-only oscillator
  pullback logic, not a monthly symmetric activity-price-impact state.
- XNG skew, kurtosis, VoV, trend, seasonality, calendar, storage-event,
  variance-ratio, and relative-value families use other inputs or clocks.

The pre-allocation checker found no exact identity and returned only the three
expected family/carrier fuzzy neighbors. Manual verdict:
`CLEAN_AUTHORIZED_XNG_ALIQ_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Risk

## Initial Risk Profile And Kill Criteria

- `expected_pf: 1.01` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 35.0` reflects XNG gaps, quote-volume proxy instability,
  CFD roll/basis, long formation warm-up, monthly holds, and family runs risk.
- Expected density is eleven to twelve positions/year after warm-up. Retire
  below five completed positions/year under the binding Q02 floor.
- Fail on nonpositive used tick volume, wrong alignment, wrong return type or
  scale, wrong counts or offsets, stale history, reversed direction, repeated
  attempt, missing stop, hold beyond forty days, risk mismatch, or
  nondeterminism.
- Do not change the formation, transform, scale, direction, carrier, cadence,
  stop, hold, spread, or retry rule to rescue a failed baseline.
- Treat paired-family Q08 failure, WTI sibling PF 1.01, tick-volume proxy,
  futures/CFD basis, and realized book overlap as kill risks, not waivers.

## Strategy Allowability Check

- [x] Mechanical structural commodity activity-price-impact premium.
- [x] Peer-reviewed primary source, DOI, complete-read governed packet, exact
      transform and evidence limitations.
- [x] No trained output, prohibited signal indicator, external runtime feed,
      grid, martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density exceeds the five-trades/year Q02 floor.
- [x] Backtests use `RISK_FIXED`; no live setfile is authorized.
- [x] Manual topology/carrier/statistic dedup review is clean.

## Framework Alignment

- no_trade: exact host/slot, locked parameters, monthly transition and
  persistent attempt, completed history, endpoint chronology/freshness,
  positive close/tick volume, ALIQ arithmetic, spread, ATR, quote, lot, magic,
  position, and risk guards.
- trade_entry: exact two-block ALIQ comparison, one fixed-risk order, and
  frozen hard stop.
- trade_management: malformed-state repair, next-month replacement, and
  forty-day stale close.
- trade_close: framework close helper plus broker-side hard stop.

No `T_Live`, AutoTrading setting, live/demo/shadow/stress/optimization
setfile, deploy manifest, portfolio gate, portfolio admission, or correlation
waiver is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-13 | initial XNG self-relative ALIQ carrier | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | `decisions/2026-08-13_qm5_20305_xng_aliq_regime_g0.md`; bounded source packet |
| Q01 Build Validation | - | PENDING | - |
| Q02 Baseline Screening | - | NOT ENQUEUED | - |
