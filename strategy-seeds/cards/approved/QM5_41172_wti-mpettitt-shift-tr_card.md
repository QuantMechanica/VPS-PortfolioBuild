---
card_schema_version: 2
type: strategy
strategy_id: MOP-PETTITT-WTI-MSHIFT-TREND-2026_S01
variant_id: MOP-PETTITT-WTI-MSHIFT-TREND-2026_S01
source_id: MOP-PETTITT-WTI-MSHIFT-TREND-2026
ea_id: QM5_41172
slug: wti-mpettitt-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41172_wti-mpettitt-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-26
created_by: Research+Development
last_updated: 2026-08-26
g0_status: APPROVED
g0_decision: decisions/2026-08-26_qm5_41172_wti_monthly_pettitt_change_point_trend_g0.md
source_approval: decisions/2026-08-26_wti_monthly_pettitt_change_point_trend_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; A. N. Pettitt; Thorsten Pohlert"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; A. N. Pettitt; Thorsten Pohlert"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Pettitt (1979), A Non-Parametric Approach to the Change-Point Problem, Applied Statistics 28(2), 126-135, DOI 10.2307/2346729; Pohlert, trend 1.1.7, CRAN."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence under strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: own_price_direction_monthly_cadence_and_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Pettitt, A. N. (1979). A Non-Parametric Approach to the Change-Point Problem. Applied Statistics 28(2), 126-135."
    location: "DOI 10.2307/2346729; Crossref and publisher metadata; body not claimed completely read"
    quality_tier: A_record_only
    role: nonparametric_single_change_point_lineage
  - type: public_method_implementation
    citation: "Pohlert, T. trend 1.1.7. CRAN."
    location: "public mirror commit d0ec3cf8b99b4f3226f5211f592955b85565721d; complete relevant files in retrieval receipt"
    quality_tier: A_method_implementation
    role: exact_rank_sum_path_absolute_maximum_and_change_point_location
  - type: governed_composite_source
    citation: "QuantMechanica bounded WTI thirteen-month Pettitt central-shift continuation source packet."
    location: "strategy-seeds/sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_central_band_direction_calendar_risk_and_lifecycle
strategy_mechanic: monthly-wti-thirteen-completed-month-end-pettitt-maximum-rank-sum-unique-central-change-point-post-shift-direction-continuation
sources:
  - "[[sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-change-point]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-price]]"
  - "[[indicators/pettitt-rank-sum-path]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, pettitt-change-point, rank-sum, central-tendency-shift, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
host_symbol: XTIUSD.DWX
execution_timeframe: D1
signal_timeframe: D1
direction: long_short
expected_trade_frequency: "About 4-8 completed XTIUSD positions/year after warm-up; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 6
r1_track_record: PASS
r1_reasoning: "Peer-reviewed complete-read WTI continuation source, peer-reviewed Pettitt method record, and complete pinned CRAN method files; the exact conjunction remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoint reconstruction, strict rank permutation, all cumulative sums, unique central maximum, side, attempt state, risk, stop, and exit are deterministic."
r3_data_available: PASS
r3_reasoning: "Registered XTIUSD.DWX D1 history and native MT5 state supply all runtime inputs; continuous-CFD basis risk remains explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, ranks, integer arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 endpoints; unique K in 4..9; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
force_build: true
g0_approval_reasoning: "OWNER mission 2026-08-26 and decisions/2026-08-26_qm5_41172_wti_monthly_pettitt_change_point_trend_g0.md: R1 PASS with complete-read peer-reviewed WTI evidence, peer-reviewed Pettitt record, and complete pinned CRAN method files; R2 PASS locks thirteen endpoints, strict ranks, cumulative sums, unique central maximum, signed side, attempt, risk, stop, and lifecycle; R3 PASS registered native WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. Canonical dedup was CLEAN and two rank fixtures separate it from Bartels and turning-point neighbors."
expected_pf: 1.05
expected_dd_pct: 20.0
---

# WTI Monthly Pettitt Central Change-Point Trend

## Hypothesis

WTI has a physical-energy return driver absent from the stated
XAU/SP500/NDX/XNG book. At a monthly clock, a durable level shift within
thirteen completed month-end closes can represent a new crude-oil regime. The
EA uses the signed Pettitt rank-sum path to locate one dominant central split
and continues in the direction of the post-shift level.

This is a falsifiable direct-crude structural-trend hypothesis. It is not
evidence that the resulting stream is profitable or decorrelated. Q02 owns
activity and economics; downstream gates own robustness and portfolio overlap.

## Source Traceability And Claim Boundary

- Trading carrier and cadence: Moskowitz, Ooi, and Pedersen (2012), complete
  governed source packet `MOP-TSMOM-2012`, explicitly including NYMEX WTI and
  monthly own-price continuation.
