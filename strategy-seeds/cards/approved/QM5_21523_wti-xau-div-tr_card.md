---
card_schema_version: 2
type: strategy
strategy_id: MOP-CME-WTI-XAU-DIV-2026_S01
variant_id: MOP-CME-WTI-XAU-DIV-2026_S01
source_id: MOP-CME-WTI-XAU-DIV-2026
ea_id: QM5_21523
slug: wti-xau-div-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21523_wti-xau-div-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-14
created_by: Research+Development
last_updated: 2026-08-14
g0_status: APPROVED
g0_decision: decisions/2026-08-14_qm5_21523_wti_xau_div_trend_g0.md
source_approval: decisions/2026-08-14_wti_xau_div_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250; CME Group (2024), Through the Lens of Gold."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; governed retrieval SHA-256 7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379"
    quality_tier: A
    role: exact_twelve_month_wti_own_return_sign_and_monthly_cadence
  - type: exchange_article
    citation: "CME Group (2024). Through the Lens of Gold."
    location: "governed packet strategy-seeds/sources/CME-OIL-GOLD-RATIO-2024/source.md; fresh route DEFERRED:SOURCE_POLICY at retrieval_route_20260814.json"
    quality_tier: A
    role: structural_oil_through_gold_relative_value_lens
strategy_mechanic: monthly-wti-exact-twelve-completed-month-return-sign-trend-admitted-only-when-synchronized-read-only-gold-twelve-month-return-has-strict-opposite-sign
sources:
  - "[[sources/MOP-CME-WTI-XAU-DIV-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/oil-gold-divergence]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, oil-gold-divergence-gate, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
