---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MOPEN-RESIDENCE-MOM-2026_S01
variant_id: MOP-WTI-MOPEN-RESIDENCE-MOM-2026_S01
source_id: MOP-WTI-MOPEN-RESIDENCE-MOM-2026
ea_id: QM5_41130
slug: wti-mopen-residence-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41130_wti-mopen-residence-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41130_wti_monthly_open_residence_momentum_g0.md
source_approval: decisions/2026-08-23_wti_monthly_open_residence_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded child strategy-seeds/sources/MOP-WTI-MOPEN-RESIDENCE-MOM-2026/source.md"
    quality_tier: A
    role: wti_own_price_one_month_continuation_and_monthly_clock
strategy_mechanic: normalized-month-boundary-wti-immediately-completed-seventeen-to-twenty-three-session-closes-three-quarter-fixed-prior-month-end-residence-endpoint-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MOPEN-RESIDENCE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-fixed-open-residence]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/fixed-open-close-residence]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-open-residence, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411300000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 7-8 completed WTI positions per full post-warm-up year after the fixed residence and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_OPEN_RESIDENCE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q00
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-month fixed-open-residence continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify energy labels, exact month boundaries, 17-23 closes plus older boundary, fixed anchor, exhaustive strict counts, integer three-quarter ceiling, endpoint identity and direction, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, immediate_completed_calendar_month, bounded_month_session_counts, older_boundary_close, exhaustive_close_residence, strict_tie_handling, integer_ceiling_three_quarter_gate, endpoint_identity, endpoint_continuation, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 peer-reviewed WTI own-return momentum paper with complete-read evidence and open-residence translation disclosed; R2 exact month/anchor/count/threshold/endpoint/direction/attempt/risk/lifecycle; R3 native XTI D1 with CFD-basis risk; R4 deterministic arithmetic without banned signal; pre-allocation dedup CLEAN and post-allocation only expected self-hits."
---

# QM5_41130 WTI Completed-Month Fixed-Open Residence Momentum

## Hypothesis

WTI repricing can persist while production, inventory, refining, transport,
hedging, and demand adjust. A completed-month endpoint return is more
structurally coherent when most daily closes stayed on that endpoint's side of
the prior month-end rather than arriving through one late shock. Following the
endpoint only after a fixed three-quarter residence gate may isolate a
persistent physical-energy repricing state.

This is a direct WTI carrier outside the certified XAU/SP500/NDX/XNG book.
Carrier and mechanic difference do not establish profitability or
decorrelation. Q02 owns frequency and baseline economics; unchanged Q09 alone
may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-MOPEN-RESIDENCE-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-23_wti_monthly_open_residence_momentum_source_approval.md`
at commit `751e7cc4d`. The bounded packet SHA-256 is
`4618B8365486FE18DA1C878F7920F6ED284115A37A87D26B59CE9C5A24DED991`.

Moskowitz, Ooi, and Pedersen document own-return continuation, test one-month
formation and holding within pooled commodities, and include NYMEX WTI. The
paper does not test D1 close residence, the three-quarter gate, a continuous
CFD, fixed-dollar ATR risk, or the QM book. Those choices are declared QM
interpretations.

No source return, WTI-only alpha, probability, density, profit factor,
drawdown, trade count, transaction cost, CFD equivalence, neutrality, or
correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,629 registry
identities, 1,297 repository cards, and 45 Strategy-Wiki nodes and returned
`CLEAN`. The post-allocation receipt contains only the two expected exact slug
and strategy-ID self-hits for reserved `QM5_41130`.

Manual family review fixes the mechanical boundaries:

- `QM5_20187_wti-tsmom1m` uses the endpoint return without a path gate.
- `QM5_41111_wti-mdaybreadth-mom` counts adjacent daily-return signs. This
  card counts cumulative close levels against one fixed older boundary.
- `QM5_41114`, `QM5_41115`, and `QM5_41117` vote on fixed calendar blocks;
  this card exhaustively counts all completed-month closes.
- `QM5_41122` orders extreme close states; this card selects no extremes.
- `QM5_41124`, `QM5_41126`, and `QM5_41127` use return magnitudes, path norms,
  or adjacent centered-return products; this card uses none of them.
- `QM5_41120_xauxag-mopen-residence-rv` is a synchronized, contrarian,
  equal-notional gold/silver basket anchored on its first in-month ratio. This
  card is one outright WTI continuation position anchored on the older close.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback.

The WTI carrier, exact completed month, older boundary, all month closes,
strict ties, integer ceiling threshold, endpoint confirmation, continuation
direction, durable attempt, fixed-risk position, and next-month exit are
jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_FIXED_OPEN_RESIDENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `411300000`.
- Decision: first executable tick of a new broker-calendar month, within 180
  elapsed minutes of the raw current host D1 bar open.
- Signal data: one older boundary close plus every D1 close in the immediately
  completed calendar month; current-month prices are excluded.
- Position count: zero or one owned WTI position and at most one consumed
  attempt per broker `yyyymm`.
- Expected frequency: seven positions/year as an ordering prior within a 7-8
  design range; Q02 must prove at least five in every scored full year.

## Rules

For older boundary close `P` and `n` chronological completed-month closes
`Q[0]..Q[n-1]`:

```text
above    = count(Q[j] > P), j=0..n-1
below    = count(Q[j] < P), j=0..n-1
required = (3*n + 3) // 4
N        = ln(Q[n-1] / P)
```

Require 17-23 month closes, positive finite arithmetic, and endpoint identity
between `N` and the sum of all log returns ending in the month within `1e-10`.
Buy only when `above>=required` and `N>0`. Sell only when `below>=required` and
`N<0`. Exact ties stay in `n` and count to neither side. All equality, invalid,
and nonqualifying states consume the month flat.

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
4. Reverse to chronological order. Treat the older close as immutable `P`,
   compare every month close strictly with `P`, retain ties only in the
   denominator, and compute `required=(3*n+3)//4`.
