---
card_schema_version: 2
type: strategy
strategy_id: MOP-MEEK-XNG-MDAILY-IQRMEAN-2026_S01
variant_id: MOP-MEEK-XNG-MDAILY-IQRMEAN-2026_S01
source_id: MOP-MEEK-XNG-MDAILY-IQRMEAN-2026
ea_id: QM5_41136
slug: xng-mdaily-iqrmean-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41136_xng-mdaily-iqrmean-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-24
created_by: Research+Development
last_updated: 2026-08-24
g0_status: APPROVED
g0_decision: decisions/2026-08-24_qm5_41136_xng_monthly_daily_iqr_mean_momentum_g0.md
source_approval: decisions/2026-08-24_xng_monthly_daily_iqr_mean_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Heather Meek; Susan A. Hoelscher"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Heather Meek; Susan A. Hoelscher"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Meek, H. and Hoelscher, S. A. (2023), Day-of-the-week effect: Petroleum and petroleum products, Cogent Economics & Finance 11(1), DOI 10.1080/23322039.2023.2213876."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded composite strategy-seeds/sources/MOP-MEEK-XNG-MDAILY-IQRMEAN-2026/source.md"
    quality_tier: A
    role: xng_own_price_monthly_continuation_and_monthly_clock
  - type: peer_reviewed_open_access_paper_bounded_packet
    citation: "Meek, Heather and Hoelscher, Susan A. (2023), Day-of-the-week effect: Petroleum and petroleum products, Cogent Economics & Finance 11(1)."
    location: "DOI 10.1080/23322039.2023.2213876; complete-read packet strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md; bounded composite strategy-seeds/sources/MOP-MEEK-XNG-MDAILY-IQRMEAN-2026/source.md"
    quality_tier: A
    role: xng_close_to_close_daily_log_return_lineage
strategy_mechanic: normalized-month-boundary-xng-immediately-completed-seventeen-to-twenty-three-session-daily-log-returns-ascending-sort-floor-quarter-trim-each-tail-central-band-arithmetic-mean-sign-continuation-one-month-hold
sources:
  - "[[sources/MOP-MEEK-XNG-MDAILY-IQRMEAN-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/robust-within-month-return-location]]"
  - "[[concepts/natural-gas-structural-trend]]"
indicators:
  - "[[indicators/completed-month-daily-interquartile-mean]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, structural-trend, completed-month-daily-return-interquartile-mean, robust-location-direction, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 411360000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed XNG positions per full post-warm-up year after exact month, interquartile-mean arithmetic, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 40.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WITHIN_MONTH_IQR_MEAN_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_STARTED
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct-XNG completed-month interquartile-mean continuation sleeve whose logic differs from certified QM5_12567. Verify uniform energy labels, exact month boundary, 17-23 returns ending in the month, older boundary inclusion, endpoint identity, full ascending sort, floor(n/4) removal from each tail, exact retained membership, central arithmetic mean direction independent of the raw endpoint, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, immediately_completed_calendar_month, bounded_month_session_count, older_boundary_close, every_return_ending_in_month_once, chronological_log_return_orientation, endpoint_identity, full_sample_ascending_sort, integer_quartile_tail_count, exact_retained_indexes, central_band_arithmetic_mean, raw_endpoint_not_a_gate, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "Current explicit OWNER mission 2026-08-24; R1 peer-reviewed XNG own-return and complete-read daily-return sources with the within-month interquartile-mean translation disclosed; R2 exact month/return/endpoint/sort/integer-trim/retained-mean/direction/attempt/risk/lifecycle; R3 native XNG D1 with label and CFD-basis risk; R4 deterministic arithmetic without a trained or banned signal; canonical pre-allocation dedup found no exact collision and one expected WTI carrier sibling, with manual family review separating the raw XNG endpoint, other XNG flow/calendar/weekly families, the WTI carrier, and certified XNG RSI logic."
---

# QM5_41136 XNG Completed-Month Daily-Return Interquartile-Mean Momentum

## Hypothesis

Natural gas adjusts to production, storage, pipeline, liquefaction, weather,
hedging, and power-demand shocks through persistent physical-energy regimes.
A completed-month endpoint can be dominated by a small number of extreme
sessions. Following the mean of the central daily-return band after removing
the integer outer quartiles tests whether the ordinary completed-month path
carries a direction that persists into the next month.

This is direct natural-gas exposure with logic materially different from the
certified book's short-horizon XNG oscillator pullback. Different logic does
not prove profitability or decorrelation. Q02 owns density and baseline
economics; unchanged Q09 alone owns realized portfolio overlap.

## Source traceability and claim boundary

