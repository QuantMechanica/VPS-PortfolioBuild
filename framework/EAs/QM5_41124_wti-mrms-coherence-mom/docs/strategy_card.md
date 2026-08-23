---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MRMS-COHERENCE-MOM-2026_S01
variant_id: MOP-WTI-MRMS-COHERENCE-MOM-2026_S01
source_id: MOP-WTI-MRMS-COHERENCE-MOM-2026
ea_id: QM5_41124
slug: wti-mrms-coherence-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41124_wti-mrms-coherence-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41124_wti_monthly_mean_rms_coherence_momentum_g0.md
source_approval: decisions/2026-08-23_wti_monthly_mean_rms_coherence_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded child strategy-seeds/sources/MOP-WTI-MRMS-COHERENCE-MOM-2026/source.md"
    quality_tier: A
    role: wti_own_return_continuation_monthly_clock_and_volatility_scaling_lineage
strategy_mechanic: exact-wti-immediately-completed-broker-month-seventeen-to-twenty-three-daily-log-returns-absolute-mean-to-root-mean-square-coherence-at-least-zero-point-one-six-same-sign-one-month-momentum
sources:
  - "[[sources/MOP-WTI-MRMS-COHERENCE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-path-coherence]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/mean-to-root-mean-square-coherence]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, completed-month-path-coherence, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 411240000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-7 positions per full post-warm-up year after the fixed coherence and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WITHIN_MONTH_GATE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct-WTI completed-month path-coherence sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact calendar membership, older boundary close, every daily return ending in the month, signed sum, squared path, bounded mean-to-RMS quotient, inclusive 0.16 threshold, same-sign direction, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, immediate_completed_calendar_month, month_session_count, older_boundary_close, chronological_log_return_orientation, every_month_return_once, signed_sum, squared_path, endpoint_identity, fixed_coherence_threshold, numerical_bounds, same_sign_direction, monthly_attempt_state, aggregate_fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 PASS peer-reviewed WTI own-return and monthly-clock lineage with the within-month coherence gate disclosed as an untested translation; R2 PASS exact month package, return inclusion, signed and squared sums, bounded normalization, fixed 0.16 gate, direction, attempt, risk and lifecycle; R3 PASS registered native WTI D1 route with continuous-CFD basis risk; R4 PASS deterministic arithmetic without banned signal; pre-allocation dedup CLEAN and post-allocation only self-hits."
---

# QM5_41124 WTI Completed-Month Mean-to-RMS Coherence Momentum

## Hypothesis

WTI can sustain slow directional regimes while production, capital spending,
inventories, refining, transport, hedging, and demand adjust. A one-month
endpoint return can be produced either by broadly aligned daily moves or by a
noisy path whose final displacement is accidental. Following only a completed
month whose signed daily mean is material relative to its return RMS tests
whether directional path coherence selects a more structural WTI move.

The direct crude-oil carrier adds a different economic driver from the
certified XAU/SP500/NDX/XNG book. That does not prove profitability,
decorrelation, or portfolio suitability. Q02 owns density and baseline
economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-MRMS-COHERENCE-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-23_wti_monthly_mean_rms_coherence_momentum_source_approval.md`
at commit `04f9f9b01`.

Moskowitz, Ooi, and Pedersen support testing an instrument's own completed
return, a one-month formation/hold inside a commodity portfolio, monthly
renewal, and volatility-aware implementation. Their universe explicitly
includes NYMEX WTI. The source does not establish a WTI-specific one-month
effect and does not use the daily mean-to-RMS qualification below.

The exact broker-month package, older boundary close, daily log returns,
fixed 0.16 threshold, Darwinex continuous CFD, fixed-dollar ATR risk, spread
cap, entry grace, and restart ledger are declared QM interpretations. No
source alpha, return, probability, trade density, profit factor, drawdown,
cost, CFD equivalence, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,623 registry
identities, 1,292 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`.
After deterministic allocation it found only the expected slug and strategy-
ID self-hits for `QM5_41124`. Evidence is in the pre- and post-allocation
receipts under `artifacts/`.

Manual family review fixes the mechanical boundaries:

