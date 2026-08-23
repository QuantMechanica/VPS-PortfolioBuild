---
card_schema_version: 2
type: strategy
strategy_id: MOP-MEEK-WTI-MDAILY-MED-2026_S01
variant_id: MOP-MEEK-WTI-MDAILY-MED-2026_S01
source_id: MOP-MEEK-WTI-MDAILY-MED-2026
ea_id: QM5_41133
slug: wti-mdaily-median-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41133_wti-mdaily-median-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41133_wti_monthly_daily_median_momentum_g0.md
source_approval: decisions/2026-08-23_wti_monthly_daily_median_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Heather Meek; Susan A. Hoelscher"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Heather Meek; Susan A. Hoelscher"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Meek, H. and Hoelscher, S. A. (2023), Day-of-the-week effect: Petroleum and petroleum products, Cogent Economics & Finance 11(1), DOI 10.1080/23322039.2023.2213876."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded composite strategy-seeds/sources/MOP-MEEK-WTI-MDAILY-MED-2026/source.md"
    quality_tier: A
    role: wti_own_price_monthly_continuation_and_monthly_clock
  - type: peer_reviewed_open_access_paper_bounded_packet
    citation: "Meek, Heather and Hoelscher, Susan A. (2023), Day-of-the-week effect: Petroleum and petroleum products, Cogent Economics & Finance 11(1)."
    location: "DOI 10.1080/23322039.2023.2213876; complete-read packet strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md; bounded composite strategy-seeds/sources/MOP-MEEK-WTI-MDAILY-MED-2026/source.md"
    quality_tier: A
    role: wti_close_to_close_daily_log_return_lineage
strategy_mechanic: normalized-month-boundary-wti-immediately-completed-seventeen-to-twenty-three-session-daily-log-returns-full-sample-ascending-sort-ordinary-odd-even-median-sign-continuation-one-month-hold
sources:
  - "[[sources/MOP-MEEK-WTI-MDAILY-MED-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/robust-within-month-return-location]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-daily-return-median]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-daily-return-median, robust-location-direction, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411330000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year after exact month, ordinary-median, arithmetic, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WITHIN_MONTH_MEDIAN_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct-WTI completed-month ordinary daily-return median continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact month boundary, 17-23 returns ending in the month, older boundary inclusion, endpoint identity, full-sample sort, exact odd/even median, direction independent of the raw endpoint, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, immediately_completed_calendar_month, bounded_month_session_count, older_boundary_close, every_return_ending_in_month_once, chronological_log_return_orientation, endpoint_identity, full_sample_ascending_sort, ordinary_odd_even_median, raw_endpoint_not_a_gate, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 peer-reviewed WTI own-return and complete-read daily-return sources with the within-month ordinary-median translation disclosed; R2 exact month/return/endpoint/sort/odd-even-center/direction/attempt/risk/lifecycle; R3 native XTI D1 with label and CFD-basis risk; R4 deterministic arithmetic without a trained or banned signal; canonical pre-allocation dedup CLEAN and manual family review separates raw endpoint, daily breadth, daily persistence, tail trim, weekday-bucket median, cross-month robust estimators, and certified XNG RSI logic."
---

# QM5_41133 WTI Completed-Month Ordinary Daily-Return Median Momentum

## Hypothesis

WTI adjusts to production, inventory, transport, refining, hedging, and demand
shocks through persistent physical-energy regimes. A completed-month endpoint
can nevertheless be dominated by one shock or rollover-like outlier. Following
the ordinary median of every completed daily return tests whether the typical
daily move shares a direction that can persist into the next month.

