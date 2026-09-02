---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MLZ76-TREND-20260902_S01
variant_id: AI-CODEX-WTI-MLZ76-TREND-20260902_S01
source_id: AI-CODEX-WTI-MLZ76-TREND-20260902
ea_id: QM5_41309
slug: wti-mlz76-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41309_wti-mlz76-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41309_wti_monthly_lz76_complexity_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_lz76_complexity_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Abraham Lempel; Jacob Ziv; Janusz Szczepanski; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "OpenAI Codex (2026), WTI monthly LZ76 sign-complexity-gated trend; supporting records Lempel and Ziv (1976), IEEE Transactions on Information Theory 22(1), DOI 10.1109/TIT.1976.1055501; Szczepanski (2009), Information Sciences 179(9), DOI 10.1016/j.ins.2008.12.019; and Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly LZ76 sign-complexity-gated trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-MLZ76-TREND-20260902/source.md
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_threshold_risk_and_lifecycle
  - type: peer_reviewed_statistical_method
    citation: "Szczepanski, J. (2009). On the Distribution Function of the Complexity of Finite Sequences. Information Sciences 179(9), 1217-1220."
    location: "DOI 10.1016/j.ins.2008.12.019; complete manuscript https://arxiv.org/abs/math/0009084"
    quality_tier: A
    role: lz76_exhaustive_history_component_count_and_finite_word_distribution
  - type: original_statistical_method_provenance
    citation: "Lempel, A. and Ziv, J. (1976). On the Complexity of Finite Sequences. IEEE Transactions on Information Theory 22(1), 75-81."
    location: "DOI 10.1109/TIT.1976.1055501; bibliographic provenance only"
    quality_tier: A
    role: original_lz76_provenance_only
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-twenty-completed-log-return-signs-binary-lz76-unique-exhaustive-history-component-count-inclusive-six-gated-newest-twelve-month-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MLZ76-TREND-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/lempel-ziv-complexity]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/lz76-exhaustive-history-complexity]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, lz76-complexity, binary-sign-word, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413090000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6-7 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact equiprobable 20-bit word density is 6.7529 states/year. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_METHOD_AND_TRADING_READ
r1_reasoning: "One durable AI-originated source ID; complete accessible LZ76-definition manuscript; verified original IEEE provenance; complete governed peer-reviewed WTI trading-paper read; exact conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, 21 endpoints, 20 returns, binary map, tie rule, shortest-new-phrase prefix, final-component exception, phrase reconstruction, raw count bounds, inclusive C<=6 gate, newest-12m direction, consumed attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, comparisons, bounded strings, substring equality, integer counts, ATR risk, quotes, positions, deals, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 21 consecutive completed month-end closes; 20 adjacent log returns; binary sign epsilon 1e-12; exact LZ76 unique exhaustive-history shortest-new-phrase parsing; raw component count 2..9; inclusive complexity ceiling 6; newest 12m cumulative log-return direction epsilon 1e-12; 1000 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly binary-phrase-complexity-gated trend sleeve outside the certified XAU/SP500/NDX/XNG book. Verify completed endpoints, return/sign orientation, exact LZ76 search prefix and shortest phrase, final suffix handling, phrase reconstruction, inclusive C=6/C=7 boundary, newest-12m side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, twenty_one_consecutive_completed_months, no_current_month_price, twenty_adjacent_log_returns, binary_sign_orientation, deterministic_tie_rejection, exact_lz76_shortest_new_phrase, prefix_ends_before_terminal_bit, final_component_exception, complete_phrase_reconstruction, raw_complexity_bounds, inclusive_complexity_six, newest_twelve_month_continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41309_wti_monthly_lz76_complexity_trend_g0.md: R1 passes with complete accessible method and WTI evidence plus explicit synthesis boundaries; R2 locks all sign, phrase, risk, attempt, and lifecycle arithmetic; R3 uses registered native WTI D1 with continuous-CFD risk; R4 is deterministic native arithmetic and bounded string comparison only. Corrected-root dedup returned CLEAN across 4,794 registry rows, 1,423 cards, and 45 Wiki nodes; manual review separates ordinal entropy, sign-run/Wald-Wolfowitz, sign-count/vote/breadth, pure WTI trend, distribution, scale, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41309 WTI Monthly LZ76 Complexity Trend

## Hypothesis

WTI has physical supply, storage, transport, refining, hedging, geopolitical,
and demand drivers absent from the certified XAU, SP500, NDX, and XNG carrier
set. When the last twenty completed monthly WTI return directions form a word
with relatively few new variable-length phrases, the path may be structured
enough for the established newest twelve-month return direction to persist for
another broker month.

