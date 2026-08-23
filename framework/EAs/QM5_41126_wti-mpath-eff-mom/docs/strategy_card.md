---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MPATH-EFF-MOM-2026_S01
variant_id: MOP-WTI-MPATH-EFF-MOM-2026_S01
source_id: MOP-WTI-MPATH-EFF-MOM-2026
ea_id: QM5_41126
slug: wti-mpath-eff-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41126_wti-mpath-eff-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41126_wti_monthly_path_efficiency_momentum_g0.md
source_approval: decisions/2026-08-23_wti_monthly_path_efficiency_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; statistic lineage strategy-seeds/sources/MOP-WTI-PATHEFF-2026/source.md; bounded child strategy-seeds/sources/MOP-WTI-MPATH-EFF-MOM-2026/source.md"
    quality_tier: A
    role: wti_own_price_monthly_continuation_and_path_efficiency_lineage
strategy_mechanic: normalized-month-boundary-wti-immediately-completed-seventeen-to-twenty-three-session-daily-log-returns-net-to-absolute-path-efficiency-at-least-zero-point-two-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MPATH-EFF-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-path-efficiency]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/net-to-absolute-path-efficiency]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-path-efficiency, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411260000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-7 completed WTI positions per full post-warm-up year after the fixed path-efficiency and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WITHIN_MONTH_GATE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q00
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-month path-efficiency continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify energy labels, exact month boundaries, 17-23 returns ending in the month, older boundary inclusion, signed net, L1 absolute path, endpoint identity, inclusive 0.20 gate, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, immediate_completed_calendar_month, bounded_month_session_counts, older_boundary_close, every_return_ending_in_month_once, chronological_log_return_orientation, signed_net_sum, absolute_path_sum, endpoint_identity, fixed_efficiency_threshold, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 peer-reviewed WTI monthly continuation and approved closed-form path-statistic lineage with daily-horizon translation disclosed; R2 exact month/return/net/L1-path/0.20-gate/attempt/risk/lifecycle; R3 native XTI D1 with label and CFD-basis risk; R4 deterministic arithmetic without banned signal; pre-allocation dedup CLEAN and post-allocation only self-hits."
---

# QM5_41126 WTI Completed-Month Path-Efficiency Momentum

## Hypothesis

WTI can sustain directional regimes while production, investment, inventories,
transport, refining, hedging, and demand adjust. A completed-month endpoint
return can be dominated by reversals that happen to finish away from the
start. Following the move only when its absolute net displacement accounts for
at least 20% of the entire absolute daily path may isolate a more structurally
directional monthly state.

This is a direct physical-energy carrier outside the certified
XAU/SP500/NDX/XNG book. Carrier and mechanic difference do not establish
profitability or decorrelation. Q02 owns frequency and baseline economics;
unchanged Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-MPATH-EFF-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-23_wti_monthly_path_efficiency_momentum_source_approval.md`
at commit `5d6f31cd2`. Its complete-read parent hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`;
the approved statistic-lineage packet hash is
`7D4F2B86DA31EEA2ECAEE7573E3CF1629883B05A575FFEB694944A99D907DBE8`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, explicitly test one-month formation/holding rules within pooled
commodities, and include WTI in their futures universe. They do not test a
WTI-only within-month daily path-efficiency state, a continuous CFD, fixed-
dollar ATR risk, or the QM book. The daily horizon, threshold, execution, and
risk choices below are declared QM interpretations.

No source return, WTI-only alpha, probability, density, profit factor,
drawdown, trade count, transaction cost, CFD equivalence, neutrality, or
correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,625 registry
identities, 1,294 repository cards, and 45 Strategy-Wiki nodes and returned
`CLEAN`. After deterministic reservation it found only the expected slug and
strategy-ID self-hits for `QM5_41126`. Evidence is in the pre- and post-
allocation receipts under `artifacts/`.

Manual family review fixes the mechanical boundaries:

- `QM5_20187_wti-tsmom1m` follows the completed-month endpoint return without
  inspecting the daily path. This card requires every daily return ending in
  the month to pass the fixed path gate.
- `QM5_20274_wti-path-eff` uses twelve adjacent monthly returns over thirteen
  completed month ends and threshold 0.25. This card uses 17-23 daily returns
  ending inside one immediately completed month and threshold 0.20.
- `QM5_20288_wti-volnorm-mom` separately L2-normalizes twelve historical
  months and averages them. This card has one L1 denominator and no historical
  average.