This is direct crude-oil exposure outside the certified XAU, SP500, NDX, and
XNG carriers. Different instrument and logic do not prove profitability or
decorrelation. Q02 owns density and baseline economics; unchanged Q09 alone
owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-MEEK-WTI-MDAILY-MED-2026/source.md`, SHA-256
`5A8D292F78176BE727885DD95A1FF31C027ED15CE28B32C242567772D33FDD21`,
authorized before extraction by
`decisions/2026-08-23_wti_monthly_daily_median_momentum_source_approval.md`
at commit `37bb3f499` and extracted at commit `9b0a166c8`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, a monthly formation/renewal family, a pooled commodity `k=1,h=1`
implementation, and explicit WTI membership. Meek and Hoelscher document
close-to-close WTI daily log returns and heterogeneous daily behavior.
Neither source tests a WTI-only within-month ordinary median, a continuous
CFD, fixed-dollar ATR risk, or the QM book. The exact median, execution, and
risk rules below are declared QM interpretations.

No source alpha, return, probability, density, profit factor, drawdown, trade
count, cost, WTI-only efficacy, CFD equivalence, or portfolio-correlation
statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,632 registry
identities, 1,300 cards, and 45 Strategy Wiki nodes using the actual Company
Reference root and returned `CLEAN`. Evidence is
`artifacts/qm5_wti_mdaily_median_mom_preallocation_dedup_20260823.json`.

Manual family review fixes the mechanic boundaries:

- `QM5_20187_wti-tsmom1m` follows the unpartitioned completed-month endpoint.
- `QM5_20269_wti-medret-mom` takes a median across twelve completed monthly
  returns, not across the daily sample inside one month.
- `QM5_41111_wti-mdaybreadth-mom` counts positive and negative daily returns
  and requires sign-majority agreement with the raw endpoint. This card keeps
  daily magnitudes, uses an ordinary center, and does not gate on the endpoint.
- `QM5_41127_wti-mdaily-persist-mom` estimates adjacent demeaned-return
  persistence and follows the raw endpoint. This card uses a rank location and
  has no adjacency calculation.
- `QM5_41131_wti-mdaily-tailtrim-mom` removes one minimum and one maximum then
  sums the retained sample. This card uses only the one or two center values.
- `QM5_41132_wti-mweekday-med-mom` takes a median of five weekday-bucket
  means. This card has no weekday buckets and sorts all individual returns.
- earlier trim, Winsor, MAD-cap, trimean, pseudomedian, Huber, and bisquare
  systems transform twelve monthly returns rather than one month's daily
  sample.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only, short-horizon XNG
  oscillator pullback rather than symmetric monthly WTI trend.

The exact WTI carrier, immediately completed month, older boundary, every
daily return ending in the month, full-sample ascending sort, ordinary
odd/even median, symmetric direction, consumed attempt, fixed risk, and
next-month lifecycle are jointly load bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_ORDINARY_DAILY_RETURN_MEDIAN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `411330000`.
- Decision: first executable tick of a new normalized broker-calendar month,
  within 180 elapsed minutes of the raw current host D1 bar open.
- Signal data: one older boundary close plus every D1 close in the immediately
  completed normalized calendar month; current-month prices are excluded.
- Position count: zero or one owned WTI position and at most one consumed
  attempt per normalized broker `yyyymm`.
- Expected frequency: approximately 10-12 positions/year; Q02 retires below
  five in any full post-warm-up scored year.

## Energy-Label Normalization

Choose one label offset for the entire decision and history package. Use zero
when the raw current D1 label equals broker date. Permit `+1` calendar day only
when the raw D1 label is exactly one calendar day behind broker date. Apply
the selected offset to current and historical bars uniformly. Reject every
other offset, mixed convention, normalized collision, weekend ending label,
or non-increasing timestamp state. Raw bar-open time, not normalized label
time, owns the 180-minute entry grace.

## Completed-Month And Ordinary-Median Contract

Within a fixed 45-bar buffer, the newest completed normalized D1 bar must
belong to the immediately preceding calendar month. Collect every unique bar
in that month and require 17 through 23 sessions plus one adjacent older bar
from the preceding month proving the left boundary. Reverse selected closes
into chronological order beginning with the older boundary.

For chronological closes `C[-1], C[0]..C[n-1]`, define:

```text
r[j] = ln(C[j] / C[j-1]), j=0..n-1
sorted = ascending(r[0], ..., r[n-1])

if n is odd:
    daily_median = sorted[n/2]
else:
    daily_median = (sorted[n/2-1] + sorted[n/2]) / 2

