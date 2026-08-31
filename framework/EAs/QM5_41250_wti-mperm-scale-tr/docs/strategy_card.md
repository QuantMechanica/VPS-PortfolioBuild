---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MPERMSCALE-20260831_S01
variant_id: AI-CODEX-WTI-MPERMSCALE-20260831_S01
source_id: AI-CODEX-WTI-MPERMSCALE-20260831
ea_id: QM5_41250
slug: wti-mperm-scale-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41250_wti-mperm-scale-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41250_wti_monthly_permutation_mad_scale_trend_g0.md
source_approval: decisions/2026-08-31_wti_monthly_permutation_mad_scale_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI monthly exact-permutation robust scale-expansion continuation; supporting record Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly exact-permutation robust scale-expansion continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MPERMSCALE-20260831/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-twelve-completed-log-returns-fixed-six-old-six-recent-exact-924-label-permutation-median-absolute-deviation-expansion-recent-mean-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MPERMSCALE-20260831]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/robust-scale-regime]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/exact-permutation-mad-scale]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, robust-scale-expansion, exact-label-permutation, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412500000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-6 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_BOUNDARY
r1_reasoning: "One durable AI-originated source ID and complete-read peer-reviewed WTI evidence; exact robust-scale/permutation trading conjunction disclosed as an untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed samples, median/MAD definitions, all 924 assignments, inclusive tolerance, tail cap, recent-mean direction, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite sorts, medians, absolute deviations, deterministic enumeration, comparisons, ATR risk, quote, position, deal, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; fixed old/recent blocks of 6; even-sample median and median absolute deviation; all 924 six-label assignments; observed scale expansion above 1e-12; inclusive upper-tail comparison tolerance 1e-14; tail count at most 416; actual recent-block arithmetic-mean direction; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly robust scale-expansion sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact completed endpoints, log-return orientation, fixed six/six blocks, even-sample medians and MADs, complete 924-label enumeration, inclusive tolerance, tail cap 416, recent-mean direction, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, fixed_six_old_six_recent_membership, even_sample_median, median_absolute_deviation, positive_observed_scale_expansion, exact_924_label_assignments, inclusive_tail_comparison_tolerance, tail_count_cap_416, recent_mean_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41250_wti_monthly_permutation_mad_scale_trend_g0.md: R1 passes with one durable AI source, complete-read peer-reviewed WTI evidence, and explicit synthesis boundary; R2 locks endpoints, returns, blocks, medians, MADs, assignments, tail count, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found no exact identity across 4,749 registry rows, 1,387 cards, and 45 Wiki nodes; manual review separates Welch mean shift, nested VoV, monthly OHLC range, per-month L2 normalization, and certified-XNG families."
---

# QM5_41250 WTI Monthly Exact-Permutation Robust Scale Trend

## Hypothesis

WTI has physical supply, production, storage, transport, refining, hedging,
investment, geopolitical, and demand drivers absent from the certified
XAU/SP500/NDX/XNG carrier set. Those slow forces can move monthly WTI returns
into a wider dispersion regime. A robust scale expansion in the newest six
monthly returns that remains upper-tail under every fixed-size relabeling may
support continuing the recent block's direction for the next month.

