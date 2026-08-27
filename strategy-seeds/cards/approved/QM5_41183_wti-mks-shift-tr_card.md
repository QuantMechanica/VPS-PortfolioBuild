---
card_schema_version: 2
type: strategy
strategy_id: MOP-NIST-KS2-WTI-MDIST-SHIFT-2026_S01
variant_id: MOP-NIST-KS2-WTI-MDIST-SHIFT-2026_S01
source_id: MOP-NIST-KS2-WTI-MDIST-SHIFT-2026
ea_id: QM5_41183
slug: wti-mks-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41183_wti-mks-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41183_wti_monthly_ks_distribution_shift_trend_g0.md
source_approval: decisions/2026-08-27_wti_monthly_ks_distribution_shift_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; NIST/SEMATECH"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; NIST/SEMATECH"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; NIST Dataplot Reference Manual, Kolmogorov-Smirnov Two-Sample Goodness of Fit Test."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence under strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: official_statistical_method
    citation: "NIST Dataplot Reference Manual, Kolmogorov-Smirnov Two-Sample Goodness of Fit Test."
    location: "https://www.itl.nist.gov/div898/software/dataplot/refman1/auxillar/ks2samp.htm; complete-page receipt under the governed source packet"
    quality_tier: A_official_method
    role: two_sample_ecdf_and_maximum_gap_definition
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI fixed-block signed-ECDF distribution-shift packet."
    location: "strategy-seeds/sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026/source.md"
    quality_tier: internal_governed
    role: exact_split_signed_boundary_calendar_risk_and_lifecycle
strategy_mechanic: monthly-wti-fixed-six-old-six-new-completed-month-end-two-sample-kolmogorov-smirnov-signed-ecdf-gap-at-least-three-directional-distribution-shift
sources:
  - "[[sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-distribution-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
  - "[[concepts/energy-sleeve]]"
indicators:
  - "[[indicators/completed-month-price]]"
  - "[[indicators/two-sample-signed-ecdf-gap]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, nonparametric, distribution-shift, signed-ecdf-gap, fixed-block, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 411830000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-8 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact random-rank directional qualification is 109/231, about 5.662 decisions/year, before market data."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK
r1_reasoning: "Complete-read peer-reviewed monthly WTI trading evidence plus a complete official NIST two-sample method page; the exact signed-ECDF trading conjunction remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoint reconstruction, fixed six/six blocks, strict ties, combined scan, both signed count maxima, boundary, direction, consumed attempt, fixed risk, stop, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, and gap risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, comparisons, integer counts, ATR risk controls, and execution state; no trained signal or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 12 completed month ends; fixed old/new block size 6; inclusive dominant signed ECDF count gap 3; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a direct-WTI monthly fixed-block distribution-shift stream outside the directional XAU/SP500/NDX/XNG book. Verify twelve consecutive completed endpoints, exact fixed six/six membership, strict ties, combined-order scan, both signed ECDF count maxima, inclusive gap-three boundary, dominant-side direction, tied-max flat state, consumed attempt, fixed-risk stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, twelve_consecutive_completed_months, latest_close_per_month, fixed_six_by_six_membership, strict_no_tie_combined_order, signed_ecdf_count_maxima, inclusive_gap_three_boundary, dominant_side_only, tied_max_flat, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41183_wti_monthly_ks_distribution_shift_trend_g0.md: R1 PASS with complete-read peer-reviewed WTI evidence and the complete official NIST two-sample method page; R2 PASS locks endpoints, fixed blocks, strict ties, signed ECDF counts, threshold, direction, attempt, risk, stop, and lifecycle; R3 PASS registered WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. The canonical checker returned CLEAN, and fixed rank fixtures separate the maximum-gap functional from Mann-Whitney while split/statistic definitions separate Pettitt, Mann-Kendall, Spearman, median-runs, and certified XNG pullback neighbors."
---

# QM5_41183 WTI Fixed-Block Signed-ECDF Distribution-Shift Trend

## Hypothesis

WTI has physical supply, production, investment, inventory, transport,
refining, geopolitical, hedging, and demand drivers absent from the stated
directional XAU, SP500, NDX, and XNG book. Those slow adjustments can displace
the distribution of completed monthly price levels rather than merely move
one endpoint.

