---
card_schema_version: 2
type: strategy
strategy_id: MOP-CME-WTI-BRENT-CFM-2026_S01
variant_id: MOP-CME-WTI-BRENT-CFM-2026_S01
source_id: MOP-CME-WTI-BRENT-CFM-2026
ea_id: QM5_21518
slug: wti-brent-cfm
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21518_wti-brent-cfm_card.md
execution_contract_status: DRAFT
created: 2026-08-14
created_by: Research+Development
last_updated: 2026-08-14
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group; Intercontinental Exchange; U.S. Energy Information Administration"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group; Intercontinental Exchange; U.S. Energy Information Administration"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250; CME WTI-Brent Financial futures; ICE Brent/WTI Futures Spread; EIA Brent-WTI benchmark analysis."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: wti_membership_twelve_month_own_return_sign_and_monthly_cadence
  - type: exchange_and_agency_context
    citation: "CME WTI-Brent Financial futures; ICE Brent/WTI Futures Spread; U.S. EIA Brent-WTI spread analysis."
    location: "complete governed packet strategy-seeds/sources/CME-WTI-BRENT-SPREAD-2026/source.md"
    quality_tier: A
    role: linked_but_distinct_crude_benchmark_structure
strategy_mechanic: monthly-wti-twelve-month-return-sign-trend-admitted-only-when-synchronized-brent-twelve-month-return-has-the-same-strict-sign-with-brent-read-only
sources:
  - "[[sources/MOP-CME-WTI-BRENT-CFM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/crude-benchmark-confirmation]]"
indicators:
  - "[[indicators/log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, cross-benchmark-confirmation, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