This is a direct-crude structural-trend hypothesis, not evidence of
profitability or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source traceability and claim boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-WTI-MPERMSCALE-20260831/source.md`, authorized
by
`decisions/2026-08-31_wti_monthly_permutation_mad_scale_trend_source_approval.md`
at commit `45721646e9` before extraction. Its reproducible read evidence is
`strategy-seeds/sources/AI-CODEX-WTI-MPERMSCALE-20260831/retrieval_route_20260831.json`.

Moskowitz, Ooi, and Pedersen (2012) supply complete-read peer-reviewed monthly
own-return continuation evidence and explicit WTI membership. They do not
test this fixed twelve-return sample, six/six split, robust scale statistic,
924-label distribution, `416` boundary, WTI CFD, fixed risk, stop, or
lifecycle. No source performance, significance, density, cost, CFD-
equivalence, correlation, or portfolio statistic transfers.

## Non-duplicate boundary

The corrected-root pre-allocation checker found no exact identity across
4,749 EA registry identities, 1,387 card files, and 45 Strategy Wiki nodes.
It returned one expected fuzzy neighbor, `QM5_41249`, at score `0.53`.
Receipt:
`artifacts/qm5_wti_mperm_scale_tr_preallocation_dedup_20260831.json`.

The load-bearing differences are:

- Welch `QM5_41249` uses a standardized difference between two arithmetic
  means. This card qualifies on median absolute deviation expansion and the
  complete exact distribution of fixed-size relabelings; old/recent mean
  difference is not a qualification input.
- VoV `QM5_20298` compares two disjoint 252-sample distributions of rolling
  20-day realized volatility and trades a low-minus-high premium. This card
  uses twelve monthly returns and follows a robust scale expansion.
- range expansion `QM5_41108` compares two monthly high-low widths and follows
  the latest candle body. This card uses no monthly high, low, open, or body.
- volatility-normalized momentum `QM5_20288` divides each historical monthly
  return by its own within-month daily L2 path. This card never normalizes an
  individual return.
- certified `QM5_12567` is a long-only XNG cumulative-RSI pullback; this card
  is symmetric monthly WTI and contains no oscillator.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_EXACT_924_LABEL_PERMUTATION_ROBUST_SCALE_EXPANSION_RECENT_MEAN_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX` on D1, slot 0, magic `412500000`.
- Run only on the first executable D1 tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of raw current-bar open.
- Persist the new `yyyymm` attempt before every fallible entry gate. A
  restart, stop-out, invalid signal, or order failure never permits a same-
  month retry.
- Reconstruct exactly thirteen immediately prior consecutive completed
  broker-month end closes, oldest to newest, from a bounded 900-D1 buffer.
- Exclude every current-month price. Require positive finite closes, strict
  chronology, exact month continuity, and a newest endpoint no more than ten
  calendar days before the current month bar.

### Exact signal

For chronological completed-month closes `C[0..12]`:

```text
for i = 0..11:
    r[i] = log(C[i+1] / C[i])

old    = r[0..5]
recent = r[6..11]

median6(x): sort ascending; return (x[2] + x[3]) / 2
mad6(x):
    center = median6(x)
    dev[i] = abs(x[i] - center)
    return median6(dev)

observed = mad6(recent) - mad6(old)
require observed > 1e-12

tail_count = 0
assignment_count = 0
for each 12-bit mask having exactly six set bits:
    pseudo_recent = returns selected by the mask
    pseudo_old = the complement
    perm_delta = mad6(pseudo_recent) - mad6(pseudo_old)
    if perm_delta >= observed - 1e-14:
        tail_count += 1
    assignment_count += 1

require assignment_count == 924
require tail_count <= 416

mean_recent = sum(recent) / 6
BUY  iff mean_recent >  1e-12
SELL iff mean_recent < -1e-12
FLAT otherwise
```

Every close, logarithm, return, sort input, median, deviation, MAD,
difference, and mean must be finite. Non-expansion, an excessive tail count,
zero recent mean, malformed endpoint, wrong assignment count, or arithmetic
failure consumes the month flat. The fixed tail cap is a trading-density
boundary, not a significance level. There is no fitted split, sampled
resampling, fallback, or signal-strength sizing.

## 4. Entry Rules

- Reject an owned position or a same-magic entry deal already present for the
  current normalized broker month.
- Both news axes and legacy news mode are OFF. Friday close is OFF.
- Reject crossed or negative quotes and a genuinely positive spread above
  1,500 points. A modeled zero `.DWX` spread remains valid.
- Require valid completed-bar `ATR(20,D1)`, valid point/tick metadata, and a
  normalized stop distance of `3.5 * ATR`.
- Submit at most one market position with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one frozen broker hard stop, and no
  take-profit.

## 5. Exit Rules

- Close on the first tick whose normalized broker month differs from the
  entry month.
