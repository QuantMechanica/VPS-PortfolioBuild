---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MORDENTROPY-20260902_S01
variant_id: AI-CODEX-WTI-MORDENTROPY-20260902_S01
source_id: AI-CODEX-WTI-MORDENTROPY-20260902
ea_id: QM5_41308
slug: wti-mordinal-entropy-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41308_wti-mordinal-entropy-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41308_wti_monthly_ordinal_entropy_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_ordinal_entropy_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Christoph Bandt; Bernd Pompe; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "OpenAI Codex (2026), WTI monthly order-3 permutation-entropy-gated trend; supporting records Bandt and Pompe (2002), Physical Review Letters 88, DOI 10.1103/PhysRevLett.88.174102, and Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly order-3 permutation-entropy-gated trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-MORDENTROPY-20260902/source.md
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_threshold_risk_and_lifecycle
  - type: peer_reviewed_statistical_method
    citation: "Bandt, C. and Pompe, B. (2002). Permutation Entropy: A Natural Complexity Measure for Time Series. Physical Review Letters 88, 174102."
    location: "DOI 10.1103/PhysRevLett.88.174102; complete official APS-rendered four-page paper"
    quality_tier: A
    role: ordinal_pattern_frequencies_entropy_formula_support_and_low_order_guidance
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-final25-month-end-closes-24-log-returns-eight-disjoint-order3-ordinal-patterns-six-state-normalized-permutation-entropy-inclusive-080-gated-newest-12m-return-sign-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MORDENTROPY-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/permutation-entropy]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/order-three-ordinal-pattern-entropy]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, permutation-entropy, ordinal-pattern, complexity-gate, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413080000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact pre-data uniform pattern-label density is 5.591 states/year. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_PEER_REVIEWED_EVIDENCE
r1_reasoning: "One durable AI-originated source ID; complete official APS method-paper read; complete governed peer-reviewed WTI trading-paper read; exact conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, 25 endpoints, 24 returns, eight disjoint triples, strict tie rule, six-pattern map, normalized entropy, inclusive 0.80 gate, newest-12-month direction, consumed attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, comparisons, bounded counts, entropy arithmetic, ATR risk, quotes, positions, deals, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 25 consecutive completed month-end closes; 24 adjacent log returns; eight non-overlapping chronological triples; six lexicographic order-three patterns; within-triple relative tie epsilon 1e-12 with fail-closed handling; normalized natural-log Shannon entropy divided by ln(6); inclusive H_norm ceiling 0.80; newest 12-month cumulative log-return direction epsilon 1e-12; 1200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly low-ordinal-complexity trend sleeve outside the certified XAU/SP500/NDX/XNG book. Verify completed endpoints, return orientation, exact disjoint triples, order-code map, tie rejection, entropy normalization and inclusive 0.80 boundary, newest-12-month side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, twenty_five_consecutive_completed_months, no_current_month_price, twenty_four_adjacent_log_returns, eight_disjoint_chronological_triples, exact_order3_pattern_map, deterministic_tie_rejection, six_pattern_counts_sum8, normalized_permutation_entropy, inclusive_entropy_080, newest_twelve_month_continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41308_wti_monthly_ordinal_entropy_trend_g0.md: R1 passes with complete peer-reviewed method and WTI evidence plus explicit synthesis boundaries; R2 locks all signal, risk, attempt, and lifecycle arithmetic; R3 uses registered native WTI D1 with continuous-CFD risk; R4 is deterministic native arithmetic only. Corrected-root dedup returned CLEAN across 4,793 registry rows, 1,422 cards, and 45 Wiki nodes; manual review separates the M15 Shannon-entropy, pure WTI TSMOM, sign/run/vote/breadth, distribution, scale, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41308 WTI Monthly Order-3 Permutation-Entropy Trend

## Hypothesis