read_only_symbols: [XBRUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 215180000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eight to eleven completed WTI positions per full post-warm-up year when the two crude-benchmark trends agree; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.02
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify an outright WTI twelve-month trend admitted only by same-sign Brent benchmark confirmation, adding a crude-oil driver distinct from the XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_thirteen_consecutive_synchronized_completed_month_ends, exact_twelve_month_log_returns, strict_same_sign_confirmation, brent_read_only, monthly_attempt_state, risk_mode_dual, friday_close_disabled, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized commodity sleeve: R1 bounded complete JFE plus CME/ICE/EIA lineage; R2 synchronized 12-month WTI/Brent strict-sign confirmation, WTI-only entry/exit/stop/sizing; R3 registered XTI/XBR D1; R4 deterministic non-trained native arithmetic; pre-allocation exact dedup clean and four fuzzy"
---

# QM5_21518 WTI-Brent Confirmed Trend

## Hypothesis

WTI's twelve-month own-return sign may retain the broad time-series-momentum
effect more cleanly when Brent, the other principal global crude benchmark,
has the same independently measured twelve-month direction. Agreement is
intended to reject WTI-only dislocations while preserving a common crude-oil
trend driven by supply, transport, inventory, policy, and demand structure.

The candidate trades WTI outright and introduces a direct crude-oil driver
absent from the certified XAU, SP500, NDX, and XNG book. Benchmark confirmation
does not prove low portfolio correlation. Q02 owns density and economics; Q09
owns realized overlap.

## Source Traceability And Claim Boundary

Moskowitz, Ooi, and Pedersen (2012) form monthly time-series-momentum
positions from each instrument's own past-return sign, include WTI, and report
the selected twelve-month family across diversified futures. CME and ICE list
WTI-Brent spread contracts, while EIA documents common and divergent
benchmark fundamentals.

The sources do not test this same-sign conjunction, synchronized broker-month
endpoints, continuous Darwinex CFDs, WTI-only execution, fixed-dollar risk,
ATR hard stop, or the QM book. No source return, significance, Sharpe ratio,
drawdown, trade count, cost, threshold, CFD equivalence, or correlation
statistic transfers. The single governed source packet is
`strategy-seeds/sources/MOP-CME-WTI-BRENT-CFM-2026/source.md`.

## Non-Duplicate Decision

The canonical checker found no exact slug or strategy-ID collision for
`wti-brent-cfm` / `MOP-CME-WTI-BRENT-CFM-2026_S01` across 4,390 registry rows
and 486 cards. Its four lexical fuzzy matches are mechanically distinct:

- `QM5_12848_wti-brent-brk` trades an opposite-leg daily spread-channel
  breakout; this EA never forms a spread and never orders Brent.
- `QM5_12843_wti-brent-spread` and `QM5_12860_wti-brent-rshock` trade paired
  relative-value convergence rather than an outright WTI trend.
- `QM5_12603_wti-tsmom12m` is unconditional WTI trend and never reads Brent.
- Brent trend sleeves order Brent itself; WTI dual-horizon sleeves compare WTI
  only to its own path. `QM5_12844_commodity-trend-crude` is a daily
  Donchian/ADX breakout.

The WTI carrier, synchronized thirteen-month endpoint set, independent WTI
and Brent twelve-month signs, strict agreement, Brent read-only boundary,
consumed monthly decision, and single-leg fixed-risk execution are jointly
load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_BRENT_BENCHMARK_CONFIRMED_TREND`.

## Markets, Timeframe, And Formula

- Traded host: `XTIUSD.DWX`, D1, slot 0, magic `215180000`.
- Read-only benchmark: `XBRUSD.DWX`, D1, no magic or order authority.
- Decision clock: first processed host D1 bar after a genuine broker-month
  transition.
- Formation: exactly thirteen consecutive synchronized completed broker-month
  endpoints ending in the immediately completed month.
- Hold: until the next broker-month boundary, with a forty-day stale guard.

```text
wti_trend_12m   = ln(WTI_month_end_latest / WTI_month_end_12_months_ago)
brent_trend_12m = ln(Brent_month_end_latest / Brent_month_end_12_months_ago)

BUY WTI  when wti_trend_12m > 0 and brent_trend_12m > 0
SELL WTI when wti_trend_12m < 0 and brent_trend_12m < 0
FLAT     otherwise
```

For each benchmark, the endpoint log return must equal the sum of its twelve
component monthly log returns within `1e-10`. Exact zero or sign disagreement
consumes the month flat. Magnitude never changes position size.

## Rules

These entry, exit, filter, and lifecycle rules are the complete authorized
baseline. No alternate threshold, horizon, endpoint convention, carrier,
calendar, risk scale, or fallback is authorized.

## 4. Entry Rules

1. Require EA ID 21518, `XTIUSD.DWX` D1 host, slot 0, magic `215180000`, and
   read-only `XBRUSD.DWX`.
2. Process lifecycle repair and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine broker-month transition.
3. Persist the broker month as consumed before history, signal, spread, quote,
   news, ATR, sizing, or order checks. A failed or stopped entry may not retry.
4. Load a bounded 500 completed-D1-bar buffer for each symbol and intersect
   exact timestamps. Require strict chronology, positive finite closes, a
   newest common endpoint before the decision bar, and no more than ten
   calendar days stale.
5. Derive exactly thirteen consecutive completed broker-month endpoints for
   both symbols, ending in the immediately completed broker month. The two
   benchmark endpoints for each month must use the same timestamp.
6. For each benchmark compute the exact twelve-month endpoint log return and
   twelve component monthly log returns. Require agreement within `1e-10`.
7. Buy only when both twelve-month returns are strictly positive. Sell only
   when both are strictly negative. Consume equality, nonfinite state, or sign
   disagreement flat.
8. Require no owned exposure, no same-month entry deal, spread in `[0,1500]`
   points, executable quote, completed `ATR(20,D1)`, and valid fixed-risk
   contract metadata.
9. Open at most one WTI position with one `RISK_FIXED=1000` budget, a frozen
   `3.5*ATR(20,D1)` broker hard stop, and no take-profit. Never order Brent.

## 5. Exit Rules

1. Close the prior WTI position on the first processed D1 bar of every new
   broker month before considering replacement, even if direction is unchanged.
2. Close after forty elapsed calendar days as a missed-rollover stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. There is no intramonth opposite-signal exit, target, trail, break-even,
   partial close, scale-in, grid, martingale, pyramid, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host, timeframe, EA ID, slot, fixed-risk, news,
  Friday, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  incomplete/stale/misaligned history, wrong endpoint count, nonconsecutive
  months, nonfinite return, sign disagreement, excessive spread, invalid
  quote, unavailable ATR, invalid stop, or invalid contract metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not order Brent or read a futures chain, external file or API,
  analyst forecast, trained output, optimizer result, or portfolio state.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly replacement or after
  forty calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future marker so
  historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before new entry logic.
- Brent remains read-only. Trend magnitude never scales risk.
- No randomness, adaptive PnL fitting, external state, partial close,
  scale-in, grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_trend_months` | 12 | [12] | exact completed-month horizon for both benchmarks |
| `strategy_history_bars_d1` | 500 | [500] | bounded completed-D1 copy per symbol |
| `strategy_max_endpoint_gap_days` | 10 | [10] | common endpoint freshness guard |
| `strategy_return_tolerance` | 1e-10 | [1e-10] | endpoint-versus-chain equality tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, return types, synchronization, strict signs, traded/read-only
roles, attempt clock, risk, stop, hold, and no-retry policy are locked.

## Author Claims

The primary source supports a diversified twelve-month time-series-momentum
family that includes WTI. The benchmark sources support a linked but distinct
WTI-Brent market structure. They do not claim that same-sign Brent
confirmation improves WTI trend, that a continuous CFD reproduces futures, or
that the candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: the cross-source conjunction, two-series
history alignment, near-identical benchmark trends, structural basis breaks,
WTI gaps and rolls, fixed-risk stop slippage, futures/CFD basis, and overlap
with XNG or risk assets can dominate the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full
  post-warm-up year.
- Fail on wrong month-end count, timestamp mismatch, nonconsecutive months,
  wrong return horizon, endpoint-chain mismatch, sign-disagreement entry,
  Brent order, repeated attempt, hold beyond forty days, missing hard stop,
  invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the horizons, sign rule, symbols, traded
  leg, stop, hold, spread, or retry rule.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | One bounded lineage backed by a complete peer-reviewed JFE paper review and governed CME/ICE/EIA benchmark records. |
| R2 | PASS | Fixed synchronized month endpoints, log-return signs, entry, exit, stop, sizing, attempt, rollover, and stale guard. |
| R3 | PASS | Registered XTI/XBR D1 closes; Brent is read-only and no external runtime series is required. |
| R4 | PASS | Deterministic arithmetic only, without trained output, external feed, grid, or martingale. |

- [x] Dedup: exact check clean; four lexical fuzzy hits manually separated by
  signal object, traded legs, decision clock, and lifecycle.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, Brent read-only contract,
  fixed-risk/news/Friday contract, and cheap parameter guards.
- trade_entry: persistent month attempt, synchronized histories, exact monthly
  returns, same-sign confirmation, spread/quote/ATR/stop checks, and one
  fixed-risk WTI order.
- trade_management: malformed-state repair, broker-month exit, and forty-day
  stale exit before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff when CPU capacity permits. It
does not authorize a manual backtest; live, demo, shadow, optimization, or
stress setfile; AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio-
gate change; portfolio admission; or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-14 | initial WTI trend with Brent benchmark confirmation | G0 | APPROVED; build pending |
| v2 | 2026-08-14 | implement locked WTI/Brent confirmation and fixed-risk lifecycle | Q01 | PASS; Q02 pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS | `decisions/2026-08-14_qm5_21518_wti_brent_cfm_g0.md`; bounded source packet |
| Q01 Build Validation | 2026-08-14 | PASS | strict compile 0/0; build check 0/0; six reference tests; P1 artifact PASS |
| Q02 Baseline Screening | 2026-08-14 | PENDING | work item `baee9255-3daf-4a85-b300-07a4f57ac0cf`; no tester dispatched by this build |
