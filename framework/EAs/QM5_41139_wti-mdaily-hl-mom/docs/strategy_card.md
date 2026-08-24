---
card_schema_version: 2
type: strategy
strategy_id: MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026_S01
variant_id: MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026_S01
source_id: MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026
ea_id: QM5_41139
slug: wti-mdaily-hl-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41139_wti-mdaily-hl-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-24
created_by: Research+Development
last_updated: 2026-08-24
g0_status: APPROVED
g0_decision: decisions/2026-08-24_qm5_41139_wti_monthly_daily_hodges_lehmann_momentum_g0.md
source_approval: decisions/2026-08-24_wti_monthly_daily_hodges_lehmann_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Heather Meek; Susan A. Hoelscher"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Heather Meek; Susan A. Hoelscher"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Meek, H. and Hoelscher, S. A. (2023), Day-of-the-week effect: Petroleum and petroleum products, Cogent Economics & Finance 11(1), DOI 10.1080/23322039.2023.2213876; governed H-L arithmetic precedent MOP-WTI-HLRET-2026."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded composite strategy-seeds/sources/MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026/source.md"
    quality_tier: A
    role: wti_own_price_monthly_continuation_and_monthly_clock
  - type: peer_reviewed_open_access_paper_bounded_packet
    citation: "Meek, Heather and Hoelscher, Susan A. (2023), Day-of-the-week effect: Petroleum and petroleum products, Cogent Economics & Finance 11(1)."
    location: "DOI 10.1080/23322039.2023.2213876; complete-read packet strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md; bounded composite strategy-seeds/sources/MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026/source.md"
    quality_tier: A
    role: wti_close_to_close_daily_log_return_lineage
  - type: governed_method_precedent
    citation: "QuantMechanica bounded Hodges-Lehmann-style return-location mechanization."
    location: "strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md"
    quality_tier: internal_governed
    role: inclusive_pair_enumeration_and_exact_median_arithmetic_only
strategy_mechanic: normalized-month-boundary-wti-immediately-completed-seventeen-to-twenty-three-session-daily-log-returns-all-inclusive-self-cross-pair-averages-dynamic-hodges-lehmann-pseudomedian-sign-continuation-one-month-hold
sources:
  - "[[sources/MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/robust-within-month-return-location]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-daily-return-hodges-lehmann-pseudomedian]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-daily-return-pseudomedian, robust-location-direction, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411390000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year after exact month, pseudomedian, arithmetic, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WITHIN_MONTH_PSEUDOMEDIAN_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct-WTI completed-month daily-return Hodges-Lehmann continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact month boundary, 17-23 returns ending in the month, older boundary, endpoint identity, every inclusive self/cross pair, dynamic count, exact odd/even median, direction independent of the raw endpoint, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, immediately_completed_calendar_month, bounded_month_session_count, older_boundary_close, every_return_ending_in_month_once, chronological_log_return_orientation, endpoint_identity, inclusive_pair_bounds, self_pair_identity, dynamic_pair_count, ascending_sort, odd_even_pseudomedian, raw_endpoint_not_a_gate, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-24 and decisions/2026-08-24_qm5_41139_wti_monthly_daily_hodges_lehmann_momentum_g0.md: R1 peer-reviewed WTI own-return and daily-return sources plus governed H-L arithmetic with translation risk explicit; R2 exact label/month/return/endpoint/inclusive-pair/count/self-pair/sort/odd-even-center/direction/attempt/risk/lifecycle; R3 native XTI D1 with label and CFD-basis risk; R4 deterministic arithmetic without a trained or banned signal; canonical pre-allocation dedup found one fuzzy raw-median neighbor, manually resolved as a different estimator."
---

# QM5_41139 WTI Completed-Month Daily-Return Hodges-Lehmann Momentum

## Hypothesis

WTI adjusts to production, inventory, transport, refining, hedging, and demand
shocks through persistent physical-energy regimes. A completed-month endpoint
or ordinary daily median can underrepresent the distribution of typical moves.
Following the Hodges-Lehmann-style pseudomedian of every completed daily
return, represented both alone and in every unordered cross-pair, tests a
robust central displacement that may persist into the following month.