This card compares the oldest and newest six of twelve completed WTI
month-end closes. It continues only a dominant maximum signed empirical-CDF
gap of at least one half. The construction is a falsifiable direct-crude
structural-trend hypothesis. It is not evidence of profitability,
independence, or decorrelation. Q02 owns density and economics; unchanged Q09
owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026/source.md`, SHA-256
`CDCEC4537A50040C1074C94FA5B29EF1038B9E72EB0798FF24D940021C2054BA`,
authorized by
`decisions/2026-08-27_wti_monthly_ks_distribution_shift_trend_source_approval.md`
at commit `7d4d275f4` before card extraction.

Moskowitz, Ooi, and Pedersen supply complete-read peer-reviewed WTI
membership, monthly own-price continuation lineage, and monthly renewal.
NIST supplies the complete operative two-sample ECDF maximum-gap method.
Neither tests this twelve-endpoint fixed-block count boundary, signed
direction, continuous-CFD mapping, fixed-dollar risk, or lifecycle.

No source alpha, return, probability, significance, density, profit factor,
drawdown, transaction cost, WTI-only result, CFD equivalence, decorrelation,
or portfolio statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,682 registry
identities, 1,333 card files, and 45 Strategy Wiki nodes and returned `CLEAN`.
Receipt:
`artifacts/qm5_wti_mks_shift_tr_preallocation_dedup_20260827.json`, SHA-256
`D8EF38827C409D0015C6BF87C64C7FE5083495EB6ECF044A304CE0E14EF96ABD`.

Manual review fixes a distinct state function:

- `QM5_41176` sums all 36 old/new Mann-Whitney wins; this card retains only
  the maximum signed vertical ECDF gap.
- `QM5_41172` searches all possible change points; this card fixes exactly one
  split after month six.
- `QM5_20264` counts every chronological pair over thirteen endpoints; this
  card is invariant to within-block order.
- `QM5_41173` weights calendar-rank displacement; this card retains only the
  maximum cumulative group-membership imbalance.
- `QM5_41182` counts above/below-median chronological runs; this card has no
  median or run count.
- certified `QM5_12567` is a long-only two-day XNG oscillator pullback, not a
  symmetric monthly WTI distribution-shift rule.

Path `[1,2,3,5,11,12,4,6,7,8,9,10]` buys here at signed maxima `(3,2)` while
Mann-Whitney stays flat at `U_new=23`. Path
`[1,2,4,6,8,10,3,5,7,9,11,12]` stays flat here at `(2,0)` while Mann-Whitney
buys at `U_new=26`. Side-reflected fixtures prove SELL symmetry.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_SIGNED_KS_ECDF_GAP3_DISTRIBUTION_SHIFT_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Intended magic: `411830000`.
- Decision: first executable D1 tick after a genuine broker-month transition,
  within 180 elapsed minutes of raw current-bar open.
- Formation: twelve immediately prior consecutive completed broker-month
  endpoints, fixed oldest/newest blocks of six.
- Hold: first later broker month; forty calendar days is stale repair.
- Expected pre-result cadence: five to eight positions/year; Q02 retires below
  five in any full post-warm-up year.

## Exact Formula

For chronological completed-month prices `C[0..11]`:

```text
O = C[0..5]
N = C[6..11]
require C is positive, finite, and pairwise distinct

old_seen = 0
new_seen = 0
Dplus = 0
Dminus = 0

for each combined value in strict ascending order:
    increment the count for its fixed block
    delta = old_seen - new_seen
    Dplus  = max(Dplus, delta)
    Dminus = max(Dminus, -delta)