daily_median > 0 => BUY XTIUSD.DWX
daily_median < 0 => SELL XTIUSD.DWX
otherwise        => FLAT
```

Require positive finite closes, finite returns, valid center indexes, and a
finite median. Verify that `sum(r)` equals `ln(C[n-1]/C[-1])` within `1e-10`.
Sort without rounding and use every return exactly once. A zero median,
endpoint mismatch, invalid count, malformed history, or invalid arithmetic
stays flat. The raw endpoint may agree or disagree and is diagnostic only.
Neither signal magnitude nor endpoint magnitude changes risk.

## Rules

The entry, exit, filter, management, and risk rules below are the complete
authorized baseline. There is no optimization surface, alternate median
formula, endpoint confirmation, or fallback signal.

## 4. Entry Rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require exact `XTIUSD.DWX`, D1, EA `41133`, slot zero, registered magic,
   locked fixed-risk inputs, and one uniform energy-label convention.
3. Detect only the first executable D1 bar of a new normalized broker month
   and require no more than 180 elapsed minutes since its raw bar open.
4. Persist the normalized current `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order gates. Never retry that month.
5. Require no owned position and no same-magic entry deal already recorded in
   the current normalized broker month.
6. Reconstruct the exact immediately completed normalized month plus one
   older boundary close. Require 17-23 unique month sessions, positive finite
   closes, strict chronology, and no current-month observation.
7. Form one chronological log return ending on every completed-month session
   and verify endpoint identity.
8. Sort all returns ascending. Use exact index `n/2` for odd `n` or the
   arithmetic mean of indexes `n/2-1` and `n/2` for even `n`.
9. Buy for a strict positive median and sell for a strict negative median.
   Equality, invalid arithmetic, or malformed history consumes the month flat.
10. Require a valid executable quote and no genuinely positive spread wider
    than 1,500 points. Modeled zero `.DWX` spread is valid.
11. Require completed-bar `ATR(20,D1)`, valid point/digit/volume metadata, and
    valid `RISK_FIXED` sizing.
12. Open at most one market position with a frozen `3.5*ATR(20,D1)` broker
    hard stop and no take-profit.

### Attempt And Restart Contract

The attempt key is terminal-global and scoped by EA and symbol. It stores the
normalized decision `yyyymm` before every fallible gate. Initialization clears
only a future-dated tester residue. Late attachment consumes the missed month
without a trade. Owned deal history and open-position checks are additional
fail-closed guards. A flat signal, invalid history, news/spread/quote/ATR
block, order rejection, stop-out, or restart cannot create a same-month retry.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, wrong-type,
   invalid-volume, invalid-open-time, or stopless owned exposure.
3. Close on the first tick whose normalized broker `yyyymm` is later than the
   month containing the position's normalized entry time.
4. Forty elapsed calendar days is a stale repair only.

There is no target, opposite-signal exit, trail, break-even move, partial
close, Friday flatten, scale-in, pyramid, grid, martingale, hedge, or
discretionary close.

## 6. Filters (No-Trade Module)

- Exact symbol, period, EA ID, slot, magic, risk, news, Friday, and frozen
  strategy inputs.
- Framework kill switch and ownership controls remain authoritative.
- Apply uniform label normalization, entry grace, durable attempt, exact
  month membership, session bounds, boundary proof, chronology, close and
  return validity, endpoint identity, ascending sort, exact median, spread,
  quote, ATR, sizing, and stop checks fail closed.