- Statistical lineage: Pettitt (1979), DOI `10.2307/2346729`; bibliographic
  record only because the public article-body route was policy-deferred.
- Exact formula record: CRAN `trend` 1.1.7 public mirror commit
  `d0ec3cf8b99b4f3226f5211f592955b85565721d`, complete relevant files and
  hashes in the retrieval receipt.
- Governed extraction and OWNER source approval:
  `strategy-seeds/sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026/source.md` and
  `decisions/2026-08-26_wti_monthly_pettitt_change_point_trend_source_approval.md`.

The sources support testing, not expected profitability, WTI-only efficacy,
CFD equivalence, the central-band trading choice, or low realized correlation.
No source performance statistic transfers.

## Non-Duplicate Decision

The canonical preallocation checker returned `CLEAN` across 4,671 EA registry
rows, 1,322 card files, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_wti_mpettitt_shift_tr_preallocation_dedup_20260826.json`.

The signal is functionally separate from neighboring WTI builds:

- Bartels (`QM5_41170`) sums squared adjacent rank differences and never
  retains a split location. This card scans signed cumulative rank sums and
  requires one central maximizing split.
- Turning points (`QM5_41171`) count local extrema and take endpoint side.
  This card uses neither local extrema nor endpoint direction.
- Foster-Stuart (`QM5_41169`) counts running records. This card estimates one
  central two-sample level separation.
- Fixture `[0,7,4,6,1,9,10,5,11,2,8,3,12]` yields `U*=24`, unique `K=5`,
  signed `U=-24`, and a buy here while Bartels `NM=436` and turning points
  `TP=10` remain flat.
- Fixture `[0,1,12,5,4,6,7,11,9,2,3,10,8]` yields an edge maximum at `K=2`,
  so this card stays flat while Bartels `NM=300` and turning points `TP=5`
  qualify long.

Verdict: `CLEAN_WTI_MONTHLY_PETTITT_UNIQUE_CENTRAL_SHIFT_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Target and host: exact `XTIUSD.DWX` only; slot 0; intended magic
  `411720000`.
- Chart and signal timeframe: D1.
- Decision cadence: first executable D1 tick of each genuine broker month.
- Formation: thirteen immediately preceding consecutive completed broker
  months; latest D1 close per month; current month excluded.
- At most one consumed attempt and one owned position per broker month.
- Expected pre-result activity: four to eight completed positions/year after
  warm-up. Q02 owns the measured result.

## Formula

Let `C[0]..C[12]` be thirteen positive finite pairwise-distinct completed WTI
month-end closes in chronological order. Rank them from 1 (smallest) to 13
(largest) as `R[0]..R[12]`.

```text
require sorted(R) = [1,2,...,13]

for k = 1..12:
    U[k] = 2 * sum(R[0..k-1]) - 14*k

Ustar = max(abs(U[k]))
Kset  = { k : abs(U[k]) == Ustar }

qualify iff size(Kset) == 1 and 4 <= K <= 9

BUY  iff qualify and U[K] < 0
SELL iff qualify and U[K] > 0
FLAT otherwise
```

Every `U[k]` must be even and lie in `[-42,42]`; `Ustar` must lie in
`[1,42]`. Equal closes, average ranks, tied maxima, edge splits, p-value
gates, endpoint fallbacks, fitted thresholds, and direction reversal are
forbidden. Statistic magnitude never changes risk.

## Rules

The EA implements one exact baseline. Invalid history or state consumes the
current broker month flat after persisting the attempt key. The current month
never contributes a signal close. Lifecycle repair precedes entry-only gates.

### Source-defined rules

- rank complete ordered observations;
- compute Pettitt's cumulative rank-sum path;
- locate the maximum absolute path value as the probable change point;
- interpret the signed separation as a central-tendency shift;
- test monthly WTI own-price continuation with monthly renewal.

### QM interpretations

- use thirteen completed month ends and strict no-tie ranks;
- require exactly one maximum and a split from 4 through 9 so both regimes
  contain at least four observations;
- follow the later regime: negative `U[K]` buys, positive `U[K]` sells;
- consume the month before every fallible gate;
- map to `XTIUSD.DWX`, fixed-dollar risk, ATR stop, spread cap, and
  deterministic lifecycle repair.

## 4. Entry Rules

On every new D1 bar, in this order:

1. Verify exact host, timeframe, EA ID, slot, fixed-risk mode, locked strategy
   inputs, news OFF/NONE, Friday close OFF, and zero stress rejection.
