---
card_schema_version: 2
type: strategy
strategy_id: RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902_S01
variant_id: RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902_S01
source_id: RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902
ea_id: QM5_41311
slug: wti-msampen-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41311_wti-msampen-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41311_wti_monthly_sample_entropy_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_sample_entropy_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Joshua S. Richman; J. Randall Moorman; Jiri Tomcala; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "QuantMechanica governed WTI sample-entropy synthesis; Tomcala (2020), Entropy 22(8), DOI 10.3390/e22080863; Richman and Moorman (2000), American Journal of Physiology-Heart and Circulatory Physiology 278(6), DOI 10.1152/ajpheart.2000.278.6.H2039; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_statistical_method
    citation: "Tomcala, J. (2020). New Fast ApEn and SampEn Entropy Algorithms Implementation and Their Application to Supercomputer Power Consumption. Entropy 22(8), 863."
    location: "DOI 10.3390/e22080863; complete open-access article read via PubMed Central PMC7517465"
    quality_tier: A
    role: sample_entropy_formula_complexity_interpretation_and_default_parameters
  - type: transparent_statistical_implementation
    citation: "CRAN TSEntropies 0.9, SampEn_R.R."
    location: "https://raw.githubusercontent.com/cran/TSEntropies/master/R/SampEn_R.R; SHA-256 2E74A7DA4C836E039E48F7985E68218D8C23B954AAEE5051873AD2BC7CF73933"
    quality_tier: A_method_implementation
    role: strict_radius_chebyshev_distance_sample_sd_template_and_count_semantics
  - type: original_statistical_method_provenance
    citation: "Richman, J. S. and Moorman, J. R. (2000). Physiological time-series analysis using approximate entropy and sample entropy. American Journal of Physiology-Heart and Circulatory Physiology 278(6), H2039-H2049."
    location: "DOI 10.1152/ajpheart.2000.278.6.H2039; publisher metadata and abstract only"
    quality_tier: A_provenance
    role: original_sample_entropy_provenance
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: governed_composite_source
    citation: "QuantMechanica (2026). WTI monthly sample-entropy-gated trend."
    location: strategy-seeds/sources/RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902/source.md
    quality_tier: governed_source
    role: exact_conjunction_threshold_risk_attempt_and_lifecycle
strategy_mechanic: monthly-wti-sixty-completed-log-returns-m2-lag1-strict-chebyshev-radius-020-sample-sd-sample-entropy-inclusive-250-gated-newest-twelve-month-continuation
sources:
  - "[[sources/RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/sample-entropy]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/sample-entropy]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, sample-entropy, template-recurrence, complexity-gate, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413110000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately seven completed WTI positions per full post-warm-up year; one consumed attempt per broker month. A fixed-seed market-free null prior qualified 59.272%. Q02 must prove at least five trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_BOUNDARY
r1_reasoning: "Complete peer-reviewed open-access method article, complete pinned transparent CRAN method file, original peer-reviewed provenance, complete governed peer-reviewed WTI trading-paper read, and explicit disclosure that the exact conjunction is untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, 61 endpoints, 60 returns, sample mean and standard deviation, strict Chebyshev radius, m2/m3 templates, self-match exclusion, count invariants, log ratio, inclusive 2.5 gate, newest-12m direction, consumed attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed prices, timestamps, logarithms, sums, bounded pair comparisons, sample standard deviation, ATR risk, quotes, positions, deals, and persistent state; no trained output or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 61 consecutive completed month-end closes; 60 adjacent log returns; sample sd with denominator 59 and floor 1e-12; embedding m=2; lag=1; radius=0.2*sample-sd; strict Chebyshev distance; no self-matches; original CRAN template counts; SampEn=ln(B/A); A>0 and B>=A; inclusive SampEn ceiling 2.5; newest 12m direction epsilon 1e-12; 1800 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly sample-entropy-gated continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, returns, sample-sd radius, exact strict template matches/counts, log ratio and inclusive boundary, newest-12m side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_one_consecutive_completed_months, no_current_month_price, sixty_adjacent_log_returns, chronological_return_orientation, exact_sample_sd, radius_020_sample_sd, m2_lag1_templates, strict_chebyshev_match, self_match_exclusion, exact_template_counts, positive_match_counts, sample_entropy_log_ratio, inclusive_entropy_250, newest_twelve_month_continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41311_wti_monthly_sample_entropy_trend_g0.md: R1-R4 pass within disclosed synthesis and continuous-CFD risks. Corrected-root dedup returned CLEAN across 4,796 registry rows, 1,425 cards, and 45 Wiki nodes; manual review separates raw-magnitude template recurrence from ordinal entropy, LZ76, raw von Neumann, intraday Shannon entropy, pure momentum, variance-ratio, sign, regression, distribution, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41311 WTI Monthly Sample-Entropy-Gated Trend

