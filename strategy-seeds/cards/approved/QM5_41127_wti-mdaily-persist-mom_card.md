---
card_schema_version: 2
type: strategy
strategy_id: MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026_S01
variant_id: MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026_S01
source_id: MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026
ea_id: QM5_41127
slug: wti-mdaily-persist-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41127_wti-mdaily-persist-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41127_wti_monthly_daily_persistence_momentum_g0.md
source_approval: decisions/2026-08-23_wti_monthly_daily_persistence_momentum_source_approval.md
source_author: "Julia S. Mehlitz; Benjamin R. Auer; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Julia S. Mehlitz; Benjamin R. Auer; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Mehlitz, J. S., and Auer, B. R. (2024), Memory-enhanced momentum in commodity futures markets, European Journal of Finance 30(8), 773-802; Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Mehlitz, Julia S., and Benjamin R. Auer (2024), Memory-enhanced momentum in commodity futures markets, The European Journal of Finance 30(8), 773-802."
    location: "DOI 10.1080/1351847X.2023.2220118; complete-read packet strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md; bounded child strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md"
    quality_tier: A
    role: wti_return_serial_dependence_lineage
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded child strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md"
    quality_tier: A
    role: wti_own_price_one_month_continuation_and_monthly_clock
strategy_mechanic: normalized-month-boundary-wti-immediately-completed-seventeen-to-twenty-three-session-daily-log-returns-bias-neutralized-lag-one-persistence-score-strictly-positive-endpoint-continuation-one-month-hold
sources:
  - "[[sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-daily-persistence]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/bias-neutralized-lag-one-return-persistence]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-daily-persistence, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411270000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-7 completed WTI positions per full post-warm-up year after the fixed persistence and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WITHIN_MONTH_PERSISTENCE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q00
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-month daily-persistence continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify energy labels, exact month boundaries, 17-23 returns ending in the month, older boundary inclusion, centering, variance and adjacent-product sums, fixed 1/(n-1) neutralization, strict positive score, endpoint direction, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, immediate_completed_calendar_month, bounded_month_session_counts, older_boundary_close, every_return_ending_in_month_once, chronological_log_return_orientation, centered_return_mean, squared_deviation_denominator, adjacent_product_numerator, fixed_sample_neutralization, strict_positive_persistence_gate, endpoint_identity, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 two peer-reviewed WTI momentum/serial-dependence papers with daily-horizon translation disclosed; R2 exact month/return/centering/variance/adjacent-product/finite-sample-score/direction/attempt/risk/lifecycle; R3 native XTI D1 with label and CFD-basis risk; R4 deterministic arithmetic without banned signal; pre-allocation dedup CLEAN and post-allocation only expected self-hits."
---

# QM5_41127 WTI Completed-Month Daily-Persistence Momentum

## Hypothesis

WTI can sustain directional regimes while production, investment, inventories,
transport, refining, hedging, and demand adjust. A completed-month endpoint
return can still be produced by alternating daily moves. Following the endpoint
only when adjacent demeaned daily returns show positive bias-neutralized lag-one
persistence may isolate a structurally smoother continuation state.

This is a direct physical-energy carrier outside the certified
XAU/SP500/NDX/XNG book. Carrier and mechanic difference do not establish
profitability or decorrelation. Q02 owns frequency and baseline economics;
unchanged Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md`,
authorized before extraction by
`decisions/2026-08-23_wti_monthly_daily_persistence_momentum_source_approval.md`
at commit `4a9af0a24`. The parent packet hashes are
`A422025CE4C7FA2F9BEB995F496103D0FCCCED899C143771F58DB7E2222D3AC8`
and `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Mehlitz and Auer document return-autocorrelation/variance-ratio memory in a
commodity universe containing WTI. Moskowitz, Ooi, and Pedersen document own-
return continuation, test one-month formation/holding within pooled
commodities, and include WTI. Neither source tests one completed month of D1
returns, the fixed `1/(n-1)` shift, the strict positive score, a continuous
CFD, fixed-dollar ATR risk, or the QM book. Those choices are declared QM
interpretations.

No source return, WTI-only alpha, probability, density, profit factor,
drawdown, trade count, transaction cost, CFD equivalence, neutrality, or
correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,626 registry
identities, 1,295 repository cards, and 45 Strategy-Wiki nodes and returned
`CLEAN`. The post-allocation receipt contains only the two expected exact slug
and strategy-ID self-hits for reserved `QM5_41127`.