The source of record is
`strategy-seeds/sources/MOP-MEEK-XNG-MDAILY-IQRMEAN-2026/source.md`, SHA-256
`AB0F8B5C47748783169EAB542C56FFC5ABC20D3D5F5D8F3D14832F50939A1C3A`,
authorized before extraction by
`decisions/2026-08-24_xng_monthly_daily_iqr_mean_momentum_source_approval.md`
at commit `c24a87615` and committed as a bounded packet at `c3ad3a01b`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, a monthly formation/renewal family, a pooled commodity `k=1,h=1`
implementation, and natural-gas membership. Meek and Hoelscher document
close-to-close natural-gas daily log returns and heterogeneous daily energy
behavior. Neither source tests an XNG-only within-month interquartile mean, a
continuous CFD, fixed-dollar ATR risk, or the QM book. The exact
integer-quartile trim, execution, and risk rules below are declared QM
interpretations.

No source alpha, return, probability, density, profit factor, drawdown, trade
count, cost, XNG-only efficacy, CFD equivalence, or portfolio-correlation
statistic is imported.

## Non-duplicate decision

Before allocation, the fail-closed canonical checker scanned 4,635 registry
identities, 1,303 cards, and 45 Strategy Wiki nodes using the current Company
Reference root. It found no exact collision and raised one expected fuzzy
carrier sibling. Evidence is
`artifacts/qm5_xng_mdaily_iqrmean_mom_preallocation_dedup_20260824.json`.

Manual family review fixes the mechanic boundaries:

- `QM5_41134_wti-mdaily-iqrmean-mom` uses the analogous statistic on WTI.
  This card is locked to XNG and cannot execute on WTI. Separate WTI/XNG
  source-pure single-symbol cards have repository precedent in `QM5_20187`
  and `QM5_20204`.
- `QM5_20204_xng-tsmom1m` follows the unpartitioned completed-month endpoint.
  This card follows only the 9-13-return central order-statistic band and
  keeps the endpoint diagnostic.
- existing XNG weekly range, close-location, flow, calendar, reversal, and
  multi-month trend cards do not sort every daily return in exactly one
  completed month and remove the dynamic outer quartiles.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative
  RSI(2) pullback above SMA(200), with a five-bar maximum hold. This card has
  no oscillator or moving-average gate, is symmetric, and holds one month.

The exact XNG carrier, immediately completed month, older boundary, every
daily return ending in the month, full ascending sort, integer outer-quartile
deletion, central-band arithmetic mean, symmetric direction, consumed
attempt, fixed risk, and next-month lifecycle are jointly load bearing.
Verdict:
`CLEAN_XNG_COMPLETED_MONTH_DAILY_INTERQUARTILE_MEAN_MOMENTUM_AFTER_CARRIER_FAMILY_REVIEW`.

## Market, clock, and state

- Host and traded symbol: exact `XNGUSD.DWX`, D1, slot 0, magic `411360000`.
- Decision: first executable tick of a new normalized broker-calendar month,
  within 180 elapsed minutes of the raw current host D1 bar open.
- Signal data: one older boundary close plus every D1 close in the immediately
  completed normalized calendar month; current-month prices are excluded.
- Position count: zero or one owned XNG position and at most one consumed
  attempt per normalized broker `yyyymm`.
- Expected frequency: approximately 10-12 positions/year; Q02 retires below
  five in any full post-warm-up scored year.

## Energy-label normalization

Choose one label offset for the entire decision and history package. Use zero
when the raw current D1 label equals broker date. Permit `+1` calendar day only
when the raw D1 label is exactly one calendar day behind broker date. Apply
the selected offset to current and historical bars uniformly. Reject every
other offset, mixed convention, normalized collision, weekend ending label,
or non-increasing timestamp state. Raw bar-open time, not normalized label
time, owns the 180-minute entry grace.

## Completed-month interquartile-mean contract

Within a fixed 45-bar buffer, the newest completed normalized D1 bar must
belong to the immediately preceding calendar month. Collect every unique bar
in that month and require 17 through 23 sessions plus one adjacent older bar
from the preceding month proving the left boundary. Reverse selected closes
into chronological order beginning with the older boundary.

For chronological closes `C[-1], C[0]..C[n-1]`, define:

```text
r[j] = ln(C[j] / C[j-1]), j=0..n-1
sorted = ascending(r[0], ..., r[n-1])
trim_each_tail = floor(n / 4)
retained_count = n - 2 * trim_each_tail
central_mean = sum(sorted[trim_each_tail .. n-trim_each_tail-1])
               / retained_count

central_mean > 0 => BUY XNGUSD.DWX
central_mean < 0 => SELL XNGUSD.DWX
otherwise        => FLAT
```

Require positive finite closes, finite returns, valid indexes, exactly four
or five observations removed per tail, exactly 9-13 retained observations,
and a finite sum and mean. Verify that `sum(r)` equals
`ln(C[n-1]/C[-1])` within `1e-10`. Sort without rounding and use every return
exactly once before trimming. A zero central mean, endpoint mismatch, invalid
count, malformed history, or invalid arithmetic stays flat. The raw endpoint
may agree or disagree and is diagnostic only. Neither signal magnitude nor
endpoint magnitude changes risk.

## Rules

The entry, exit, filter, management, and risk rules below are the complete
authorized baseline. There is no optimization surface, alternate trim
formula, endpoint confirmation, or fallback signal.