## Hypothesis

WTI carries physical supply, storage, transport, refining, geopolitical,
hedging, and demand risks absent from the certified XAU, SP500, NDX, and XNG
carrier set. When sixty completed monthly WTI returns contain unusually
repeatable local magnitude templates, the newest twelve-month direction may
persist for one more broker month.

This is a falsifiable direct-crude structural trend sleeve. It is not evidence
of profitability, predictability, significance, independence, or
decorrelation. Q02 owns cadence and baseline economics; unchanged Q09 alone
owns portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902/source.md`,
SHA-256
`79595F30663A90E8268874CB7C36B4F876C047BDE36BC3B1E3501B81CA9EC13A`,
approved at commit `6258f9e3a5` before card extraction.

Tomcala and the pinned CRAN method file fix the exact sample-entropy
arithmetic. Richman and Moorman supply original provenance. Moskowitz, Ooi,
and Pedersen supply only the WTI carrier and monthly own-return continuation
lineage. None tests this conjunction, window, threshold, CFD, fixed risk,
costs, lifecycle, activity, or portfolio fit.

## Non-Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_wti_msampen_tr_preallocation_dedup_20260902.json`, SHA-256
`1DC955560717980BCB73A2B69DBDB64CA038E5EFC990E7D0C1E9AFE827D11CF6`,
returned `CLEAN` across 4,796 registry rows, 1,425 cards, and all 45 Strategy
Wiki nodes.

- `QM5_41308` uses six rank-order labels from eight disjoint triples and is
  invariant to magnitude-preserving order. This rule counts overlapping raw-
  magnitude templates at dimensions two and three.
- `QM5_41309` parses a twenty-bit return-sign word into LZ76 phrases. It has
  no magnitude radius or conditional template-match ratio.
- `QM5_41310` compares squared adjacent changes with total dispersion. It has
  no template recurrence or entropy logarithm.
- `QM5_9520` trades intraday ternary Shannon-state crossings, not a monthly
  WTI complexity gate.
- Pure trend, variance-ratio, sign-run/count, rank, regression, location,
  scale, distribution-shift, calendar, event, and channel EAs use different
  state objects. Certified `QM5_12567` is a two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_60_RETURN_M2_R020SD_SAMPEN_LE250_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and slot zero: `XTIUSD.DWX`, D1, governed magic `413110000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the host D1 boundary.
- Formation: sixty-one consecutive completed broker-month-end closes;
  current-month prices are excluded.
- Hold: next broker month, with forty-calendar-day stale repair.
- Expected cadence: approximately seven completed positions/year. Q02
  retires any full scored post-warm-up year below five.

## Exact Formula

For chronological completed-month closes `C[0..60]`:

```text
x[i] = ln(C[i+1] / C[i]), i=0..59
mean = sum(x[i]) / 60
sd   = sqrt(sum((x[i]-mean)^2) / 59)
r    = 0.2 * sd
```

For dimension `d` in `{2,3}`, define lag-one templates
`T_d(i)=(x[i],...,x[i+d-1])`, `i=0..60-d`. Count unordered distinct pairs
whose maximum coordinate distance is strictly below `r`:

```text
B = count length-two matching pairs over i,j in 0..58, i<j
A = count length-three matching pairs over i,j in 0..57, i<j
SampEn = ln(B/A)
mom12  = sum(x[48..59])