- Close after forty elapsed calendar days as stale repair.
- Broker hard stop remains authoritative. There is no target, opposite-
  signal exit, or same-month re-entry.

## 6. Filters (No-Trade Module)

- Fail closed on wrong symbol, timeframe, EA ID, slot, magic, unlocked input,
  risk mode, news mode, Friday-close mode, or stress state.
- Consume the month before history, signal, position, deal, spread, quote,
  ATR, stop, sizing, margin, or order checks.
- Reject malformed or current-month history, late attachment, an existing
  owned position, a same-month entry deal, non-expansion, excessive tail
  count, crossed quotes, excessive spread, invalid ATR/stop metadata, or a
  nonpositive fixed-risk size.

## 7. Trade Management Rules

- Repair malformed owned exposure before entry-only gates: duplicates, wrong
  symbol/magic, invalid volume, missing stop, or invalid open time close.
- Apply no stop modification after entry. There is no trail, break-even,
  partial close, grid, martingale, scale-in, or pyramid.

## Parameters to test

Q02 uses one locked baseline and no optimization surface:

| parameter | default | Q02 status | role |
|---|---:|---|---|
| `strategy_month_returns` | 12 | locked | adjacent completed monthly log returns |
| `strategy_block_size` | 6 | locked | fixed older and recent samples |
| `strategy_scale_epsilon` | `1e-12` | locked | strict robust scale expansion guard |
| `strategy_compare_tolerance` | `1e-14` | locked | conservative inclusive tail comparison |
| `strategy_tail_count_max` | 416 | locked | upper-tail assignment-density cap |
| `strategy_direction_epsilon` | `1e-12` | locked | recent-block mean direction tolerance |
| `strategy_history_bars` | 900 | locked | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | locked | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked | newest completed endpoint age ceiling |
| `strategy_atr_period` | 20 | locked | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen broker hard-stop multiple |
| `strategy_stale_days` | 40 | locked | survivor repair |
| `strategy_max_spread_points` | 1500 | locked | entry execution ceiling |

Changing the return count, split, median, MAD, assignment set, comparison
tolerance, tail cap, direction, risk, or hold after observing Q02 is
forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_BOUNDARY | One durable source ID; complete-read peer-reviewed WTI packet; exact scale/permutation translation disclosed as untested. |
| R2 | PASS | Clock, data, blocks, median/MAD, assignments, tail count, side, attempt, risk, stop, spread, and exits are exact. |
| R3 | PASS | Registered native WTI D1 and MT5 state only; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- WTI gaps, continuous-CFD roll/basis, financing, small-sample robust-scale
  instability, permutation ties, and month-label offsets are material risks.
- Retire on zero positions, fewer than five completed positions in any full
  post-warm-up year, nonpositive governed economics, or a failed
  deterministic fixture.
- Fail on current-month leakage, missing/duplicate months, wrong return order,
  wrong block membership, wrong even-sample median or MAD, a label assignment
  count other than 924, wrong inclusive comparison/tolerance, wrong `416`
  cap, wrong recent-mean direction, missing stop, wrong risk mode, same-month
  retry, or nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot, locked inputs, fixed-risk mode,
  month grace, persistent attempt, endpoint integrity, signal integrity,
  position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached robust-scale/permutation-qualified direction, one fixed-
  risk WTI order, frozen ATR hard stop, no target.
- trade_management: malformed-position repair, month rollover, and forty-day
  stale repair; no modification logic.
- trade_close: framework close helper, broker hard stop, and deterministic
  lifecycle reason mapping.

## Safety boundary

This card authorizes only one branch build, deterministic reference tests,
strict Q01, one D1 `RISK_FIXED` backtest setfile, and one paced non-live Q02
handoff if the governed CPU ceiling permits. It does not authorize a manual
tester run; live/demo/shadow/stress/optimization setfile; AutoTrading;
`T_Live`; deploy or live manifest; portfolio-gate mutation; portfolio
admission; or correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-31 | initial exact-permutation robust-scale WTI card | G0 | APPROVED; build pending |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-31 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