Manual family review fixes the mechanical boundaries:

- `QM5_20187_wti-tsmom1m` uses the endpoint return without an internal daily
  serial-dependence gate.
- `QM5_13134_energy-vr-mom` uses 32 monthly returns, a robust q=2 significance
  test, and continuation/reversal. This card uses 17-23 daily returns within
  one month, a fixed short-sample neutralization, and continuation only.
- `QM5_20245`, `QM5_20253`, `QM5_20256`, and `QM5_20257` estimate multi-month
  robust variance-ratio states rather than the latest month's daily path.
- `QM5_41111` counts signs; `QM5_41114`, `QM5_41115`, and `QM5_41117` vote on
  fixed blocks; `QM5_41122` orders extremes. This card multiplies adjacent
  centered return magnitudes and has no count, vote, or extreme state.
- `QM5_41124` uses mean-to-RMS coherence and `QM5_41126` uses endpoint-to-L1
  path efficiency. Neither estimates adjacent centered dependence.
- `QM5_41123` and `QM5_41125` are contrarian XAU/XAG baskets; this is one
  outright WTI series.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator
  pullback.

The WTI carrier, exact completed month, older boundary close, every daily
return ending in the month, centering, variance denominator, adjacent-product
numerator, fixed `1/(n-1)` shift, strict positive score, endpoint direction,
durable attempt, fixed-risk position, and next-month exit are jointly load-
bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_PERSISTENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `411270000`.
- Decision: first executable tick of a new broker-calendar month, within 180
  elapsed minutes of the raw current host D1 bar open.
- Signal data: every D1 return ending in the immediately completed calendar
  month; current-month prices are excluded.
- Position count: zero or one owned WTI position and at most one consumed
  attempt per broker `yyyymm`.
- Expected frequency: six positions/year as an ordering prior within a 5-7
  design range; Q02 must prove at least five in every scored full year.

## Rules

At the monthly decision, reconstruct the immediately completed month and one
adjacent older close. For `n` chronological log returns calculate:

```text
N   = sum(r[j])
mu  = N/n
S   = sum((r[j]-mu)^2)
A   = sum((r[j]-mu)*(r[j-1]-mu)), j=1..n-1
rho = A/S
J   = rho + 1/(n-1)
```

Require 17-23 returns, `S>0`, finite arithmetic, `rho` in `[-1,1]` within
`1e-10`, and endpoint identity. Only `J>0` qualifies. Follow the sign of `N`;
all equality, invalid, and nonqualifying states consume the month flat.

## 4. Entry Rules

1. Detect a decision only on the first executable D1 bar of a new normalized
   broker month, with entry no later than 180 elapsed minutes from the raw
   current bar open.
2. Persist the decision `yyyymm` before history, signal, news, spread, quote,
   ATR, sizing, or order gates. No restart, rejection, failure, or stop-out may
   retry that month.
3. Require the newest completed bar to be in the immediately prior calendar
   month. Within 45 bars, require 17-23 unique completed-month closes in strict
   reverse order and one older close in the adjacent month.
4. Reverse to chronological order and form one log return from the older close
   into every completed-month session. Verify the sum equals the direct
   boundary-to-final log return within `1e-10`.
5. Compute `N`, `mu`, `S`, `A`, `rho`, and `J` exactly as above. Require
   `S>0`, finite arithmetic, bounded `rho`, `J>0`, and `N!=0`.
6. Buy when `N>0`; sell when `N<0`. Score and return magnitude never change
   size.
7. Require no owned position, no current-month entry deal, spread no greater
   than 1,500 points, valid executable quote, and valid completed
   `ATR(20,D1)`.
8. Attach a frozen `3.5*ATR(20,D1)` server-side hard stop, no target, and size
   through the V5 fixed-stop-risk helper with aggregate `RISK_FIXED=1000`.

## 5. Exit Rules

1. The server-side hard stop is authoritative between ticks and D1 bars.
2. Flatten malformed, duplicated, wrong-symbol, wrong-magic, wrong-type, or
   stopless owned exposure immediately.
3. Close on the first tick whose normalized broker `yyyymm` is later than the
   month containing the owned position's entry time.