- `QM5_20187_wti-tsmom1m` uses only the immediately completed month-end return
  sign and attempts every valid month. This card requires that endpoint sign
  to pass a fixed all-daily-return coherence gate.
- `QM5_20288_wti-volnorm-mom` separately divides each of twelve historical
  month returns by its own daily L2 path, then equally averages all twelve
  normalized states without a threshold. This card uses one immediately
  completed month and one bounded 0.16 qualification.
- `QM5_20274_wti-path-eff` uses a twelve-month net return divided by the L1
  sum of twelve monthly absolute returns. This card uses one month of daily
  returns and an RMS/L2 denominator.
- `QM5_41111_wti-mdaybreadth-mom` counts daily signs while discarding
  magnitudes. This card uses every squared magnitude and is return-order
  invariant.
- `QM5_41114`, `QM5_41115`, and `QM5_41117` aggregate fixed halves, thirds,
  or early/late blocks. `QM5_41122` uses extreme-state sequence order. This
  card has no block, vote, location, or sequence state.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator
  pullback.

The WTI carrier, exact completed calendar month, older boundary close, every
daily return ending in the month, signed sum, squared path, bounded
mean-to-RMS quotient, inclusive 0.16 threshold, continuation direction,
durable attempt, fixed risk, and next-month exit are jointly load-bearing.
Verdict:
`CLEAN_WTI_COMPLETED_MONTH_MEAN_RMS_COHERENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Exact host and traded symbol: `XTIUSD.DWX`, D1, slot 0, planned magic
  `411240000`.
- Decision: first executable tick of a new broker-calendar month, within 180
  elapsed minutes of the raw current D1 bar open.
- Signal data: exact immediately completed calendar month only; every
  current-month close is excluded.
- Position count: zero or one owned WTI position and at most one consumed
  attempt per broker `yyyymm`.
- Expected frequency: six positions/year as an ordering prior inside a 5-7
  design range; Q02 must prove at least five in every scored full year.

## Completed-Month Contract

Within a fixed 45-bar buffer, collect every completed D1 bar labeled with the
immediately prior broker year and month. Require 17 through 23 unique bars in
strict reverse-time order and one adjacent older bar whose month is exactly
the preceding calendar month. A current-month bar, duplicate or nondecreasing
timestamp, wrong label, missing boundary proof, nonpositive close, or session
count outside 17-23 consumes the current month flat.

Put the older boundary close first, followed by the completed-month closes in
chronological order. If there are `n` completed-month sessions, form exactly
`n` returns:

```text
r[j] = ln(P[j+1] / P[j]), j=0..n-1
N    = sum(r[j])
Q    = sum(r[j]^2)
C    = abs(N) / sqrt(n * Q)