### Entry rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require exact `XNGUSD.DWX`, D1, EA `41136`, slot zero, registered magic,
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
8. Sort all returns ascending; remove exactly `floor(n/4)` from each tail;
   average every retained observation exactly once.
9. Buy for a strict positive central mean and sell for a strict negative
   central mean. Equality or invalid state consumes the month flat.
10. Require a valid executable quote and no genuinely positive spread wider
    than 3,000 points. Modeled zero `.DWX` spread is valid.
11. Require completed-bar `ATR(20,D1)`, valid point/digit/volume metadata, and
    valid `RISK_FIXED` sizing.
12. Open at most one market position with a frozen `3.5*ATR(20,D1)` broker
    hard stop and no take-profit.

### Attempt and restart contract

The attempt key is terminal-global and scoped by EA and symbol. It stores the
normalized decision `yyyymm` before every fallible gate. Initialization clears
only a future-dated tester residue. Late attachment consumes the missed month
without a trade. Owned deal history and open-position checks are additional
fail-closed guards. A flat signal, invalid history, news/spread/quote/ATR
block, order rejection, stop-out, or restart cannot create a same-month retry.

### Exit rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, wrong-type,
   invalid-volume, invalid-open-time, or stopless owned exposure.
3. Close on the first tick whose normalized broker `yyyymm` is later than the
   month containing the position's normalized entry time.
4. Forty elapsed calendar days is a stale repair only.

There is no target, opposite-signal exit, trail, break-even move, partial
close, Friday flatten, scale-in, pyramid, grid, martingale, hedge, or
discretionary close.

### Filters and trade management

- Exact symbol, period, EA ID, slot, magic, risk, news, Friday, and frozen
  strategy inputs.
- Framework kill switch and ownership controls remain authoritative.
- Apply label normalization, entry grace, durable attempt, exact month
  membership, session bounds, boundary proof, chronology, return validity,
  endpoint identity, ascending sort, integer trim, retained mean, spread,
  quote, ATR, sizing, and stop checks fail closed.
- Manage malformed, later-month, and stale exits every tick before entry.
- Freeze the original hard stop; never widen, trail, remove, or replace it.
- Never retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the month.
- Runtime cannot read current-month signal prices, futures curves, storage,
  weather, production, volume, open interest, fitted output, external
  files/APIs, trained output, prior pipeline results, or manual signals.

## Parameters to test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_bars_d1` | 45 | bounded month plus boundary buffer |
| `strategy_min_month_sessions` | 17 | completed-month lower bound |
| `strategy_max_month_sessions` | 23 | completed-month upper bound |
| `strategy_trim_divisor` | 4 | integer tail count denominator |
| `strategy_min_retained_returns` | 9 | fail-closed retained-band floor |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_numerical_tolerance` | 1e-10 | endpoint-identity tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 3000 | XNG entry-cost guard |

## Risk

- Backtest mode only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- One exact `XNGUSD.DWX` D1 position at a time under slot zero and registered
  magic `411360000`.
- Position size comes only from the V5 fixed-risk helper and a frozen
  completed-bar `3.5*ATR(20,D1)` stop.
- Both news axes and Friday close are OFF for the full-month native-price
  hypothesis.
- No live/demo/shadow/stress/optimization setfile is authorized.

Expected PF and drawdown fields are low-confidence planning priors, not source
claims or pass criteria. Q02 must retire at zero trades, below five completed
positions in a full scored post-warm-up year, with nonpositive governed
economics, or on any fidelity, determinism, risk, or lifecycle defect.

## Framework alignment

- no_trade: exact host/period/ID/slot, registered magic, locked risk/news/
  Friday/strategy inputs, and fail-closed ownership state.
- trade_entry: normalized month clock, consumed attempt, exact calendar
  package, chronological returns, endpoint identity, full sort, integer tail
  deletion, retained arithmetic mean, spread/quote/ATR/stop checks, and one
  fixed-risk request.
- trade_management: malformed-position repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety and claim boundary

This card authorizes only one branch-local source build, strict compile/Q01,
and one paced target-only Q02 handoff when the CPU ceiling permits. It does not
authorize a manual backtest, live artifact, `T_Live`, AutoTrading, terminal
control, deploy manifest, portfolio-gate change, portfolio admission,
correlation waiver, or decorrelation claim. Q09 alone owns portfolio overlap.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-24 | approved source extraction | G0-approved card; numeric identity fixed pending governed registry allocation |

## Phase log

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| Source Approval | 2026-08-24 | APPROVED_SOURCE | decisions/2026-08-24_xng_monthly_daily_iqr_mean_momentum_source_approval.md |
| G0 Research Intake | 2026-08-24 | APPROVED | decisions/2026-08-24_qm5_41136_xng_monthly_daily_iqr_mean_momentum_g0.md |
| Q01 Build | 2026-08-24 | NOT_STARTED | governed identity/magic allocation and implementation pending |
| Q02 Baseline | 2026-08-24 | NOT_ENQUEUED | requires strict Q01 PASS and CPU-ceiling check |