- `QM5_41111_wti-mdaybreadth-mom` counts daily signs and discards magnitude.
  This card uses every absolute return magnitude.
- `QM5_41124_wti-mrms-coherence-mom` uses a squared-path/RMS denominator.
  This card uses the L1 absolute path, so shock concentration changes the two
  statistics differently.
- `QM5_41114`, `QM5_41115`, and `QM5_41117` aggregate fixed blocks, while
  `QM5_41122` uses ordered extreme states. This card has no block, vote,
  location, or sequence state.
- `QM5_41123_xauxag-mpath-eff-rv` fades a synchronized intermetal ratio with
  two opposite legs. This card follows one outright WTI series.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator
  pullback.

The WTI carrier, exact completed month, older boundary close, every daily
return ending in the month, net-to-absolute-path quotient, fixed inclusive
0.20 threshold, continuation direction, durable attempt, fixed-risk position,
and next-month exit are jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_PATH_EFFICIENCY_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `411260000`.
- Decision: first executable tick of a new broker-calendar month, within 180
  elapsed minutes of the raw current host D1 bar open.
- Signal data: every D1 return ending in the immediately completed calendar
  month; current-month prices are excluded.
- Position count: zero or one owned WTI position and at most one consumed
  attempt per broker `yyyymm`.
- Expected frequency: six positions/year as an ordering prior within a 5-7
  design range; Q02 must prove at least five in every scored full year.

## Completed-Month Contract

The newest completed D1 bar must belong to the immediately preceding calendar
month. Within a fixed 45-bar buffer, the package must contain exactly every
completed D1 close labeled with that prior year and month. Require 17 through
23 unique timestamps in strict order and one adjacent older close proving that
the package was not truncated. A current-month close, duplicate timestamp,
wrong month, missing boundary proof, invalid close, or session count outside
17-23 consumes the current month flat.

Let `C[0]` be the older boundary close and `C[1]..C[n]` be all completed-month
closes in chronological order. For `n` returns:

```text
r[j] = ln(C[j+1] / C[j]), j=0..n-1
N    = sum(r[j])
P    = sum(abs(r[j]))
E    = abs(N) / P

E >= 0.20 and N > 0 => BUY XTIUSD.DWX
E >= 0.20 and N < 0 => SELL XTIUSD.DWX
otherwise            => FLAT
```

Require finite arithmetic, `P>0`, and `E` in `[0,1]` within `1e-10`. Require
`N` to equal `ln(C[n]/C[0])` within `1e-10`. Exact-zero constituent returns
are valid and add zero to both sums. Zero path, zero net, below-threshold
efficiency, and invalid numerical state are flat. Every return ending in the
completed month contributes exactly once. No current-month price enters the
formula.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Repair malformed owned exposure before entry-only filters.
2. Require exact symbol, D1, EA ID, slot, risk mode, news modes, Friday-close
   input, and current raw D1 bar time.
3. Observe a new host D1 bar and derive current broker `yyyymm` from its raw
   bar time.
4. Admit only within `strategy_entry_grace_minutes=180` elapsed minutes of
   raw host bar open. Late attachment consumes the month flat.
5. Persist current `yyyymm` attempt before history, aggregation, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry that month.
6. Aggregate the exact immediately completed broker month. Require 17 through
   23 month-session closes and one adjacent older boundary close.
7. Build every chronological log return ending in the month; compute `N`,
   `P`, and `E`; require finite values, endpoint identity, `P>0`, and quotient
   bounds.
8. Require `E>=strategy_efficiency_threshold=0.20` and nonzero `N`.
9. Buy on positive `N` and sell on negative `N`. Equality, invalid state, and
   below-threshold state remain flat.
10. Require spread no greater than 1,500 points, a valid quote, and completed-
    bar `ATR(20,D1)`.
11. Freeze one server-side hard stop at `3.5*ATR`; use no profit target.
12. Size the one position from the fixed-dollar risk budget. Signal strength
    never changes risk.

### Attempt And Restart Contract

The attempt key is terminal-global, scoped by EA and symbol, and stores current
broker `yyyymm`. It is written before every fallible gate. Initialization
after the 180-minute grace consumes the missed month without a late trade.
Owned deal history and open-position checks are additional fail-closed guards.
An order rejection, stop-out, news block, spread failure, restart, invalid ATR,
or invalid history cannot create a same-month retry.

## 5. Exit Rules

1. Broker hard stops and framework kill switch remain authoritative.
2. Duplicated, wrong-symbol, wrong-type, wrong-magic, or stopless owned
   exposure is flattened immediately.
