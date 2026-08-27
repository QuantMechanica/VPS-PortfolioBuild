---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-M2RUNS-20260827_S01
variant_id: AI-CODEX-WTI-M2RUNS-20260827_S01
source_id: AI-CODEX-WTI-M2RUNS-20260827
ea_id: QM5_41184
slug: wti-mww-runs-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41184_wti-mww-runs-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41184_wti_monthly_wald_wolfowitz_runs_shift_trend_g0.md
source_approval: decisions/2026-08-27_wti_monthly_wald_wolfowitz_runs_shift_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Abraham Wald; Jacob Wolfowitz; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "OpenAI Codex governed synthesis (2026-08-27), supported by Wald and Wolfowitz (1940), DOI 10.1214/aoms/1177731909, and Moskowitz, Ooi, and Pedersen (2012), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_ai_origin
    citation: "OpenAI Codex (2026). WTI Monthly Fixed-Block Two-Sample Label-Runs Distribution Shift."
    location: "strategy-seeds/sources/AI-CODEX-WTI-M2RUNS-20260827/source.md"
    quality_tier: internal_governed
    role: single_lineage_exact_trading_mechanization
  - type: peer_reviewed_method_bibliography
    citation: "Wald, A., and Wolfowitz, J. (1940). On a Test Whether Two Samples Are from the Same Population. The Annals of Mathematical Statistics 11(2), 147-162."
    location: "DOI 10.1214/aoms/1177731909; metadata only, runtime reader policy-deferred"
    quality_tier: A_metadata_only
    role: supporting_method_name_and_bibliography
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: supporting_monthly_own_price_continuation_and_wti_membership
strategy_mechanic: monthly-wti-fixed-five-old-five-new-completed-month-end-wald-wolfowitz-two-sample-pooled-label-runs-at-most-five-median-directed-distribution-shift-continuation
sources:
  - "[[sources/AI-CODEX-WTI-M2RUNS-20260827]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-distribution-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
  - "[[concepts/energy-sleeve]]"
indicators:
  - "[[indicators/completed-month-price]]"
  - "[[indicators/two-sample-pooled-label-runs]]"
  - "[[indicators/fixed-block-median-direction]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, nonparametric, distribution-shift, two-sample-runs, fixed-block, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 411840000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-6 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact random-rank qualification is 114/252, or about 5.429 decisions/year, before market data."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_PUBLIC_METHOD_ACCESS_LIMITATION
r1_reasoning: "One canonical AI-originated governed packet is permitted by R1; its supporting peer-reviewed method record is metadata-only after a policy defer, while the monthly WTI carrier has complete-read peer-reviewed support."
r2_mechanical: PASS
r2_reasoning: "Month clock, ten endpoints, fixed five/five blocks, pooled sort, label-run count, inclusive boundary five, exact block medians, direction, attempt, fixed risk, stop, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 execution state supply every runtime input; continuous-CFD roll, basis, financing, gap, and label risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, sorting, comparisons, integer counts, ATR risk controls, and execution state; no trained signal, prohibited runtime feed, grid, martingale, scale-in, or pyramid."
parameters_to_test: "Locked Q02 baseline only: 10 completed month ends; fixed old/new block size 5; inclusive maximum pooled-label runs 5; exact five-value block medians; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly pooled-label-runs distribution-shift stream outside the directional XAU/SP500/NDX/XNG book. Verify ten consecutive completed endpoints, exact fixed five/five membership, strict ties, stable pooled ordering, every label transition, inclusive runs-five boundary, exact block medians, symmetric side, consumed attempt, fixed risk, hard stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, first_tradable_month_bar, ten_consecutive_completed_months, latest_close_per_month, fixed_five_by_five_membership, strict_no_tie_pooled_order, exact_label_run_count, inclusive_runs_five_boundary, exact_block_medians, symmetric_direction, monthly_attempt_state, fixed_risk, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41184_wti_monthly_wald_wolfowitz_runs_shift_trend_g0.md: R1 PASS with one governed AI source, explicit public-method access limitation, peer-reviewed method bibliography, and complete-read peer-reviewed WTI support; R2 PASS locks endpoints, blocks, pooled order, runs, median direction, attempt, risk, stop, and lifecycle; R3 PASS registered WTI D1 with continuous-CFD basis risk; R4 PASS deterministic native arithmetic only. Canonical dedup returned CLEAN, and separating fixtures distinguish chronological median-runs, signed ECDF/KS, Mann-Whitney, Pettitt, and certified XNG pullback mechanics."
---

# QM5_41184 WTI Fixed-Block Two-Sample Label-Runs Shift Trend