C >= 0.16 and N > 0 => BUY WTI
C >= 0.16 and N < 0 => SELL WTI
otherwise            => FLAT
```

Require finite arithmetic, `Q>0`, and `C` in `[0,1]` within `1e-10`. Require
`N` to equal `ln(P[n]/P[0])` within `1e-10`. Exact-zero constituent returns are
valid and add zero to both sums. A zero path, zero net, below-threshold
coherence, identity failure, or invalid numerical state is flat. Every return
ending on a session in the completed month contributes exactly once.

There is no demeaning, sample-variance correction, degrees-of-freedom term,
annualization, rounding, fitting, or signal-strength sizing.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Repair malformed owned exposure before entry-only filters.
2. Require exact symbol, D1, EA ID, slot, risk mode, news modes, Friday-close
   inputs, and locked strategy parameters.
3. Observe a new host D1 bar and derive current broker `yyyymm` from its raw
   bar time.
4. Admit only within `strategy_entry_grace_minutes=180` elapsed minutes of
   raw host bar open. Late attachment consumes the month flat.
5. Persist current `yyyymm` before history, aggregation, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that month.
6. Aggregate the exact immediately completed broker month. Require 17 through
   23 valid month-session closes and one older adjacent-month boundary close.
7. Build every chronological return ending in the month. Accumulate `N` and
   `Q` from one loop and verify the boundary-to-final endpoint identity.
8. Require `Q>0`, bounded finite `C`, `C>=0.16`, and nonzero `N`.
9. Buy for positive `N` and sell for negative `N`. Equality, invalid state,
   and below-threshold state remain flat.
10. Require spread no greater than 1,500 points, an executable quote, and
    valid completed-bar `ATR(20,D1)`.
11. Freeze one hard stop `3.5*ATR` from entry and use no target.
12. Size the one position so normalized stop risk is at or below the single
    `RISK_FIXED` budget. Coherence and return magnitude never alter risk.

### Attempt And Restart Contract

The attempt key is terminal-global and scoped by EA and symbol. It stores the
current broker `yyyymm` before every fallible gate. Initialization after the
180-minute grace consumes the missed month without a late trade. Owned deal
history and open-position checks are additional fail-closed guards. An order
rejection, stop-out, news block, spread failure, restart, invalid ATR, or
invalid history cannot create a same-month retry.

## 5. Exit Rules

1. Broker hard stop and framework kill switch remain authoritative.
2. Duplicate, wrong-symbol, wrong-magic, invalid-type, or stopless owned
   exposure is flattened before a new entry is considered.
3. Close on the first tick whose broker `yyyymm` is later than the entry
   attempt month.
4. Forty elapsed calendar days is a stale repair only.

There is no take-profit, opposite-signal exit, trailing stop, break-even move,
partial close, Friday flattening, scale-in, pyramid, grid, martingale,
reversal, or discretionary close.

## 6. Filters (No-Trade Module)

- Require exact `XTIUSD.DWX`, D1, EA ID `41124`, and slot 0.
- Require `RISK_FIXED>0`, `RISK_PERCENT=0`, valid stop inputs, news temporal
  OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact completed-month history, older
  boundary proof, chronological returns, signed/squared arithmetic, endpoint
  identity, coherence gate, spread, quote, ATR, stop, and sizing fail-closed.
- No moving average, oscillator, fitted mean, sample variance, volatility
  forecast, sign count, block vote, sequence, range location, seasonality,
  event calendar, volume, open interest, futures curve, external file, API, or
  manual runtime input is used.

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
| `strategy_coherence_threshold` | 0.16 | inclusive mean-to-RMS gate |
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
testable family, one-month formation/hold, monthly renewal, and volatility-
aware implementation. It does not supply the within-month RMS statistic or
0.16 qualification.

## QM Interpretations

`MOP-WTI-MRMS-COHERENCE-MOM-2026_S01` fixes broker labels, 17-to-23 month
sessions, older boundary inclusion, every daily log return ending in the
month, the bounded mean-to-RMS formula, fixed 0.16 threshold, continuation
direction, continuous-CFD mapping, entry grace, persistent attempt, spread
cap, fixed-dollar ATR risk, and lifecycle.

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
- Path coherence is descriptive, not confidence. A high value can arise from
  one dominant shock despite the RMS normalization.

## Kill Criteria

- Retire at zero trades or below five completed positions in any full post-
  warm-up scored year.
- Fail on wrong month labels, missing older boundary, wrong session count,
  current-month leakage, reversed/omitted/duplicated return, wrong signed or
  squared sum, endpoint mismatch, wrong normalization, wrong inclusive 0.16
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
| R1 | PASS_WITH_WITHIN_MONTH_GATE_TRANSLATION_RISK | Peer-reviewed JFE paper, DOI, author-hosted complete read, durable hashes, explicit WTI membership, and one-month lineage; coherence gate remains an untested QM choice. |
| R2 | PASS | Month package, chronology, return inclusion, sums, normalization, threshold, direction, attempt, risk, stop, and lifecycle are exact. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native `XTIUSD.DWX` D1 plus MT5 execution state provides every runtime input. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external feed, grid, or martingale. |

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed-risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: consumed month attempt, exact completed-month reconstruction,
  older boundary, all daily returns, signed/squared sums, endpoint identity,
  fixed coherence gate, spread/quote/ATR/stop checks, and one fixed-risk order.
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
| v1 | 2026-08-23 | initial source-bounded WTI completed-month mean-to-RMS coherence card | G0 | APPROVED |