5. Form one chronological log return from `P` into every month session and
   verify the sum equals `log(Q[n-1]/P)` within `1e-10`.
6. Buy when `above>=required` and `N>0`; sell when `below>=required` and
   `N<0`. Residence surplus and endpoint magnitude never change size.
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

- Require exact `XTIUSD.DWX`, D1, EA ID `41130`, slot 0, and magic
  `411300000`.
- Require `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, news
  temporal OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact month, history, close validity,
  fixed-anchor counts, integer threshold, endpoint identity, spread, quote,
  ATR, stop, and sizing fail-closed.
- No fitted threshold, mean, scale, return-magnitude gate, moving average,
  oscillator, daily-return sign count, block vote, range location,
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
| `strategy_min_month_sessions` | 17 | minimum completed-month closes |
| `strategy_max_month_sessions` | 23 | maximum completed-month closes |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_residence_numerator` | 3 | fixed residence fraction numerator |
| `strategy_residence_denominator` | 4 | fixed residence fraction denominator |
| `strategy_numerical_tolerance` | 1e-10 | endpoint-identity tolerance |
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
- The residence count is descriptive, not confidence.

## Kill Criteria

- Retire at zero trades or below five completed positions in any full post-
  warm-up scored year.
- Fail on wrong month labels, missing boundary, wrong session count, current-
  month leakage, wrong anchor, omitted or duplicated close, wrong tie
  assignment, wrong ceiling arithmetic, endpoint mismatch, wrong direction,
  repeated attempt, hold beyond forty days, missing stop, invalid fixed-risk
  mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the carrier, residence fraction, tie rule,
  anchor, direction, risk, stop, hold, spread, retry policy, or by adding
  another signal or sweep.

## Strategy Allowability Check

| Gate | Verdict | Reasoning |
|---|---|---|
| R1 | PASS_WITH_OPEN_RESIDENCE_TRANSLATION_RISK | Peer-reviewed paper, DOI, complete-read evidence, durable hashes, WTI membership, own-return momentum, monthly clock, and deterministic residence lineage; D1 gate and continuation map remain untested QM choices. |
| R2 | PASS | Month package, chronology, anchor, exhaustive counts, ties, integer threshold, endpoint identity, direction, attempt, risk, stop, and lifecycle are exact. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native `XTIUSD.DWX` D1 plus MT5 execution state provides every runtime input. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external feed, grid, or martingale. |

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed-risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: consumed month attempt, exact completed-month reconstruction,
  fixed older anchor, exhaustive strict residence counts, integer ceiling,
  endpoint identity and direction, spread/quote/ATR/stop checks, and one fixed-
  risk order.
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
| v1 | 2026-08-23 | initial source-bounded WTI completed-month fixed-open-residence card | G0 | APPROVED |