## Hypothesis

WTI has physical supply, inventory, refining, transport, investment, hedging,
geopolitical, and demand drivers absent from the stated directional XAU,
SP500, NDX, and XNG book. Slow adjustment can separate the level
distributions of older and newer completed WTI months.

This card continues the newer block's median direction only when fixed
old/new membership clusters in pooled ascending price order. It is a
falsifiable direct-crude structural-trend hypothesis, not evidence of
profitability, statistical significance, independence, or decorrelation.
Q02 owns density/economics and unchanged Q09 owns realized overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-WTI-M2RUNS-20260827/source.md`, SHA-256
`90486EA94D449BB207D1625000A1200CDE3F1B0B7D4B05C712F4D1A1E03C9806`,
authorized in commit `fb7ef4580` before card extraction.

The public Wald-Wolfowitz DOI was classified
`DEFERRED:SOURCE_POLICY`; no complete read or inaccessible method detail is
claimed. The exact pooled-label rule is a disclosed Codex synthesis under the
OWNER mission. The preserved MOP packet supplies complete-read monthly WTI
continuation support only. No source alpha, critical value, p-value,
significance, frequency, profit factor, drawdown, cost, CFD equivalence,
decorrelation, or portfolio statistic transfers.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,683 registry
identities, 1,334 cards, and 45 current-vault Strategy Wiki nodes and returned
`CLEAN`. Receipt:
`artifacts/qm5_wti_mww_runs_shift_tr_preallocation_dedup_20260827.json`,
SHA-256
`88D3A10D84ECB5C876FA9916F24234DA802EDEB8AFA1A8D0805B2EC387EC27B1`.

The fixed state function is distinct:

- `QM5_41182` counts chronological transitions after a pooled-median
  dichotomy; this card sorts by price and counts fixed old/new membership
  runs, discarding within-block chronology.
- `QM5_41183` retains one maximum signed ECDF gap; this card counts the full
  membership-run path and takes side from separate exact block medians.
- `QM5_41176` sums all cross-block wins; adjacency clustering can differ at
  the same win sum.
- `QM5_41172` searches a variable chronological change point; this card fixes
  the split after observation five.
- certified `QM5_12567` is a long-only two-day XNG cumulative-RSI pullback.

Locked separating fixtures appear under Rules and in the pure reference
suite. Verdict:
`CLEAN_WTI_MONTHLY_FIXED_FIVE_BY_FIVE_POOLED_LABEL_RUNS_LE5_MEDIAN_DIRECTED_DISTRIBUTION_SHIFT_CONTINUATION`.

## Rules

### Decision clock and endpoint reconstruction

On the first executable tick of a genuine new normalized broker month:

1. Persist the current `yyyymm` attempt before every fallible entry gate.
2. Reconstruct exactly one latest D1 close from each of the immediately prior
   ten consecutive completed broker months.
3. Require the newest endpoint no older than ten calendar days and all ten
   values positive, finite, and pairwise distinct.
4. Fix older `O=C[0..4]` and newer `N=C[5..9]`; never move the split.

### Signal formula

```text
P = stable strict ascending sort of all values in O and N
L = fixed block label O or N carried by each value in P
R = 1 + count(L[i] != L[i-1], i=1..9)

old_median = middle value of sorted O
new_median = middle value of sorted N