WTI has physical supply, storage, transport, refining, hedging, geopolitical,
and demand drivers absent from the certified XAU, SP500, NDX, and XNG carrier
set. When the last two years of completed monthly WTI returns repeat a small
set of local three-return orderings, the path may be structured enough for
the newest twelve-month return direction to persist for another month.

This is a falsifiable direct-crude structural trend sleeve. It is not evidence
of profitability, predictability, independence, or decorrelation. Q02 owns
activity and baseline economics; unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MORDENTROPY-20260902/source.md`, SHA-256
`DE821B493BB33F7B1BFE8C1422F09C431B71A7406BC2DFE060F58A4301EA1A9C`,
approved at commit `c277ed7240` before card extraction.

Bandt and Pompe define ordinal-pattern frequencies, permutation entropy, its
support, and practical low orders. Moskowitz, Ooi, and Pedersen supply the WTI
carrier and monthly own-return continuation lineage. Neither source tests the
exact eight-triple conjunction, `0.80` gate, Darwinex CFD, fixed risk, stop,
spread, attempt state, or lifecycle.

## Non-Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_wti_mordinal_entropy_tr_preallocation_dedup_20260902.json`,
SHA-256
`A8269329F537EDECA505FD1350FF931172DA18BC409A5F601184A6B518B10F18`,
found no exact or fuzzy identity across 4,793 registry rows, 1,422 cards, and
all 45 Strategy Wiki nodes. Manual semantic review resolves the nearest
families:

- `QM5_9520` uses M15 up/down/flat Shannon-entropy crossovers and compression
  on several markets. This card uses six order-three patterns of monthly WTI
  returns as an entry gate and never trades an entropy cross.
- `QM5_12603` is pure monthly WTI twelve-month momentum. This card consumes
  every high-ordinal-entropy month flat.
- WTI sign-run, quarterly-vote, daily-breadth, rank, distribution-shift,
  scale, same-calendar, event, and channel EAs do not count the six local
  order patterns of eight disjoint return triples.
- Certified `QM5_12567` is a long-only two-day XNG cumulative-RSI pullback.