2. Normalize a uniform D1 label offset and derive broker month keys.
3. Require a genuine new month within 180 elapsed minutes of raw bar open.
4. Persist the current `yyyymm` before history, signal, news, spread, quote,
   ATR, sizing, margin, or order gates.
5. Reject an owned position or same-magic entry deal already recorded in the
   current broker month.
6. Reconstruct exactly thirteen consecutive completed month-end closes from a
   bounded D1 buffer. Validate positivity, finiteness, pairwise distinction,
   endpoint month, chronology, and staleness.
7. Assign strict ranks, prove the 1..13 permutation, compute all twelve
   `U[k]`, and prove parity and bounds.
8. Require one absolute maximum in `K=4..9`; buy for negative signed `U[K]`
   and sell for positive signed `U[K]`. Every other result consumes flat.
9. Require spread no greater than 1,500 points, valid quotes, finite
   completed-bar ATR, a valid frozen stop distance, and fixed-risk sizing.
10. Submit one slot-zero market order with a frozen hard stop and no target.
    An order reject never retries the month.

## 5. Exit Rules

Exit or repair at the first applicable condition:

1. immediately close malformed owned exposure: duplicates, wrong symbol,
   wrong magic, wrong direction for the recorded current-month signal,
   invalid volume, missing stop, or an invalid open timestamp;
2. close on the first tick whose normalized broker month differs from the
   entry month; or
3. close after forty elapsed calendar days as a stale-position backstop.

There is no profit target, trailing stop, break-even move, volatility exit,
opposite-signal exit, scale-in, or same-month re-entry.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41172, slot zero, active resolver identity, fixed-risk
  mode, news OFF/NONE, legacy news OFF, and Friday close OFF.
- Every strategy input is locked to the baseline; mismatch fails init.
- Uniform D1 label normalization, genuine month transition, 180-minute grace,
  thirteen consecutive endpoints, no ties, prior-month recency, rank
  permutation, cumulative-sum invariants, unique central split, durable
  attempt, spread, quote, ATR, stop, and sizing all fail closed.
- Lifecycle repair is never delayed by an entry-only gate.
- Runtime cannot read futures curves, inventory, volume, open interest,
  external files, APIs, forecasts, trained outputs, portfolio results, or
  prior pipeline verdicts.

## 7. Trade Management Rules

- Own at most one exact slot-zero WTI position.
- Keep the initial broker hard stop frozen; never widen, trail, or remove it.
- Reconstruct the current-month expected direction for lifecycle validation
  without creating another attempt.
- Retry a required close every tick until flat.
- Do not add, pyramid, hedge, reverse, or reopen during the consumed month.

## 8. Parameters To Test

The Q02 baseline is locked; this section names inputs for auditability, not an
optimization grant.