BUY  iff R <= 5 and new_median > old_median
SELL iff R <= 5 and new_median < old_median
FLAT otherwise
```

Pairwise-distinct values make block-median equality impossible. Invalid
labels, sort order, run counts outside `2..10`, a late clock, or `R>5`
consume the month flat. No p-value, critical table, variable split, fallback,
or adaptive threshold exists.

### Exact density prior

All `choose(10,5)=252` fixed-label orders are exhaustively enumerable. Runs
`2,3,4,5` occur in `2,8,32,72` orders, respectively, so `R<=5` qualifies
114 states. Label reflection gives 57 BUY and 57 SELL states. The pre-market
density is `12*114/252 = 5.4286` decisions/year before data failures and
median-price mechanics. This is not a significance or performance claim.

### Separating fixtures

- Labels `OOONNONNN O` after strict sorting (spaces ignored) have five runs
  and qualify; a chronological permutation inside either block must not
  change this card but can change `QM5_41182`.
- Labels `ONONONONON` have ten runs and stay flat even though either block can
  have a higher median.
- Two pooled orders with the same Mann-Whitney cross-block win sum but run
  counts five and six must produce qualify/flat here.
- Reflecting every label preserves the run count and reverses median side.

The pure reference suite must enumerate all 252 label orders, verify the
distribution `2,8,32,72,72,32,32,8,2` for runs 2 through 10, verify 57/57
directional qualifying states under rank medians, and lock these separating
fixtures against chronological median-runs and signed-ECDF logic.

### Entry and risk

- Exact host/traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `411840000`.
- One owned position maximum; never scale, grid, pyramid, or retry the month.
- Require spread at most 1,500 points and valid bid/ask.
- Size through the V5 fixed-risk helper using `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` against a frozen
  `3.5*ATR(20,D1)` stop.
- Attach the hard stop to the market request. No take-profit.

### Lifecycle and repair

- Close at the first later normalized broker month.
- Close after forty elapsed calendar days if the rollover exit was missed.
- Immediately flatten malformed, duplicate, wrong-symbol, wrong-side, or
  stopless owned exposure before considering entry.
- There is no signal-flip exit, recount exit, trail, break-even move, partial
  close, Friday close, or news exit.

## Risk

### Fixed backtest contract

The only authorized preset is `XTIUSD.DWX`, D1, `environment=backtest`,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both news axes
and the legacy mode are OFF; Friday close is OFF. There is no optimization
surface.

Principal risks are WTI gaps, continuous-CFD roll/basis and financing, stale
month endpoints, small-block instability, a non-significant density boundary,
abrupt reversal after an apparent shift, stop slippage, and realized overlap
with XNG or risk assets. The fixed-dollar stop bounds intended risk but cannot
guarantee fill price through a gap.

### Kill criteria

Retire on any of:

- zero Q02 trades;
- fewer than five completed trades in any full post-warm-up year;
- nonpositive governed Q02 economics;
- endpoint, block, tie, sort, run-count, median, side, attempt, stop, risk,
  rollover, repair, or determinism defect;
- any downstream gate failure under unchanged criteria.

No failure may be rescued by changing endpoint count, block size, run
boundary, side, carrier, risk, stop, hold, or by adding a filter.

## Framework Alignment

| Module | Authorized implementation |
|---|---|
| No-Trade | exact symbol/period/config gates, owned-exposure repair, month-attempt ledger, entry window, news/filter hook |
| Trade Entry | endpoint reconstruction, strict pooled label-run count, block medians, spread/ATR/fixed-risk market request |
| Trade Management | no discretionary management; repair remains fail-closed |
| Trade Close | next-month and forty-day stale exits |

Development may add only the framework plumbing necessary to implement these
rules. No source or coding convenience authorizes another filter.

## Allowability Checklist

- [x] R1: exactly one governed source ID; public method access limit recorded.
- [x] R2: direction, entry, exit, stop, sizing, attempt, and repair are fixed.
- [x] R3: `XTIUSD.DWX` D1 is a registered native test route.
- [x] R4: deterministic native arithmetic; no prohibited trained component.
- [x] One position per magic; no grid, martingale, scale-in, or pyramid.
- [x] Exact dedup checker returned CLEAN and manual mechanic review is clean.
- [x] Random-rank density prior exceeds the five-trade annual floor.
- [x] `RISK_FIXED` backtest mode is explicit.
- [x] Live, portfolio, deployment, and AutoTrading surfaces remain excluded.

## Parameters To Test

One locked Q02 baseline only:

| Input | Value |
|---|---:|
| completed endpoints | 10 |
| fixed block size | 5 |
| maximum qualifying label runs | 5 |
| D1 reconstruction buffer | 900 bars |
| entry grace | 180 minutes |
| newest endpoint staleness | 10 days |
| ATR stop | period 20, multiplier 3.5 |
| stale exit | 40 calendar days |
| maximum spread | 1,500 points |
| deviation | 20 points |

## Author Claims

None. The exact conjunction is an untested Codex synthesis. Supporting
sources contribute no WTI-only return or CFD performance claim.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-27 | initial OWNER-authorized build | Q01 pending | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-27 | APPROVED | G0 decision and this card |
| Q01 Build Validation | TBD | NOT_BUILT | TBD |
| Q02 Baseline Screening | TBD | NOT_ENQUEUED_Q01_PENDING | TBD |
| Q03+ | TBD | NOT_STARTED | governed pipeline only |

## Safety Boundary

This card authorizes only a branch-local source build, strict non-live Q01,
and one paced Q02 enqueue after Q01/review PASS and below the CPU ceiling. It
does not authorize manual backtests; live/demo/shadow/stress/optimization
presets; `T_Live`; AutoTrading; deploy/live manifests; portfolio-gate edits;
portfolio admission; correlation waivers; terminal control; or claims of
profitability, certification, or decorrelation.