Verdict:
`CLEAN_WTI_MONTHLY_24_RETURN_EIGHT_DISJOINT_ORDER3_PATTERN_NORMALIZED_PERMUTATION_ENTROPY_080_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and slot 0: `XTIUSD.DWX`, D1.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the host D1 boundary.
- Formation: twenty-five consecutive completed broker-month-end closes;
  every current-month price is excluded.
- Hold: next genuine broker month, with forty-calendar-day stale repair.
- Expected cadence: about six completed positions per full post-warm-up year.
  Q02 retires any full scored year below five.

## Exact Formula

For chronological completed-month endpoints `c[0..24]`:

```text
r[i] = ln(c[i+1] / c[i]), i=0..23
T[k] = (r[3k], r[3k+1], r[3k+2]), k=0..7
```

Reject a triple when any pair is equal under
`1e-12*max(1,abs(left),abs(right))`. Otherwise classify `(a,b,c)`:

```text
pattern 0 = 012 when a < b < c
pattern 1 = 021 when a < c < b
pattern 2 = 102 when b < a < c
pattern 3 = 120 when c < a < b
pattern 4 = 201 when b < c < a
pattern 5 = 210 when c < b < a
```

For eight labels, require `sum(count[0..5])=8`, let `p[j]=count[j]/8`, and
compute:

```text
H_norm = -sum(p[j] * ln(p[j]), p[j]>0) / ln(6)
```

Qualify at inclusive `H_norm<=0.80`. Then
`mom12=sum(r[12..23])`: buy above `+1e-12`, sell below `-1e-12`, and consume
flat otherwise. Entropy and momentum magnitude never alter risk.

## Rules

- Consume the normalized broker month before history, signal, news, spread,
  quote, ATR, sizing, margin, or order gates. Never retry that month.
- Select the latest close in each of the twenty-five immediately prior,
  consecutive broker months from a bounded 1,200-D1 buffer.
- Reject current-month input, missing/duplicate/nonconsecutive month keys,
  nonchronological endpoints, nonpositive closes, stale newest endpoint,
  nonfinite returns/entropy, within-triple ties, a pattern-count invariant
  failure, or neutral momentum.
- Permit neither foreign `XTIUSD.DWX` exposure nor pre-existing owned
  exposure before entry.
- Both news axes, legacy news mode, Friday close, and stress rejection are off.
- Q02 has no optimization surface.

## 4. Entry Rules

1. Require EA ID 41308, exact `XTIUSD.DWX`, D1, slot 0, registered magic,
   fixed-risk mode, framework defaults, and every locked strategy input.
2. Run stale/month lifecycle management before entry-only gates.
3. Require a genuine new broker month inside the 180-minute entry window.
4. Persist the normalized month key before every fallible gate.
5. Reconstruct the exact twenty-five endpoints and twenty-four chronological
   log returns.
6. Apply exact disjoint triple membership, tie rejection, six-pattern map,
   count invariant, normalized entropy, inclusive `0.80` gate, and newest
   twelve-month direction.
7. Require a trade-enabled symbol, valid quote/contract/tick/volume/margin
   metadata, and spread no greater than 1,500 points.
8. Use closed D1 ATR(20) to freeze a `3.5*ATR` hard stop.
9. Size one position to `RISK_FIXED=1000`; send no take-profit and never scale.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first tick in a broker month later than the entry month.
3. Close after forty elapsed calendar days as stale-state repair.
4. Missing or invalid entry-month state while an owned position exists also
   triggers a defensive close.
5. There is no target, entropy exit, opposite signal, intramonth flip, Friday
   flatten, trail, break-even, partial close, scale-in, or pyramid.

## 6. Filters (No-Trade Module)

- Fail closed on wrong symbol, period, identity, slot, magic, risk, news,
  Friday-close, stress, or locked-input contract.
- Fail closed on stale/nonconsecutive history, bad closes/returns, ties,
  impossible pattern labels/counts, nonfinite entropy, high entropy, neutral
  momentum, spread, quote, ATR, sizing, or margin.
- The no-trade hook never closes exposure; lifecycle belongs in management.
- Runtime may not use futures chains, files, APIs, volume, inventory,
  forecasts, optimizer output, portfolio state, randomized tie breakers, or
  trained artifacts.

## 7. Trade Management Rules

- Exactly zero or one owned slot-0 WTI position is valid.
- Preserve the frozen broker hard stop and entry-month state.
- Close at the next genuine month, forty elapsed days, or malformed state.
- No resize, stop move, retry, partial close, scale-in, or new signal is
  authorized during the hold.

## Parameters To Test

Q02 has one locked baseline:

| parameter | value |
|---|---:|
| completed month-end closes | 25 |
| adjacent log returns | 24 |
| ordinal blocks | 8 disjoint triples |
| ordinal order / labels | 3 / 6 |
| relative tie epsilon | `1e-12` |
| entropy normalization | `ln(6)` |
| inclusive entropy ceiling | `0.80` |
| direction | newest 12-month log-return sign |
| direction epsilon | `1e-12` |
| D1 history buffer | 1,200 bars |
| entry grace | 180 minutes |
| endpoint gap ceiling | 10 days |
| ATR stop | `3.5*ATR(20,D1)` |
| stale hold ceiling | 40 days |
| spread ceiling | 1,500 points |

Changing any value creates a new variant and requires fresh evidence.

## Expected Behavior And Frequency

Exhaustive enumeration of all `6^8=1,679,616` pattern-label strings admits
`782,496`, or `46.5877914952%`, at `H_norm<=0.80`. The discrete maximum
admitted entropy is `0.773705614469`; the next possible entropy is
`0.833915022608`. That is `5.5905` theoretical states per twelve attempts,
before actual returns and operational gates, not realized activity or
performance. The receipt hash is
`EC39456AD3C851820641D94CC140EE2BA4B9BCA2B5AC1D4F648A9E8D163AEED2`.

## Risk

| item | contract |
|---|---|
| backtest risk mode | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| portfolio weight | 1.0 |
| stop | frozen `3.5*ATR(20,D1)` |
| take-profit | none |
| concurrent exposure | one slot-0 WTI position |
| statistic sizing | forbidden |
| live risk | not authorized |

Gaps can exceed modeled stop risk. The continuous WTI CFD carries roll,
financing, basis, and broker-session risks absent from a futures study.

## Data Requirements

- Native `XTIUSD.DWX` D1 time/close history and closed D1 ATR values.
- Broker time/month, quotes, spread, symbol metadata, margin, position/deal
  state, and terminal globals for month-attempt and entry-state persistence.
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
2. Malformed or missing entry-month state repair.
3. Next genuine broker-month exit.
4. Forty-day stale exit.
5. No other strategy or framework calendar exit.

## Runtime Data Dependencies

- Tester host `XTIUSD.DWX`, D1, account currency USD, deposit 100,000.
- Q02 window `2018.07.02` through `2024.12.31` so the first scored attempt
  follows the required 25-month warm-up.
- MT5-native history/execution state only; no external API, file, future bar,
  trained artifact, inventory series, or curve data.

## Reputable-Source Gate Findings

- R1: PASS with one durable AI lineage and complete peer-reviewed method and
  trading-paper reads.
- R2: PASS with exact deterministic signal, risk, and lifecycle rules.
- R3: PASS on registered native WTI D1, with explicit CFD transport risks.
- R4: PASS with deterministic native arithmetic and one position per magic.

## Failure Modes And Kill Criteria

Retire or fail closed on formula/fixture mismatch, wrong return orientation,
overlapping triple membership, accepted tie, wrong pattern code or count,
entropy normalization/boundary error, zero positions, fewer than five
positions in a full scored post-warm-up year, nonpositive governed economics,
missing stop, invalid fixed-risk mode, nondeterminism, lifecycle deviation, or
any downstream gate failure. No post-result parameter repair is authorized.

## Execution And State Contract

- Persist one normalized month attempt before all fallible entry gates.
- Persist entry month only after confirmed fill and recover it from deal
  history if a restart loses terminal state.
- Use framework checked-magic, risk sizing, price/volume normalization, and
  governed order helpers. Never compute magic manually.
- Emit structured signal and lifecycle diagnostics without credentials.

## Portfolio Interaction

Direct WTI introduces crude-oil exposure absent from the certified carrier
set and uses neither the incumbent XNG cumulative-RSI logic nor a metal/index
carrier. This is a diversification hypothesis only. Q09 must measure realized
correlation and may reject it without a waiver.

## Validation Plan

1. Reference-test month extraction, return orientation, all six patterns,
   tie rejection, entropy/count invariants, inclusive boundary behavior,
   momentum direction, and density receipt.
2. Run card schema lint and strict Q01 compile/build checks.
3. Enqueue one canonical `RISK_FIXED` Q02 item only if CPU admission is clear.
4. Preserve any zero-trade, activity, or economic failure without changing
   the locked rule.

## Framework Alignment

| card rule | module |
|---|---|
| identity, risk/news/Friday contract, month attempt, endpoint and entropy state | `Strategy_NoTradeFilter` and bounded helpers |
| quote, spread, ATR, fixed-risk size, one WTI order | `Strategy_EntrySignal` |
| missing-state repair, next-month exit, forty-day stale repair | `Strategy_ManageOpenPosition` |
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
| v1 | 2026-09-02 | initial WTI ordinal-entropy trend card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_wti_monthly_ordinal_entropy_trend_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41308_wti_monthly_ordinal_entropy_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