| Input | Value | Contract |
|---|---:|---|
| `strategy_endpoint_count` | 13 | locked |
| `strategy_min_change_index` | 4 | locked |
| `strategy_max_change_index` | 9 | locked |
| `strategy_history_bars_d1` | 900 | locked |
| `strategy_entry_grace_minutes` | 180 | locked |
| `strategy_endpoint_stale_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |

No parameter sweep, tie ranking, central-band change, alternate sample,
p-value gate, endpoint-direction fallback, volatility filter, seasonal filter,
or ensemble gate is authorized after results.

## Framework Execution Overrides

- Friday close: disabled to preserve the approved full-month hold.
- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode passed to framework init: OFF.
- Backtest risk: fixed 1,000 account-currency units; percentage risk zero.
- Stress rejection probability: zero in the canonical set.

## Exit Precedence

1. Framework kill switch and hard-stop enforcement.
2. Lifecycle integrity repair.
3. New-broker-month close.
4. Forty-day stale close.
5. Entry-only news, spread, quote, ATR, sizing, and margin gates.
6. New entry.

## Runtime Data Dependencies

- `XTIUSD.DWX` native/custom D1 bars and symbol metadata;
- broker time, current quotes, positions, deals, account state, and terminal
  global variables;
- framework ATR, risk sizing, stop rules, transaction manager, logging, and
  equity stream;
- no external runtime data or network access.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Stop: frozen `3.5*ATR(20,D1)` from the last completed bar at entry.
- Maximum entry spread: 1,500 points.
- One position and one attempt per broker month.
- `Ustar` magnitude never alters size.
- No live, demo, shadow, stress, or optimization preset is authorized.
- Principal risks are WTI gaps, continuous-CFD roll/basis and financing,
  sparse monthly density, abrupt reversal after a detected shift, hard-stop
  slippage, and realized overlap with energy or risk assets.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS | Complete-read peer-reviewed WTI evidence, peer-reviewed Pettitt method record, and complete pinned CRAN method files; exact trading conjunction untested. |
| R2 | PASS | Clock, endpoint order, strict ranks, cumulative sums, maximum, central band, side, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS | Registered native WTI D1 supplies every runtime input; Q02 owns density, cost, and CFD sufficiency. |
| R4 | PASS | Native deterministic ranks and state only; no trained signal, banned indicator, external feed, grid, or martingale. |

## 9. Failure Modes And Kill Criteria

Retire or fail the candidate on any of the following:

- fewer than four completed positions in any full post-warm-up Q02 year;
- zero trades, nonpositive governed economics, or a downstream gate failure;
- current-month leakage, missing/duplicate month keys, nonlatest close, stale
  newest endpoint, nonchronological timestamps, or mixed label offsets;
- endpoint count other than 13, an accepted equal close, wrong rank
  permutation, odd or out-of-bounds `U[k]`, wrong `Ustar`, accepted tied or
  edge maximum, or wrong signed side;
- same-month retry, missing hard stop, wrong risk mode, wrong spread ceiling,
  late entry, or missed month-boundary exit;
- nondeterministic output for identical history and inputs;
- any post-result rescue change to formation, rank rule, central band, side,
  risk, stop, hold, symbol, or carrier; or
- downstream portfolio-correlation rejection. No waiver is implied.

## Falsification And Requalification

Any change to the thirteen-month formation, strict rank definition,
cumulative-sum formula, unique-maximum rule, `K=4..9` band, signed shift side,
broker-month normalization, consumed attempt, spread ceiling, risk mode, stop,
or exit clock creates a new execution contract and requires a new binary,
stream reconciliation, Q02 restart, and full portfolio requalification.
Unresolved history-label, rank, split, or lifecycle ambiguity is `BLOCKED`,
never filled in by Development.

## 10. Execution And State Contract

- `ea_id=41172`, exact `XTIUSD.DWX`, D1, slot 0, intended magic
  `411720000`.
- Persist `QM5_41172_MONTH_ATTEMPT_<magic>` before all fallible gates.
- Recover the persisted attempt across restarts and reconcile it with entry
  deals.
- A late restart consumes the new month flat; no catch-up entry.
- Exactly one active magic-registry row and resolver mapping are mandatory
  before compile.
- Logs expose month key, endpoint times, ranks, all `U[k]` invariants,
  `Ustar`, `K`, signed value, direction, and state.

## 11. Portfolio Interaction

This candidate adds direct WTI exposure rather than another index, gold, or
natural-gas rule. That is an exposure hypothesis, not a measured correlation
result. Q09 alone may establish overlap with the stated book. No portfolio
gate, manifest, allocation, or correlation waiver is changed by this card.

## 12. Validation Plan

1. Card schema lint and forbidden-token scan.
2. Canonical research dedup receipt plus the two discriminating rank fixtures.
3. Pure reference checks for rank permutation, all `U[k]`, parity/range,
   unique maximum, central band, side, ties, and invalid states.
4. Strict MQL5 compile and framework build check.
5. Canonical `RISK_FIXED` XTIUSD.DWX D1 backtest set only.
6. Independent source/card/build alignment review.
7. At most one paced Q02 enqueue; no manual tester dispatch under a binding
   CPU ceiling.
8. Q02 owns activity/economics; subsequent automated gates own robustness and
   Q09 overlap. Failure retires the locked candidate.

## 13. Framework Alignment

| Card rule | V5 location |
|---|---|
| Exact host, risk/news/Friday/input locks | no-trade filter and `OnInit` |
| Month transition and durable consumed attempt | decision-clock and terminal-global state helpers |
| Thirteen completed month endpoints | bounded D1 reconstruction helper |
| Ranks, cumulative sums, maximum, band, side | entry signal helper |
| Frozen ATR stop and one market order | `Strategy_EntrySignal` plus framework transaction manager |
| Integrity repair, month close, forty-day stop | `Strategy_ManageOpenPosition` |
| No discretionary close signal | `Strategy_ExitSignal` returns false |
| Logging and equity stream | framework hooks on new bar/tick/transaction |

## 14. Safety Boundary

Authorized: one approved card, one registered V5 identity, one non-live source
build, strict Q01 validation, independent review, and at most one paced Q02
enqueue.

Forbidden: manual backtests outside the farm, live/demo/shadow/stress or
optimization setfiles, `T_Live`, AutoTrading, deploy or live manifests,
portfolio-gate edits, portfolio admission, correlation waivers, external
runtime data, terminal control, and claims of profitability, certification,
or decorrelation before the governed evidence exists.

## Revision History

| Date | Change |
|---|---|
| 2026-08-26 | Initial source-complete card approved under the OWNER commodity/energy portfolio mission; canonical dedup CLEAN; R1-R4 PASS. |