- Runtime cannot read current-month signal prices, futures curves, inventory,
  volume, open interest, fitted conditional-variance output, external
  files/APIs, trained output, prior pipeline results, or manual signals.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411330000`.
- Manage malformed, later-month, stale, and kill-switch exits every tick
  before entry evaluation.
- Freeze the original hard stop; never widen, trail, remove, or replace it.
- Persist the monthly attempt across restart and supplement it with owned
  position/deal-history checks.
- Never retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_bars_d1` | 45 | bounded month plus boundary buffer |
| `strategy_min_month_sessions` | 17 | completed-month lower bound |
| `strategy_max_month_sessions` | 23 | completed-month upper bound |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_numerical_tolerance` | 1e-10 | endpoint-identity tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month lifecycle |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

Every value is locked in the one baseline setfile. Changing the observation
grain, sample membership, median formula, direction, month, risk, or lifecycle
requires a new identity and complete G0/Q01 cycle.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return direction, monthly formation
and renewal, pooled commodity one-month lineage, and explicit WTI membership.
Meek and Hoelscher supply WTI close-to-close daily-log-return lineage. Neither
source supplies the within-month ordinary median statistic.

## QM Interpretations

`MOP-MEEK-WTI-MDAILY-MED-2026_S01` fixes the normalized broker month, 17-23
sessions, older boundary, every daily log return ending in the month,
endpoint identity, full-sample sort, ordinary odd/even median, direction
without endpoint agreement, continuous-CFD mapping, attempt ledger,
fixed-dollar ATR risk, spread ceiling, and next-month exit. Their efficacy is
unproven until deterministic pipeline evidence exists.

## Explicitly Out Of Scope

- raw endpoint confirmation, sign counts, weekday buckets, trimming,
  Winsorization, fitted robust-location iterations, return thresholds, or
  volatility scaling;
- current-month returns, rolling futures construction, futures curves,
  inventory, volume, open interest, news, analyst data, external files/APIs,
  or prior pipeline results;
- target, trail, break-even, partial close, scale-in, pyramid, grid,
  martingale, discretionary override, portfolio admission, or live use.

## Runtime Data Contract

Use native MT5 `XTIUSD.DWX` D1 OHLC, broker time, quote/spread, symbol
metadata, completed-bar ATR, framework kill-switch state, owned positions,
deal history, and terminal-global attempt state only. Fail closed on missing,
stale, duplicated, nonfinite, mislabelled, or inconsistent state.

## Risk

- Backtest mode only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- One frozen `3.5*ATR(20,D1)` hard stop; no target; one position maximum.
- The median sign never changes risk size. Q02 owns density and baseline
  economics. Q09 alone may determine book correlation.
- CFD/futures basis, daily labels, gaps, tails, spread, slippage, financing,
  stop execution, and one-instrument concentration remain kill risks.

## Testing And Falsification

- Unit/reference vectors must cover odd and even sample sizes, ascending and
  descending inputs, duplicate center values, exact zero, nonfinite values,
  invalid session counts, endpoint agreement and disagreement, label offsets,
  month boundaries, attempt persistence, risk locks, and next-month exit.
- Card schema lint, strict compile, build guardrails, symbol-scope validation,
  registry/resolver verification, and setfile validation must pass before Q02.
- Q02 retires on zero trades, below five completed trades in any full scored
  post-warm-up year, nonpositive governed economics, or any rule defect.
- Failure does not authorize median, sample, endpoint, direction, carrier,
  threshold, risk, stop, or lifecycle changes.

## V5 Framework Alignment

| Card rule | V5 module | Planned implementation |
|---|---|---|
| exact inputs, risk/news/Friday locks | No-Trade | `Strategy_NoTradeFilter` |
| month clock, attempt, history, returns, sort, median, quote/spread/ATR/stop | Trade Entry | `Strategy_EntrySignal` and deterministic helpers |
| malformed exposure and monthly/stale lifecycle | Trade Management | `Strategy_ManageOpenPosition` |
| no separate discretionary exit signal | Trade Close | `Strategy_ExitSignal` returns false; management owns authorized exits |
| framework news compatibility, axes locked OFF | No-Trade hook | `Strategy_NewsFilterHook` |

## Traceability Checklist

- [x] Durable source approval predates extraction.
- [x] Governed source packets and retrieval receipt read completely.
- [x] Source claims separated from QM translations.
- [x] Canonical pre-allocation dedup returned CLEAN.
- [x] Manual family review distinguishes daily median from all close neighbors.
- [x] R1-R4 recorded and ML/prohibited signal boundary explicit.
- [x] One backtest-only fixed-risk baseline declared.
- [x] Q02 frequency kill and Q09 decorrelation ownership fixed.
- [x] No T_Live, AutoTrading, manifest, portfolio-gate, or live authority.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-23 | initial WTI completed-month ordinary daily-return median momentum card | G0 | APPROVED |

## Phase Log

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-23 | APPROVED_SOURCE | `decisions/2026-08-23_wti_monthly_daily_median_momentum_source_approval.md` |
| G0 Research Intake | 2026-08-23 | APPROVED | `decisions/2026-08-23_qm5_41133_wti_monthly_daily_median_momentum_g0.md` |
| Q01 Build | 2026-08-23 | PENDING | deterministic registry allocation and strict build required |
| Q02 Baseline | 2026-08-23 | NOT_ENQUEUED | requires Q01 PASS and paced CPU capacity |