This is direct crude-oil exposure outside the certified XAU, SP500, NDX, and
XNG carriers. Different instrument and logic do not prove profitability or
decorrelation. Q02 owns density and baseline economics; unchanged Q09 alone
owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026/source.md`,
SHA-256
`0B913EE46ADDC651A42572071A9C73547473CB683800A2F60B19FB53C1BDA6E4`,
authorized before extraction by
`decisions/2026-08-24_wti_monthly_daily_hodges_lehmann_momentum_source_approval.md`
at commit `fd8b238d4` and committed as a bounded packet at `bb2a24a4c`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, a monthly formation/renewal family, a pooled commodity `k=1,h=1`
implementation, and explicit WTI membership. Meek and Hoelscher document
close-to-close WTI daily log returns and heterogeneous daily behavior. The
governed H-L packet supplies exact inclusive-pair and median arithmetic only.
None tests a WTI-only within-month daily pseudomedian, a continuous CFD,
fixed-dollar ATR risk, or the QM book. The exact statistic, execution, and
risk rules below are declared QM interpretations.

No source alpha, return, probability, density, profit factor, drawdown, trade
count, cost, WTI-only efficacy, CFD equivalence, neutrality, or portfolio-
correlation statistic is imported. No new public route is used.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker authenticated and scanned
4,638 registry identities, 1,306 cards, and 45 Strategy Wiki nodes using the
actual Company Reference root. It found no exact identity and surfaced only
`QM5_41133_wti-mdaily-median-mom` as a fuzzy neighbor. Evidence is
`artifacts/qm5_wti_mdaily_hl_mom_preallocation_dedup_20260824.json`.

Manual family review fixes the mechanical boundaries:

- `QM5_41133` sorts the raw daily returns and uses only one/two center values.
  This card retains all raw returns, forms every inclusive self/cross-pair
  average, and takes the exact median of 153-276 derived values.
- `QM5_41134_wti-mdaily-iqrmean-mom` deletes both raw tails and averages the
  central half. This card removes no observation and estimates a different
  pairwise-average location functional.
- `QM5_20276_wti-hl-mom` applies the same arithmetic family to twelve monthly
  WTI returns spanning a year. This card uses 17-23 daily returns inside only
  the immediately completed month.
- `QM5_41138_xauxag-mdaily-hl-rv` uses synchronized intermetal returns, fades
  the estimator, and owns two legs. This card uses outright WTI returns,
  follows the estimator, and owns one energy position.
- endpoint momentum, sign breadth, tail trimming, weekday buckets,
  persistence, path, RMS, and sequence cards do not enumerate inclusive
  pairwise return averages.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only, short-horizon XNG
  oscillator pullback rather than symmetric monthly WTI trend.

The exact WTI carrier, immediately completed month, older boundary, every
daily return ending in the month, inclusive self/cross-pair enumeration,
dynamic pair count, exact odd/even pseudomedian, symmetric direction,
consumed attempt, fixed risk, and next-month lifecycle are jointly load
bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `411390000`.
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

## Completed-Month Pseudomedian Contract

Within a fixed 45-bar buffer, the newest completed normalized D1 bar must
belong to the immediately preceding calendar month. Collect every unique bar
in that month and require 17 through 23 sessions plus one adjacent older bar
from the preceding month proving the left boundary. Reverse selected closes
into chronological order beginning with the older boundary.

For chronological closes `C[-1], C[0]..C[n-1]`, define:

```text
r[j] = ln(C[j] / C[j-1]), j=0..n-1

k = 0
for i = 0..n-1:
  for j = i..n-1:
    w[k] = (r[i] + r[j]) / 2
    k += 1

m = n * (n + 1) / 2
require k == m
sorted = ascending(w[0..m-1])

hl = sorted[m/2]                         when m is odd
hl = (sorted[m/2-1] + sorted[m/2]) / 2  when m is even

hl > 0 => BUY XTIUSD.DWX
hl < 0 => SELL XTIUSD.DWX
otherwise => FLAT
```

Require positive finite closes, finite returns and pairwise values,
`17 <= n <= 23`, and `m=n*(n+1)/2` in `[153,276]`. Verify every self-pair
against its source return and verify `sum(r)` against
`ln(C[n-1]/C[-1])` within `1e-10`. Sort without rounding. Exact-zero returns
and duplicated pairwise values are valid. A zero pseudomedian, pair-count or
self-pair defect, endpoint mismatch, invalid count, malformed history, or
invalid arithmetic stays flat. The raw endpoint is diagnostic only and
cannot gate direction. Neither magnitude changes risk.

## Rules

The entry, exit, filter, management, and risk rules below are the complete
authorized baseline. There is no optimization surface, alternate median
formula, endpoint confirmation, or fallback signal.

## 4. Entry Rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require exact `XTIUSD.DWX`, D1, EA `41139`, slot zero, registered magic,
   locked fixed-risk inputs, and one uniform energy-label convention.
3. Detect only the first executable D1 bar of a new normalized broker month
   and require no more than 180 elapsed minutes since its raw bar open.
4. Persist normalized current `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry that month.
5. Require no owned position and no same-magic entry deal already recorded in
   the current normalized broker month.
6. Reconstruct the exact immediately completed normalized month plus one
   older boundary close. Require 17-23 unique month sessions, positive finite
   closes, strict chronology, and no current-month observation.
7. Form one chronological log return ending on every completed-month session
   and verify endpoint identity.
8. Enumerate every inclusive pair `(i,j)` with `0 <= i <= j < n`, append each
   average exactly once, require `n*(n+1)/2` values in `[153,276]`, and verify
   every self-pair.