4. Forty elapsed calendar days is a stale repair only.

There is no target, opposite-signal exit, trail, break-even move, partial
close, Friday flatten, scale-in, pyramid, grid, martingale, or discretionary
close.

## 6. Filters (No-Trade Module)

- Require exact `XTIUSD.DWX`, D1, EA ID `41127`, slot 0, and magic
  `411270000`.
- Require `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, news
  temporal OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact month, history, close validity,
  persistence arithmetic, spread, quote, ATR, stop, and sizing fail-closed.
- No fitted threshold, robust significance state, anti-persistence reversal,
  moving average, oscillator, sign count, block vote, range location,
  seasonality, event calendar, volume, open interest, futures curve, external
  file, API, or manual runtime input is used.

## 7. Trade Management Rules

- Own either zero exposure or exactly one valid WTI position on the registered
  magic and symbol.
- Repair malformed state before considering a new entry.
- Leave the frozen server-side stop unchanged; do not trail, widen, partial-
  close, reverse, add, scale, or pyramid.
- Close at the first later broker-month boundary; use the forty-day guard only
  when that boundary repair was missed.
- Management remains reachable on every tick before any entry-only gate.

## Parameters To Test

No optimization surface is approved. The sole baseline uses:

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_history_bars_d1` | 45 | bounded completed-month buffer |
| `strategy_min_month_sessions` | 17 | minimum returns ending in month |
| `strategy_max_month_sessions` | 23 | maximum returns ending in month |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_sample_bias_adjustment` | true | require fixed `1/(n-1)` shift |
| `strategy_persistence_threshold` | 0.0 | strict `J>0` gate |
| `strategy_numerical_tolerance` | 1e-10 | arithmetic and endpoint tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `strategy_deviation_points` | 20 | deterministic order deviation |
| `qm_friday_close_enabled` | false | full-month identity |

Every value is locked in the one backtest setfile.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)`; no target or score-strength sizing.
- High risk: WTI gaps, geopolitical and inventory shocks, CFD roll/basis and
  financing, hard-stop slippage, sparse monthly decisions, and correlation
  with XNG or risk assets can dominate the premise.
- A positive persistence score is descriptive, not confidence.

## Kill Criteria

- Retire at zero trades or below five completed positions in any full post-
  warm-up scored year.
- Fail on wrong month labels, missing boundary, wrong session count, current-
  month leakage, reversed/omitted/duplicated return, wrong centering, variance,
  adjacent-product sum, correction, strict gate, endpoint identity, direction,
  repeated attempt, hold beyond forty days, missing stop, invalid fixed-risk
  mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the carrier, correction, threshold,
  direction, return inclusion, risk, stop, hold, spread, retry policy, or by
  adding another signal or sweep.

## Strategy Allowability Check

| Gate | Verdict | Reasoning |
|---|---|---|
| R1 | PASS_WITH_WITHIN_MONTH_PERSISTENCE_TRANSLATION_RISK | Two peer-reviewed papers, DOIs, complete-read evidence, durable hashes, WTI membership, own-return momentum, monthly clock, and serial-dependence lineage; daily horizon and fixed shift remain untested QM choices. |
| R2 | PASS | Month package, chronology, returns, endpoint identity, centering, sums, correction, strict threshold, direction, attempt, risk, stop, and lifecycle are exact. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native `XTIUSD.DWX` D1 plus MT5 execution state provides every runtime input. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external feed, grid, or martingale. |

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed-risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: consumed month attempt, exact completed-month reconstruction,
  daily return array, centering, variance and adjacent-product sums, fixed
  correction, endpoint identity, strict score gate, spread/quote/ATR/stop
  checks, and one fixed-risk order.
- trade_management: malformed-state repair, later-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only deterministic allocation, branch-only source build,
strict compile/Q01, one `RISK_FIXED` backtest preset, reference tests, and one
paced non-live Q02 enqueue if the fresh resource ceiling permits. It does not
authorize a manual backtest, demo/shadow/live/stress/optimization preset,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio-gate mutation,
portfolio admission, decorrelation claim, correlation waiver, or live use.

## Pipeline History

| Version | Date | Build reason | Phase reached | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-23 | initial source-bounded WTI completed-month daily-persistence card | G0 | APPROVED |