BUY  iff B>=A>0, SampEn <= 2.5 and mom12 > +1e-12
SELL iff B>=A>0, SampEn <= 2.5 and mom12 < -1e-12
FLAT otherwise
```

Require finite arithmetic, `sd>1e-12`, `r>0`, integer count invariants, and
nonnegative finite sample entropy. A distance exactly equal to `r` is not a
match. Entropy and momentum magnitude never alter risk.

## Rules

- Consume the normalized broker month before history, signal, news, spread,
  quote, ATR, sizing, margin, or order gates. Never retry that month.
- Select the latest close in each immediately prior consecutive broker month
  from a bounded 1,800-D1 buffer.
- Reject current-month input, missing/duplicate/nonconsecutive month keys,
  nonchronological endpoints, nonpositive closes, a stale newest endpoint,
  invalid returns/radius/counts/entropy, high entropy, or neutral momentum.
- Permit neither foreign `XTIUSD.DWX` exposure nor existing owned exposure.
- Both news axes, legacy news, Friday close, and stress rejection are OFF.
- Q02 has one locked baseline and no optimization surface.

## 4. Entry Rules

1. Require EA ID 41311, exact `XTIUSD.DWX` D1, slot zero, magic 413110000,
   fixed-risk mode, framework defaults, and every strategy input locked.
2. Run lifecycle repair before entry-only gates.
3. Require a genuine new broker month inside the 180-minute entry window.
4. Persist the month attempt before every fallible gate.
5. Reconstruct the exact endpoints and chronological log returns.
6. Apply exact sample mean/sd, radius, template membership, strict distance,
   count invariants, sample entropy, inclusive `2.5` gate, and newest twelve-
   month direction.
7. Require spread in `[0,1500]`, valid quote/contract/tick/volume/margin
   metadata, and completed D1 ATR(20).
8. Open at most one position with a frozen `3.5*ATR` hard stop and no target,
   sized to the one fixed-dollar risk budget.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later broker month.
3. Close after forty elapsed calendar days as stale repair.
4. Close duplicate, wrong-symbol, invalid-type, wrong-side, missing-stop, or
   malformed entry-month exposure defensively.
5. There is no target, entropy exit, intramonth flip, Friday flatten, trail,
   break-even move, partial close, scale-in, grid, martingale, or pyramid.

## 6. Filters (No-Trade Module)

- Fail closed on wrong identity, symbol, period, slot, magic, seed, risk,
  news, Friday, stress, or locked strategy input.
- Fail closed on stale/nonconsecutive history, invalid closes/returns,
  sample-sd floor, radius, count invariant, nonfinite entropy, high entropy,
  neutral momentum, prior attempt/deal, spread, quote, ATR, sizing, or margin.
- Lifecycle handling precedes entry-only gates and does not depend on a new
  signal.
- Runtime may not use a futures curve, inventory, file, API, forecast,
  optimizer output, portfolio state, randomness, or trained artifact.

## 7. Trade Management Rules

- Exactly zero or one owned slot-zero WTI position is valid.
- Preserve the frozen broker hard stop and persisted entry-month state.
- Recompute the identical signal after restart when verifying expected side.
- Close at the next month, forty days, or malformed state. Do not resize,
  retry, partially close, scale in, or move the stop.

## Parameters To Test

Q02 has one locked baseline:

| parameter | value |
|---|---:|
| completed month-end closes | 61 |
| adjacent log returns | 60 |
| sample-sd denominator / floor | 59 / `1e-12` |
| embedding dimension / lag | 2 / 1 |
| radius | `0.2*sample-sd` |
| distance / boundary | Chebyshev / strict `<r` |
| self matches | excluded |
| sample entropy | `ln(B/A)`, require `B>=A>0` |
| inclusive entropy ceiling | `2.5` |
| direction | newest 12-month log-return sign |
| direction epsilon | `1e-12` |
| D1 history buffer | 1,800 bars |
| entry grace / endpoint staleness | 180 minutes / 10 days |
| ATR stop / stale hold | `3.5*ATR(20,D1)` / 40 days |
| spread ceiling | 1,500 points |

Changing any value creates a new variant and requires fresh evidence.

## Expected Behavior And Frequency

The fixed-seed market-free receipt, SHA-256
`AA3B42CC0E745595271B53306A515AAE81E1BC6BD9A053DA4AEB049DEDADA169`,
qualifies 59,272 of 100,000 independent standard-normal paths, or 7.11264
states per twelve clocks. Another 13,328 paths have no length-three match and
fail closed. This is a cadence sanity check only, not WTI evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The broker stop is frozen at `3.5*ATR(20,D1)` and no
take-profit is attached. Gaps can exceed modeled stop risk. WTI's continuous
CFD adds roll, basis, financing, and broker-session risks. Raw magnitude
templates are sensitive to scale estimates, outliers, and finite-sample
match scarcity. Live risk is not authorized.

## Data Requirements

- Native `XTIUSD.DWX` D1 time/close history and closed D1 ATR values.
- Broker time/month, quotes, spread, symbol metadata, margin, position/deal
  state, and terminal globals for attempt and entry-state persistence.
- No external runtime source.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- `qm_stress_reject_probability=0` in the canonical baseline.
- Kill-switch, weekend, broker-disconnect, and hard-stop coverage remain active.

## Exit Precedence

1. Kill switch / broker hard stop.
2. Malformed position or missing entry-month state repair.
3. Next genuine broker-month exit.
4. Forty-day stale exit.
5. No other strategy or framework calendar exit.

## Runtime Data Dependencies

- Tester host `XTIUSD.DWX`, D1, account currency USD, deposit 100,000.
- Q02 window `2018.07.02` through `2024.12.31`; pre-window history supplies
  the sixty-one-month formation where the custom archive permits it.
- MT5-native history/execution state only; no external API, file, future bar,
  trained artifact, inventory series, or curve data.

## Reputable-Source Gate Findings

- R1: PASS with complete method evidence, original provenance, and complete
  governed WTI trading-paper evidence under an explicit synthesis boundary.
- R2: PASS with exact deterministic signal, risk, and lifecycle rules.
- R3: PASS on registered native WTI D1, with explicit CFD transport risks.
- R4: PASS with bounded deterministic native arithmetic.

## Failure Modes And Kill Criteria

Retire or fail closed on formula/fixture mismatch, wrong return orientation,
wrong sample standard deviation, non-strict distance, wrong template range or
self-match handling, count/log/boundary error, zero positions, fewer than five
positions in any full post-warm-up year, nonpositive governed economics,
missing stop, invalid fixed-risk mode, nondeterminism, lifecycle deviation, or
any downstream gate failure. No post-result parameter repair is authorized.

## Execution And State Contract

- Persist one normalized month attempt before all fallible entry gates.
- Persist entry month only after confirmed fill and recover it from owned
  position/deal history if terminal state is lost.
- Use framework checked-magic, risk sizing, price/volume normalization, and
  governed order helpers. Never compute a runtime magic value by hand.
- Emit structured signal and lifecycle diagnostics without credentials.

## Portfolio Interaction

Direct WTI introduces crude-oil exposure absent from the certified carrier set
and uses neither the incumbent XNG cumulative-RSI logic nor a metal/index
carrier. This is a diversification hypothesis only. Q09 must measure realized
correlation and may reject it without a waiver.

## Validation Plan

1. Reference-test return orientation, sample sd/radius, strict template
   matches, no-self-match counts, log ratio, boundary, direction, and fixed
   fixtures.
2. Run card schema lint and strict Q01 compile/build checks.
3. Enqueue one canonical `RISK_FIXED` Q02 item only if CPU admission is clear.
4. Preserve any zero-trade, activity, or economic failure without changing
   the locked rule.

## Framework Alignment

| card rule | module |
|---|---|
| identity, risk/news/Friday contract, month attempt, endpoint and entropy state | `Strategy_NoTradeFilter` and bounded helpers |
| quote, spread, ATR, fixed-risk size, one WTI order | `Strategy_EntrySignal` |
| restart recovery, side validation, next-month and forty-day repair | `Strategy_ManageOpenPosition` |
| broker/framework reason mapping | `Strategy_ExitSignal` and V5 close helper |

## Safety Boundary

Authorized: deterministic identity/magic allocation, branch-only non-live
build, reference tests, strict Q01, one fixed-risk backtest set, and one paced
Q02 enqueue below the whole-host CPU ceiling.

Forbidden: optimization, manual tester launch, live/demo/shadow/stress sets,
portfolio-gate edit, correlation waiver, portfolio admission, deploy/live
manifest, `T_Live`, AutoTrading, terminal control, or live use.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial WTI sample-entropy trend card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_wti_monthly_sample_entropy_trend_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41311_wti_monthly_sample_entropy_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