3. Close on the first tick whose broker `yyyymm` is later than the month stored
   for the position's entry attempt.
4. Forty elapsed calendar days is a stale repair only.

There is no take-profit, opposite-signal exit, trailing stop, break-even move,
partial close, Friday flattening, scale-in, pyramid, grid, martingale, or
discretionary close.

## 6. Filters (No-Trade Module)

- Require exact `XTIUSD.DWX`, D1, EA ID `41126`, slot 0, and magic
  `411260000`.
- Require `RISK_FIXED>0`, `RISK_PERCENT=0`, valid stop inputs, news temporal
  OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact calendar month, history and close
  validity, path-efficiency gate, spread ceiling, valid quote, completed ATR,
  stop, and sizing fail-closed.
- No fitted center, scale, sample variance, RMS, volatility forecast, sign
  count, block vote, sequence, range location, moving average, oscillator,
  seasonality, event calendar, volume, open interest, futures curve, external
  file, API, or manual runtime input is used.

## 7. Trade Management Rules

- Own either zero exposure or exactly one valid WTI position on the registered
  magic and symbol.
- Flatten duplicated, wrong-symbol, wrong-type, or stopless owned exposure
  before considering a new entry.
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
| `strategy_efficiency_threshold` | 0.20 | inclusive L1 path-efficiency gate |
| `strategy_numerical_tolerance` | 1e-10 | quotient and endpoint tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `strategy_deviation_points` | 20 | deterministic order deviation |
| `qm_friday_close_enabled` | false | full-month identity |

Every value is locked in the one backtest setfile and is not an optimization
surface.

## Source-Defined Rules

The source lineage supplies WTI membership, own-return continuation as a
testable family, one-month formation/hold, monthly renewal, and the audited
closed-form net-to-absolute-path statistic. It does not supply the within-
month daily horizon or 0.20 qualification.

## QM Interpretations

`MOP-WTI-MPATH-EFF-MOM-2026_S01` fixes broker labels, 17-to-23 month sessions,
older boundary inclusion, every daily log return ending in the month, the
bounded L1 statistic, fixed 0.20 threshold, continuation direction,
continuous-CFD mapping, entry grace, persistent attempt, spread cap, fixed-
dollar ATR risk, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
repair precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 closes and timestamps, broker time, symbol
metadata, executable quote, completed-bar ATR, framework position/deal state,
and terminal-global attempt state. No finite external dataset or event
calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)`; no target or signal-strength sizing.
- High risk: WTI gaps, geopolitical and inventory shocks, CFD roll/basis and
  financing, hard-stop slippage, sparse monthly decisions, and correlation
  with XNG or risk assets can dominate the premise.
- Path efficiency is descriptive, not confidence. A high value can arise from
  one dominant shock despite the L1 normalization.

## Kill Criteria

- Retire at zero trades or below five completed positions in any full post-
  warm-up scored year.
- Fail on wrong month labels, missing older boundary, wrong session count,
  current-month leakage, reversed/omitted/duplicated return, wrong signed or
  absolute sum, endpoint mismatch, wrong normalization, wrong inclusive 0.20
  gate, wrong-side entry, repeated attempt, hold beyond forty days, missing
  hard stop, invalid fixed-risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the carrier, threshold, direction, return
  inclusion, risk, stop, hold, spread, retry policy, or by adding another
  signal or optimization sweep.

## Strategy Allowability Check

| Gate | Verdict | Reasoning |
|---|---|---|
| R1 | PASS_WITH_WITHIN_MONTH_GATE_TRANSLATION_RISK | Peer-reviewed JFE paper, DOI, author-hosted complete read, durable hashes, explicit WTI membership, one-month lineage, and audited closed-form statistic; daily horizon and gate remain untested QM choices. |
| R2 | PASS | Month package, chronology, return inclusion, sums, endpoint identity, normalization, threshold, direction, attempt, risk, stop, and lifecycle are exact. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native `XTIUSD.DWX` D1 plus MT5 execution state provides every runtime input. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external feed, grid, or martingale. |

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed-risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: consumed month attempt, exact completed-month reconstruction,
  older boundary, all daily returns, signed/absolute sums, endpoint identity,
  fixed efficiency gate, spread/quote/ATR/stop checks, and one fixed-risk order.
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
| v1 | 2026-08-23 | initial source-bounded WTI completed-month path-efficiency card | G0 | APPROVED |