BUY  iff Dplus  >= 3 and Dplus  > Dminus
SELL iff Dminus >= 3 and Dminus > Dplus
FLAT otherwise
```

The count divided by six is the one-sided ECDF gap. Count arithmetic is
authoritative. Equal signed maxima, central gaps, malformed values, or any tie
consume the month flat. No p-value, critical table, rank sum, variable split,
endpoint return, fitted location, fallback, or signal-strength sizing exists.

Exact enumeration of 924 strict six/six assignments gives 218 BUY, 218 SELL,
and 488 flat states, or directional qualification `109/231`. This is a
pre-market density design fact only.

## Rules

- `ea_id=41183`, exact `XTIUSD.DWX`, D1, slot 0, magic `411830000`.
- Consume the normalized broker month before every fallible entry gate.
- Use exactly twelve immediately prior consecutive completed month keys and
  the latest close in each; newest endpoint no more than ten days stale.
- Preserve the fixed old/new membership while sorting the combined values.
- Require strict uniqueness, exact six/six counts, and gap counts in `0..6`.
- Trade only the dominant signed count at the inclusive boundary three.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require `qm_ea_id=41183`, exact `XTIUSD.DWX`, D1, slot offset zero,
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, OFF/NONE news,
   Friday close OFF, and every singleton strategy input.
2. Process lifecycle repair and prior-month/stale exits before entry-only
   gates.
3. On a genuine new broker month within the 180-minute grace window, persist
   `QM5_41183_MONTH_ATTEMPT_<magic>=yyyymm` before history or execution gates.
4. If already consumed, late, or carrying owned exposure, do not enter.
5. Reconstruct exactly twelve completed month-end closes with strict
   chronology and maximum ten-day newest-endpoint staleness.
6. Reject any nonpositive, nonfinite, or equal close. Scan the combined strict
   order, prove exactly six observations per block, and calculate both count
   maxima in `0..6`.
7. Consume flat unless exactly one maximum is dominant at three or more. Buy
   for dominant `Dplus`; sell for dominant `Dminus`.
8. Reject spread above 1,500 points, invalid quotes, invalid completed-bar
   ATR, nonpositive stop distance, invalid volume, or insufficient margin.
9. Submit one market request sized by the V5 risk helper against a frozen
   `3.5*ATR(20,D1)` hard stop. Attach no target and never retry the month.

## 5. Exit Rules

- Close on the first processed tick whose normalized broker month differs
  from the persisted entry month.
- Close after forty elapsed calendar days as stale repair.
- The broker hard stop and framework kill switch remain active.
- No target, signal flip, gap recount, trail, break-even, partial exit, Friday
  close, news exit, or same-month re-entry is authorized.

## 6. Filters (No-Trade Module)

- Exact symbol/period/EA/slot and locked-input checks fail `OnInit` closed.
- Standard framework kill-switch, weekend/holiday, connection, margin, and
  session protections remain active.
- News temporal mode is OFF, compliance profile is NONE, and legacy news mode
  is OFF because the signal uses no event data.
- Friday close is OFF to preserve the approved month-long lifecycle.
- Entry-only gates never suppress lifecycle repair or mandatory exits.

## 7. Trade Management Rules

- Own at most one slot-zero WTI position with exact symbol and magic.
- Before considering entry, close duplicate, wrong-symbol, wrong-magic,
  wrong-side, invalid-volume, stopless, later-month, or stale owned exposure.
- Recover entry month and expected direction from terminal-global attempt
  state and deal history after restart; ambiguous state closes fail-safe.
- Stop distance and size are frozen at entry. No scale-in, averaging,
  pyramiding, grid, discretionary override, or signal-strength sizing exists.

## 8. Parameters To Test

The Q02 baseline is locked; these inputs exist for auditability, not an
optimization grant.

| Input | Value | Contract |
|---|---:|---|
| `strategy_endpoint_count` | 12 | locked |
| `strategy_block_size` | 6 | locked |
| `strategy_min_gap_count` | 3 | locked |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_max_endpoint_gap_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |
| `strategy_deviation_points` | 20 | locked |

No alternate split, tie ranking, critical-value or probability gate,
endpoint fallback, volatility filter, seasonal filter, or ensemble is
authorized after results.

## Risk

All backtest presets use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. One position is sized through the V5 fixed-risk helper
against a frozen `3.5*ATR(20,D1)` hard stop. Signal strength never changes
risk. No live, demo, shadow, stress, or optimization preset is authorized.

Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
monthly formation staleness, small-sample rank instability, weak selectivity
at the density boundary, abrupt reversal after a distribution shift,
hard-stop slippage, and realized correlation with XNG or risk assets.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete-read peer-reviewed WTI evidence and complete official NIST two-sample method documentation; exact trading conjunction untested. |
| R2 | PASS | Clock, endpoints, fixed blocks, strict ties, signed count maxima, boundary, side, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native WTI D1 supplies every runtime input; Q02 owns density, costs, and CFD sufficiency. |
| R4 | PASS | Native deterministic comparison and integer arithmetic only; no trained signal, prohibited input, external feed, grid, or martingale. |

## Failure Modes And Kill Criteria

Retire or fail on any of the following:

- fewer than five completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or any downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest endpoint,
  stale newest endpoint, nonchronological timestamps, or mixed label offsets;
- endpoint count other than 12, block size other than 6, accepted tie, lost
  fixed membership, combined-scan count other than 12, block count other than
  six/six, count maximum outside 0..6, entry below boundary three, tied-max
  entry, or wrong side;
- same-month retry, missing hard stop, wrong risk mode, excessive spread, late
  entry, missed month exit, or nondeterministic output; or
- any post-result rescue change to formation, split, tie rule, threshold,
  side, risk, stop, hold, symbol, carrier, or added filter.

## Falsification And Requalification

Any change to the twelve-month formation, fixed block membership, strict tie
rule, combined-order scan, signed count definitions, inclusive boundary,
dominant-side mapping, broker-month normalization, consumed attempt, spread
ceiling, risk, stop, or exit clock creates a new execution contract and
requires a new binary, Q02 restart, and full portfolio requalification.
Ambiguity is `BLOCKED`, never filled in by Development.

## Execution And State Contract

- `ea_id=41183`, exact `XTIUSD.DWX`, D1, slot 0, intended magic `411830000`.
- Persist `QM5_41183_MONTH_ATTEMPT_<magic>` before all fallible gates.
- Recover persisted attempt across restarts and reconcile it with entry deals.
- A late restart consumes the new month flat; no catch-up entry.
- Exactly one active magic-registry row and resolver mapping are mandatory
  before compile.
- Logs expose month key, endpoint times/values, fixed membership, sorted
  membership path, every cumulative delta, both maxima, direction, and state.

## Portfolio Interaction

This candidate adds direct WTI exposure rather than another index, gold, or
natural-gas rule. That is an exposure hypothesis, not a measured correlation
result. Q09 alone may establish overlap with the stated book. No portfolio
gate, manifest, allocation, incumbent, threshold, or waiver changes here.

## Validation Plan

1. Card schema lint and prohibited-token scan.
2. Canonical dedup receipt and signed-ECDF/Mann-Whitney separating fixtures.
3. Pure reference checks for strict sorting, fixed membership, cumulative
   deltas, both maxima, inclusive boundary, tied maxima, symmetry, ties,
   invalid states, exact density counts, and neighbor separation.
4. Strict MQL5 compile and framework build check.
5. Canonical `RISK_FIXED` XTIUSD.DWX D1 backtest set only.
6. Independent source/card/build alignment review.
7. At most one paced Q02 enqueue below both tester and host-CPU ceilings.
8. Q02 owns activity/economics; later gates own robustness and Q09 overlap.

## Framework Alignment

| Card rule | V5 location |
|---|---|
| Exact host, risk/news/Friday/input locks | no-trade filter and `OnInit` |
| Month transition and durable consumed attempt | decision-clock and terminal-global state helpers |
| Twelve completed month endpoints | bounded D1 reconstruction helper |
| Fixed blocks, strict sorting, cumulative deltas, maxima, side | entry signal helper |
| Frozen ATR stop and fixed-risk market request | `Strategy_EntrySignal` plus framework transaction manager |
| Integrity repair, month close, forty-day stop | `Strategy_ManageOpenPosition` |
| No discretionary close signal | `Strategy_ExitSignal` returns false |
| Logging and equity stream | framework hooks on new bar/tick/transaction |

## Safety Boundary

Authorized: one approved card, one registered V5 identity, one non-live source
build, strict Q01 validation, independent review, and at most one paced Q02
enqueue.

Forbidden: manual backtests outside the farm; live/demo/shadow/stress or
optimization setfiles; `T_Live`; AutoTrading; deploy or live manifests;
portfolio-gate edits; portfolio admission; correlation waivers; external
runtime data; terminal control; and claims of profitability, certification,
or decorrelation before governed evidence exists.

## Revision History

| Date | Change |
|---|---|
| 2026-08-27 | Initial source-complete card approved under the OWNER commodity/energy portfolio mission; canonical dedup CLEAN; R1-R4 PASS. |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-08-27 | APPROVED_SOURCE | `decisions/2026-08-27_wti_monthly_ks_distribution_shift_trend_source_approval.md` |
| G0 Research Intake | 2026-08-27 | APPROVED | `decisions/2026-08-27_qm5_41183_wti_monthly_ks_distribution_shift_trend_g0.md` |
| Q01 Build Validation | 2026-08-27 | NOT_BUILT | build pending |
| Q02 Baseline Screening | 2026-08-27 | NOT_ENQUEUED_Q01_PENDING | compile and Q01 pending |