read_only_symbols: [XAUUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 215230000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to eight completed WTI positions per full post-warm-up year because only strict WTI/gold twelve-month sign divergence is eligible; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_POLICY_DEFER
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a WTI twelve-month trend stream admitted only while synchronized gold trends in the strict opposite direction; verify gold remains read-only. Q09 alone may establish realized decorrelation from XAU, SP500, NDX, and XNG."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_thirteen_consecutive_common_completed_month_ends, exact_timestamp_intersection, exact_twelve_month_log_returns, endpoint_chain_equality, strict_opposite_sign_gate, xau_read_only, monthly_attempt_state, risk_mode_dual, friday_close_disabled, q02_frequency_floor, cfd_futures_basis, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-14_qm5_21523_wti_xau_div_trend_g0.md after durable source approval and atomic allocation: R1 one governed composite backed by a complete peer-reviewed JFE read and a governed CME exchange packet with the fresh route honestly deferred; R2 locked synchronized month endpoints, strict opposite signs, WTI-only direction, lifecycle, stop, and risk; R3 registered XTI/XAU D1 with XAU read-only; R4 deterministic native arithmetic. The canonical checker returned CLEAN across 4,395 registry rows and 491 cards; oil/gold ratio, ratio breakout, return-spread, unconditional WTI trend, XNG decoupling, Brent confirmation, SP500 downside-beta, and XNG RSI families were manually separated."
---

# QM5_21523 WTI Trend In A Gold-Divergence State

## Hypothesis

WTI trend returns may add a distinct physical-energy stream when crude oil and
gold are moving in opposite long-horizon directions. The candidate follows
WTI's exact twelve-completed-month own-return sign only while gold's return
over the same synchronized endpoints has the strict opposite sign.

The filter is intended to reject common commodity direction and isolate oil-
specific supply, transport, inventory, policy, or demand repricing from the
certified metal sleeve. It does not prove low portfolio correlation. Q02 owns
density and economics; Q09 alone owns realized book overlap.

## Source Traceability And Claim Boundary

The canonical governed source is
`strategy-seeds/sources/MOP-CME-WTI-XAU-DIV-2026/source.md`.

Moskowitz, Ooi, and Pedersen supply the twelve-month own-return-sign momentum
rule, monthly cadence, and explicit WTI membership. The governed CME packet
supplies only the structural oil-through-gold relative-value lens. The generic
source router deferred a fresh CME page read under `DEFERRED:SOURCE_POLICY`, so
no new page text or inferred quotation enters this card.

Neither source tests the exact opposite-sign conjunction, synchronized
continuous-CFD month endpoints, WTI-only execution, fixed-dollar risk, ATR
stop, spread cap, restart ledger, or QM book. No source performance, density,
cost, CFD equivalence, neutrality, or correlation result transfers.

## Non-Duplicate Decision

The pre-allocation checker returned `CLEAN` across 4,395 EA-registry rows and
491 root cards. Manual review separates the closest systems:

- `QM5_12604_cme-oilgold-ratio` fades an absolute daily oil/gold log-ratio
  z-score and orders both legs.
- `QM5_12605_cme-oilgold-brk` follows a daily ratio channel and orders both
  legs.
- `QM5_12863_oilgold-rspread` fades a short-window return-spread shock and
  orders both legs.
- `QM5_12603_wti-tsmom12m` is unconditional. `QM5_21516` uses weak WTI/XNG
  daily correlation, `QM5_21518` same-sign Brent confirmation, and
  `QM5_21522` falling WTI/SP500 downside beta.
- `QM5_12567_cum-rsi2-commodity` is a long-only short-horizon XNG oscillator
  pullback.

This candidate forms no ratio, z-score, channel, relative-return shock, or
two-leg package. Its synchronized monthly endpoints, two exact twelve-month
signs, strict divergence, WTI-only topology, and consumed attempt are jointly
load-bearing. Verdict:
`CLEAN_WTI_TWELVE_MONTH_TREND_IN_STRICT_GOLD_DIVERGENCE_STATE`.

## Markets, Timeframe, And Formula

- Host and traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `215230000`.
- Read-only state symbol: `XAUUSD.DWX`, D1, with no magic or order authority.
- Decision: first processed host D1 bar after a genuine broker-month change.
- Formation: exactly thirteen consecutive synchronized completed broker-
  month endpoints.
- Hold: until the next broker-month transition, with a forty-day stale guard.

```text
wti_trend_12m = ln(WTI_latest_completed_month_end
                   / WTI_month_end_12_months_older)
xau_trend_12m = ln(XAU_latest_completed_month_end
                   / XAU_month_end_12_months_older)

BUY  WTI when wti_trend_12m >  1e-12 and xau_trend_12m < -1e-12
SELL WTI when wti_trend_12m < -1e-12 and xau_trend_12m >  1e-12
FLAT otherwise
```

For each symbol, the endpoint return must equal the sum of its twelve adjacent
monthly log returns within `1e-10`. Return magnitude never changes risk.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. No alternative horizon, sign rule, carrier, or parameter sweep is
authorized.

## 4. Entry Rules

1. Require exact EA ID 21523, `XTIUSD.DWX` D1 host, slot 0, magic 215230000,
   read-only `XAUUSD.DWX`, and every locked input.
2. Process malformed-position repair and prior-month liquidation before
   entry-only gates. Evaluate only after a genuine broker-month transition.
3. Persist the new broker month as consumed before history, signal, news,
   spread, quote, ATR, sizing, or order checks. No flat, blocked, failed,
   stopped, or closed decision may retry that month.
4. Reject any owned exposure or any same-month entry deal for this magic.
5. Load bounded completed WTI and gold D1 histories, intersect exact
   timestamps, and derive exactly thirteen consecutive common broker-month
   endpoints ending in the immediately completed month.
6. Reject duplicate, current-month, stale, nonpositive, nonfinite,
   nonchronological, or nonconsecutive endpoints. The newest common endpoint
   must be no more than ten calendar days stale.
7. Compute both exact twelve-month endpoint log returns. Verify each equals
   the sum of its twelve adjacent monthly returns within `1e-10`.
8. Buy WTI only for strict positive-WTI/negative-gold divergence; sell only
   for strict negative-WTI/positive-gold divergence. Consume every other state
   flat.
9. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid stop distance, registered magic, and valid contract and
   volume metadata.
10. Open at most one WTI market position using exactly one
    `RISK_FIXED=1000` budget and a frozen `3.5 * ATR(20,D1)` broker hard stop.
    There is no take-profit and no gold order.

## 5. Exit Rules

1. Close the prior WTI position on the first processed D1 bar of every new
   broker month before evaluating replacement risk, even if direction would
   remain unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Immediately close duplicate, wrong-symbol, invalid-type, or missing-stop
   exposure owned by the EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the monthly hold spans weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact host symbol, D1 timeframe, EA ID, slot,
  fixed-risk contract, news/Friday contract, or locked strategy inputs.
- Reject a consumed month, owned or same-month exposure, missing or
  nonconsecutive common month end, timestamp mismatch, wrong endpoint count,
  stale/nonfinite history, endpoint-chain mismatch, same-sign/deadband state,
  excessive spread, invalid quote, ATR, stop, magic, contract, or volume.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  and repair run before entry-only gates.
- Runtime may not order gold or read a futures chain, external file or API,
  analyst forecast, trained output, optimizer result, or portfolio state.

## 7. Trade Management Rules

- Maintain at most one correctly typed `XTIUSD.DWX` position under slot 0 and
  one consumed attempt per broker month.
- Preserve the original broker hard stop; close before monthly replacement or
  after forty calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history. Tester initialization clears only a future-dated
  marker so historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before new entry logic.
- Gold remains read-only. No randomness, PnL-adaptive fit, external state,
  partial close, scale-in, grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| strategy_trend_months | 12 | [12] | exact completed-month horizon for both returns |
| strategy_history_bars_d1 | 600 | [600] | bounded raw D1 history per symbol |
| strategy_max_endpoint_gap_days | 10 | [10] | newest common endpoint freshness guard |
| strategy_sign_deadband | 1e-12 | [1e-12] | strict sign threshold for both returns |
| strategy_return_tolerance | 1e-10 | [1e-10] | endpoint-versus-chain equality tolerance |
| strategy_atr_period_d1 | 20 | [20] | completed WTI stop estimator |
| strategy_atr_sl_mult | 3.5 | [3.5] | frozen hard-stop multiple |
| strategy_max_hold_days | 40 | [40] | monthly stale guard |
| strategy_max_spread_points | 1500 | [1500] | WTI entry spread ceiling |

Every timestamp, endpoint, return, sign, direction, traded/read-only role,
risk, stop, hold, spread, and retry rule is locked.

## Author Claims

Moskowitz, Ooi, and Pedersen report broad futures evidence for own-return-sign
time-series momentum and explicitly include WTI. CME frames crude oil through
gold as a relative-value lens. Neither claims that opposite WTI/gold
twelve-month signs make WTI trend profitable, equivalent to the source
futures, or uncorrelated with the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: the conjunction is novel; divergence can
be rare or persistent; WTI and gold CFDs differ from fixed-maturity futures;
roll, financing, gaps, geopolitics, and hard-stop slippage remain; and opposite
long-horizon signs do not eliminate daily, tail, or portfolio overlap.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full
  post-warm-up year.
- Fail on wrong month mapping, wrong endpoint count, timestamp mismatch,
  nonconsecutive months, endpoint-chain mismatch, same-sign entry, wrong
  direction, gold order, repeated attempt, hold beyond forty days, missing
  hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the horizon, endpoint rule, deadband,
  direction, carrier, risk, stop, hold, spread, or retry rule.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS_WITH_POLICY_DEFER | One canonical composite source backed by a complete peer-reviewed JFE read and a governed CME exchange packet; the fresh CME route is transparently deferred. |
| R2 | PASS | Exact synchronized month endpoints, two return checks, strict opposite signs, attempt state, stop, rollover, and stale exit are fixed. |
| R3 | PASS | Registered WTI and gold D1 closes supply every runtime input; gold is read-only. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: deterministic CLEAN; manual review separates oil/gold ratio,
  breakout, return-spread, unconditional WTI trend, recent factor-gated WTI,
  and XNG oscillator families.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, gold read-only contract,
  fixed-risk/news/Friday contract, and cheap parameter guards.
- trade_entry: consumed monthly attempt, synchronized WTI/gold endpoint
  reconstruction, two exact returns, strict divergence, spread/quote/ATR/stop
  checks, and one fixed-risk WTI order.
- trade_management: malformed-state repair, broker-month exit, and forty-day
  stale exit before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, one `XTIUSD.DWX` D1 `RISK_FIXED` backtest setfile, and one paced
non-live Q02 handoff when CPU capacity permits. It does not authorize a manual
backtest; live, demo, shadow, stress, or optimization artifact; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio-gate change; portfolio
admission; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-14 | initial WTI twelve-month trend in strict gold-divergence state | G0 | APPROVED; build pending |
| v2 | 2026-08-14 | implement synchronized opposite-sign gate and WTI lifecycle | Q01 | PASS; Q02 handoff pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS | `decisions/2026-08-14_qm5_21523_wti_xau_div_trend_g0.md`; governed composite source packet |
| Q01 Build Validation | 2026-08-14 | PASS | strict compile 0/0; build check 0/0; seven reference tests; P1 artifact PASS |
| Q02 Baseline Screening | 2026-08-14 | NOT_ENQUEUED | requires Q01 PASS and CPU-capacity check |