This is a falsifiable direct-crude structural trend sleeve. It is not evidence
of profitability, predictability, independence, or decorrelation. Q02 owns
activity and baseline economics; unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MLZ76-TREND-20260902/source.md`, SHA-256
`6C03347BB420026B8B5B7D607A593158BE518C4AB8AF3EC258E345D1143095CD`,
approved at commit `1496422063436b9ae09b9b825761dd52c572d96e` before card
extraction.

Szczepanski's complete method manuscript defines the unique LZ76 exhaustive
history and its component count. The original Lempel-Ziv IEEE record supplies
provenance. Moskowitz, Ooi, and Pedersen supply the WTI carrier and monthly
own-return continuation lineage. None tests the exact twenty-sign conjunction,
raw ceiling six, Darwinex CFD, fixed risk, stop, spread, attempt state, or
lifecycle.

## Non-Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_wti_mlz76_tr_preallocation_dedup_20260902.json` found no exact
or fuzzy identity across 4,794 registry rows, 1,423 cards, and all 45 Strategy
Wiki nodes. Manual semantic review resolves the nearest families:

- `QM5_41308` uses return magnitudes, six order-three patterns, eight disjoint
  triples, and Shannon entropy. This card uses only a twenty-bit sign word,
  variable-length shortest-new phrases, and raw component count.
- `QM5_20273` and Wald-Wolfowitz relatives count adjacent or grouped runs; the
  LZ76 history depends on repeated substrings of every permitted length.
- WTI sign-count, breadth, vote, block, endpoint, regression, rank,
  distribution-shift, scale, same-calendar, event, and channel rules do not
  parse a finite binary word into exhaustive phrases.
- `00000001101110100100` and `00000001101110101000` both contain seven ones
  and nine runs, but parse to `C=6` and `C=7`. The first qualifies and the
  second does not, so this is not a renamed sign/run gate.
- Certified `QM5_12567` is a long-only two-day XNG cumulative-RSI pullback.

Verdict:
`CLEAN_WTI_MONTHLY_20_RETURN_SIGN_LZ76_EXHAUSTIVE_HISTORY_COMPLEXITY_LE6_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and slot 0: `XTIUSD.DWX`, D1.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the host D1 boundary.
- Formation: twenty-one consecutive completed broker-month-end closes; every
  current-month price is excluded.
- State: LZ76 raw component count of twenty return signs.
- Direction: cumulative log return of the newest twelve completed months.
- Hold: next genuine broker month, with forty-calendar-day stale repair.
- Expected cadence: about 6-7 completed positions per full post-warm-up year.
  Q02 retires any full scored year below five.

## Exact Formula

For chronological completed-month closes `C[0..20]`:

```text
r[i] = ln(C[i+1] / C[i]), i=0..19
s[i] = "1" if r[i] > 1e-12
s[i] = "0" if r[i] < -1e-12
```

Any `abs(r[i]) <= 1e-12` is invalid and consumes the month flat.

Starting at word position `p`, choose the shortest nonempty phrase `S[p..q]`
that does not occur inside prefix `S[0..q-1]`, which ends before the phrase's
terminal bit. Append that phrase and continue at `q+1`. If the remaining
suffix never becomes new before word end, append it once as the permitted
non-exhaustive final component. Require concatenated phrases to equal all
twenty bits and component count `C(S)` to be within `2..9`.

```text
qualifies = C(S) <= 6
mom12     = sum(r[8..19])
BUY       = qualifies and mom12 > 1e-12
SELL      = qualifies and mom12 < -1e-12
FLAT      = otherwise
```

The raw component count and momentum magnitude never scale risk. The method
reference `0011011101110110` must parse as
`0 | 01 | 10 | 111 | 01110110` with `C=5`.

## Rules

These are the complete authorized baseline. No signal sweep, alternate LZ
variant, normalizer, entropy substitution, compression library, fallback to
unqualified momentum, or result-based repair is authorized.

### Entry Rules

1. Require exact EA ID `41309`, `XTIUSD.DWX` D1, slot 0, magic `413090000`,
   seed 42, and every baseline input locked to its declared value.
2. Process lifecycle repair before entry-only gates and evaluate only at a
   genuine broker-month transition within the 180-minute grace window.
3. Persist the current normalized month key before history, signal, spread,
   quote, news, ATR, sizing, margin, or order checks. Never retry that month.
4. Reject owned exposure, foreign exposure on the host symbol, or an existing
   same-month entry deal for the magic.
5. Reconstruct exactly twenty-one consecutive completed month-end closes from
   bounded D1 history. Require positive finite closes, strictly increasing
   endpoint timestamps, newest endpoint before the decision bar and no more
   than ten calendar days stale, and no current-month price.
6. Form exactly twenty chronological adjacent log returns. Encode each as the
   exact binary sign map; an inclusive epsilon tie fails closed.
7. Parse the full word under the exact LZ76 phrase rule. Require shortest-new
   phrases, only the final component potentially non-exhaustive, exact word
   reconstruction, and raw count `2..9`.
8. Consume flat at `C>6`. At `C<=6`, sum exactly `r[8]..r[19]`; buy above the
   positive epsilon, sell below the negative epsilon, and consume zero flat.
9. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and fixed-risk sizing.
10. Open at most one market position with a frozen `3.5*ATR(20,D1)` broker
    hard stop and no take-profit.

### Exit Rules

1. Close the prior position at the next genuine broker-month transition
   before considering replacement, even when direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, wrong-side, or missing-stop
   owned exposure.
4. Broker hard stop and framework kill switch remain authoritative.
5. Friday close is disabled because the authorized hold spans weekends.
6. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is allowed.

### Filters And No-Trade Rules

- Fail closed outside exact symbol, timeframe, ID, slot, magic, seed, risk,
  news/Friday contract, or locked inputs.
- Fail closed on malformed month labels, late restart, nonconsecutive or stale
  endpoints, current-month leakage, invalid prices, returns, signs, phrases,
  phrase reconstruction, component bounds, above-ceiling complexity, neutral
  momentum, prior attempt/deal, owned or foreign exposure, excessive spread,
  invalid quote, unavailable ATR, invalid stop, or invalid metadata.
- Both news axes and legacy news mode are locked OFF. Lifecycle repair and
  monthly close execute before entry-only gates.
- Runtime may not read a futures curve, inventory report, volume, open
  interest, file, API, analyst forecast, trained output, optimizer result,
  prior PnL, portfolio state, or external calendar.

### Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after
  forty calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization removes only a future
  marker from another run so historical tests remain deterministic.
- Recompute the expected current-month direction from the same completed
  endpoints when validating a recovered position. Close on any mismatch.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_month_returns` | 20 | [20] | binary word length |