9. Sort the full pairwise array and compute the exact odd/even median. Buy for
   a strict positive value and sell for a strict negative value. Equality or
   invalid state consumes the month flat.
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
  return validity, endpoint identity, inclusive pair count, self-pairs,
  ascending sort, exact median, spread, quote, ATR, sizing, and stop checks
  fail closed.
- Runtime cannot read current-month signal prices, futures curves, inventory,
  volume, open interest, fitted conditional-variance output, external
  files/APIs, trained output, prior pipeline results, or manual signals.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411390000`.
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
| `strategy_max_pair_count` | 276 | bounded inclusive-pair array ceiling |
| `strategy_numerical_tolerance` | 1e-10 | endpoint/self-pair tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `strategy_deviation_points` | 20 | deterministic order deviation |
| `qm_friday_close_enabled` | false | preserve full-month lifecycle |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

Every value is locked in the one baseline setfile. Changing observation grain,
sample membership, pair convention, median formula, direction, month, risk,
or lifecycle requires a new identity and complete G0/Q01 cycle.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return direction, monthly formation
and renewal, pooled commodity one-month lineage, and explicit WTI membership.
Meek and Hoelscher supply WTI close-to-close daily-log-return lineage. The
governed H-L packet supplies exact inclusive-pair arithmetic only. None
supplies this within-month pseudomedian strategy.

## QM Interpretations

`MOP-HL-MEEK-WTI-MDAILY-HL-MOM-2026_S01` fixes the normalized broker month,
17-23 sessions, older boundary, every daily log return ending in the month,
endpoint identity, inclusive pair enumeration, dynamic pair count, exact
odd/even pseudomedian, direction without endpoint agreement, continuous-CFD
mapping, attempt ledger, fixed-dollar ATR risk, spread ceiling, and next-month
exit. Their efficacy is unproven until deterministic pipeline evidence exists.

## Explicitly Out Of Scope

- raw endpoint confirmation, ordinary raw-return median, trimming,
  Winsorization, fitted robust-location iterations, sign counts, weekday
  buckets, return thresholds, or volatility scaling;
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
- Pseudomedian sign and magnitude never change risk size. Q02 owns density and
  baseline economics. Q09 alone may determine book correlation.
- CFD/futures basis, daily labels, gaps, tails, spread, slippage, financing,
  stop execution, and one-instrument concentration remain kill risks.

## Testing And Falsification

- Unit/reference vectors must cover odd/even pair counts, ascending and
  descending inputs, duplicates, exact zero, nonfinite values, invalid
  session/pair counts, self-pairs, endpoint agreement/disagreement, label
  offsets, month boundaries, attempt persistence, risk locks, and exit.
- Card schema lint, strict compile, build guardrails, symbol-scope validation,
  registry/resolver verification, and setfile validation must pass before Q02.
- Q02 retires on zero trades, below five completed positions in any full
  scored post-warm-up year, nonpositive governed economics, or rule defect.
- Failure does not authorize sample, pair, median, endpoint, direction,
  carrier, threshold, risk, stop, or lifecycle changes.

## V5 Framework Alignment

| Card rule | V5 module | Planned implementation |
|---|---|---|
| exact inputs, risk/news/Friday locks | No-Trade | `Strategy_NoTradeFilter` |
| month clock, attempt, history, returns, inclusive pairs, sort, median, quote/spread/ATR/stop | Trade Entry | `Strategy_EntrySignal` and deterministic helpers |
| malformed exposure and monthly/stale lifecycle | Trade Management | `Strategy_ManageOpenPosition` |
| no separate discretionary exit signal | Trade Close | `Strategy_ExitSignal` returns false; management owns authorized exits |
| framework news compatibility, axes locked OFF | No-Trade hook | `Strategy_NewsFilterHook` |

## Traceability Checklist

- [x] Durable source approval predates extraction.
- [x] Governed source packets and retrieval receipt read completely.
- [x] Source claims separated from QM translations.
- [x] Canonical pre-allocation dedup found no exact identity.
- [x] Manual family review distinguishes the one fuzzy raw-median neighbor.
- [x] R1-R4 recorded and ML/prohibited signal boundary explicit.
- [x] One backtest-only fixed-risk baseline declared.
- [x] Q02 frequency kill and Q09 decorrelation ownership fixed.
- [x] No T_Live, AutoTrading, manifest, portfolio-gate, or live authority.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-24 | initial WTI completed-month daily-return pseudomedian momentum card | G0 | APPROVED |

## Phase Log

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-24 | APPROVED_SOURCE | `decisions/2026-08-24_wti_monthly_daily_hodges_lehmann_momentum_source_approval.md` |
| G0 Research Intake | 2026-08-24 | APPROVED | `decisions/2026-08-24_qm5_41139_wti_monthly_daily_hodges_lehmann_momentum_g0.md` |
| Q01 Build | - | PENDING_BUILD | - |
| Q02 Baseline | - | NOT_ENQUEUED_Q01_PENDING | - |