| `strategy_complexity_ceiling` | 6 | [6] | inclusive raw LZ76 gate |
| `strategy_sign_epsilon` | 1e-12 | [1e-12] | deterministic return tie band |
| `strategy_momentum_months` | 12 | [12] | newest continuation slice |
| `strategy_direction_epsilon` | 1e-12 | [1e-12] | neutral momentum band |
| `strategy_history_bars` | 1000 | [1000] | bounded D1 month-end reconstruction |
| `strategy_entry_grace_minutes` | 180 | [180] | first-bar execution window |
| `strategy_endpoint_stale_days` | 10 | [10] | newest endpoint freshness |
| `strategy_atr_period` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_stale_days` | 40 | [40] | lifecycle repair limit |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, phrase/search semantics, sign and return orientation, component
bounds, direction, entry clock, risk, stop, hold, and no-retry policy are
locked. Any change requires a new card and full pipeline.

## Author Claims

Szczepanski defines the LZ76 exhaustive-history component count and finite-word
distribution; Lempel and Ziv are the original method provenance. Moskowitz,
Ooi, and Pedersen document time-series momentum across liquid futures, report
one-to-twelve-month continuation, and explicitly include WTI. None claims this
binary complexity gate predicts WTI, transfers to a continuous CFD, clears
costs, trades often enough, or diversifies the current book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, roll/basis and financing,
single-name concentration, short finite-word inference, hard-stop slippage,
month-label errors, and correlation with XNG or risk assets can dominate the
premise. A low LZ76 count describes repetition; it does not establish a trend,
stationarity, prediction, or independence.

## Kill Criteria

- Retire on zero positions or fewer than five completed positions per full
  post-warm-up year.
- Fail on wrong endpoint count/order, nonconsecutive months, current-month
  leakage, reversed return orientation, wrong sign map, accepted tie, any
  phrase that is not shortest-new under the exact prefix, wrong final-suffix
  treatment, phrase reconstruction failure, component count outside `2..9`,
  inclusive boundary error, wrong momentum slice/side, repeated monthly
  attempt, missing hard stop, hold beyond forty days, invalid risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing word length, parser, ceiling, sign or
  direction epsilon, momentum horizon, side, entry clock, stop, hold, spread,
  retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: one governed AI source with a complete accessible method manuscript,
  original IEEE provenance, complete peer-reviewed WTI trading evidence, and
  explicit synthesis boundaries.
- [x] R2: fixed endpoints, returns, binary word, exact LZ76 phrases/count,
  threshold, direction, attempt, hard stop, renewal, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: deterministic logarithm, comparisons, bounded string/substrings,
  integer counts, calendar, and ATR arithmetic; no trained output or external
  runtime feed.
- [x] Dedup: deterministic checker CLEAN; ordinal entropy, sign-run, sign
  count/vote/breadth, pure trend, distribution, scale, calendar, event, and
  channel neighbors were manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/ID/slot/magic/seed, locked inputs, fixed risk,
  news/Friday contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, return
  signs, exact phrase parsing/reconstruction, complexity gate, momentum side,
  spread/quote/ATR/stop checks, and one fixed-risk order.
- trade_management: malformed-state repair, recovered-direction validation,
  prior-month exit, and stale exit before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, reference fixtures, and one non-live paced Q02 handoff. It does
not authorize a manual backtest; live, demo, shadow, optimization, or stress
setfile; terminal control; AutoTrading; `T_Live`; deploy or T_Live manifest;
portfolio admission; portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial source-bounded WTI LZ76 complexity trend card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41309_wti_monthly_lz76_complexity_trend_g0.md` |
| Q01 Build Validation | - | NOT_BUILT | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | - |
