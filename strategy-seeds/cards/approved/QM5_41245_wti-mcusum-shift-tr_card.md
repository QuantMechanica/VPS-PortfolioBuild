---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MCUSUM-20260831_S01
variant_id: AI-CODEX-WTI-MCUSUM-20260831_S01
source_id: AI-CODEX-WTI-MCUSUM-20260831
ea_id: QM5_41245
slug: wti-mcusum-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41245_wti-mcusum-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41245_wti_monthly_centered_cusum_shift_trend_g0.md
source_approval: decisions/2026-08-31_wti_monthly_centered_cusum_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; E. S. Page; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; NIST/SEMATECH"
source_citation: "OpenAI Codex (2026), WTI monthly centered-CUSUM return-regime shift trend; supporting records Page (1954), Biometrika 41(1/2), DOI 10.1093/biomet/41.1-2.100; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; NIST/SEMATECH CUSUM Control Charts."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly centered-CUSUM return-regime shift trend."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MCUSUM-20260831/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Page, E. S. (1954). Continuous Inspection Schemes. Biometrika 41(1/2), 100-115."
    location: "DOI 10.1093/biomet/41.1-2.100; bibliographic metadata only"
    quality_tier: A_record_only
    role: cumulative_sum_shift_detection_lineage
  - type: official_statistical_method
    citation: "NIST/SEMATECH Engineering Statistics Handbook, CUSUM Control Charts."
    location: "https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc323.htm; complete public page read"
    quality_tier: A_official_method
    role: cumulative_deviation_formula_and_mean_shift_interpretation
strategy_mechanic: monthly-wti-twelve-completed-log-returns-centered-cumulative-sum-unique-central-change-point-post-segment-mean-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MCUSUM-20260831]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/cumulative-sum-change-point]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/mean-centered-cumulative-sum]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, return-regime-shift, centered-cusum, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412450000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-9 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_METHOD_ACCESS_BOUNDARY
r1_reasoning: "One durable AI-originated source ID; complete-read peer-reviewed WTI evidence; named Page bibliographic record; complete official NIST method page; exact trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, centering, eleven path values, tie tolerance, central split, post-segment side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite arithmetic, comparisons, ATR risk, quote, position, deal, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; arithmetic centering; all k=1..11 path values; absolute tie epsilon 1e-12; unique k in 4..8; post-segment arithmetic mean side; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly return-regime shift sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact completed endpoints, log-return orientation, full-sample centering, every nonterminal CUSUM split, unique central maximum, post-segment return side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, full_sample_mean_centering, all_eleven_nonterminal_cusums, absolute_tie_epsilon, unique_maximum, central_split_four_to_eight, post_segment_mean_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41245_wti_monthly_centered_cusum_shift_trend_g0.md: R1 passes with one durable AI source, complete-read peer-reviewed WTI evidence, a named peer-reviewed method record, a complete official NIST page, and explicit synthesis/access boundaries; R2 locks endpoints, returns, centering, path, split, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup returned CLEAN across 4,744 registry rows, 1,382 cards, and 45 Wiki nodes; manual review separates rank, ECDF, pair-count, regression, and same-calendar families."
---

# QM5_41245 WTI Monthly Centered-CUSUM Shift Trend

## Hypothesis

WTI has physical supply, production, storage, transport, refining, hedging,
investment, geopolitical, and demand drivers absent from the certified
XAU/SP500/NDX/XNG carrier set. Those slow forces can shift the mean of monthly
WTI returns. A unique central maximum in the mean-centered cumulative-return
path can identify one dominant transition; the post-split mean sign is a
falsifiable direction for the next month.

This is a direct-crude structural-trend hypothesis, not evidence of
profitability or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source traceability and claim boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-WTI-MCUSUM-20260831/source.md`, authorized by
`decisions/2026-08-31_wti_monthly_centered_cusum_shift_trend_source_approval.md`.
Its reproducible retrieval evidence is
`strategy-seeds/sources/AI-CODEX-WTI-MCUSUM-20260831/retrieval_route_20260831.json`.

Supporting evidence is bounded as follows:

- Moskowitz, Ooi, and Pedersen (2012) supply complete-read peer-reviewed
  monthly own-return continuation evidence and explicit WTI membership.
- Page (1954) supplies a named peer-reviewed CUSUM bibliographic record; the
  article body was inaccessible and no body content is reconstructed.
- NIST supplies a complete official public description of cumulative sums
  around an estimated mean and their response to a mean shift.

None tests this retrospective twelve-return bridge, maximum-split rule,
central band, post-segment side, WTI CFD, fixed risk, stop, or lifecycle. No
source performance, significance, density, cost, CFD-equivalence, correlation,
or portfolio statistic transfers.

## Non-duplicate boundary

The corrected-root pre-allocation checker returned `CLEAN` across 4,744 EA
registry identities, 1,382 card files, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_wti_mcusum_shift_tr_preallocation_dedup_20260831.json`.

The load-bearing differences are:

- Pettitt `QM5_41172` ranks thirteen price levels and uses signed cumulative
  ranks. This card retains monthly return magnitudes, arithmetic centering,
  and the post-split return mean.
- KS `QM5_41183` fixes six old/six new price levels and keeps a signed ECDF
  count gap. This card searches eleven return splits and requires one central
  maximum excursion.
- Mann-Whitney `QM5_41176` counts fixed-block price pair wins. This card uses
  no ranks, fixed block, or pair counts.
- OLS `QM5_20261` fits a log-price slope and `R^2`. This card fits no line.
- same-calendar `QM5_41224` compares recurring named-month returns over ten
  years. This card uses one contiguous twelve-month path.
- certified `QM5_12567` is a long-only XNG cumulative-RSI pullback; this card
  is symmetric monthly WTI and contains no oscillator.

Verdict:
`CLEAN_WTI_MONTHLY_CENTERED_RETURN_CUSUM_UNIQUE_CENTRAL_SHIFT_POST_MEAN_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX` on D1, slot 0, magic `412450000`.
- Run only on the first executable D1 tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of the raw current bar open.
- Persist the new `yyyymm` attempt before every fallible entry gate. A restart,
  stop-out, invalid signal, or order failure never permits a same-month retry.
- Reconstruct exactly thirteen immediately prior consecutive completed broker-
  month end closes, oldest to newest, from a bounded 900-D1 buffer.
- Exclude every current-month price. Require positive finite closes, strict
  chronology, exact month continuity, and a newest endpoint no more than ten
  calendar days before the current month bar.

### Exact signal

For chronological completed-month closes `C[0..12]`:

```text
for i = 0..11:
    r[i] = log(C[i+1] / C[i])

mean = sum(r[0..11]) / 12
running = 0

for k = 1..11:
    running += r[k-1]
    S[k] = running - k*mean

M = max(abs(S[k]))
K = { k : abs(abs(S[k]) - M) <= 1e-12 }

qualify iff M > 1e-12 and size(K) == 1 and 4 <= K[0] <= 8
post_mean = sum(r[K[0]..11]) / (12-K[0])

BUY  iff qualify and post_mean >  1e-12
SELL iff qualify and post_mean < -1e-12
FLAT otherwise
```

The terminal sum after all twelve returns is identically zero and is not a
candidate split. Every close, logarithm, return, sum, mean, path value, and
post mean must be finite. A zero path, tied maximum, edge maximum, zero post
mean, malformed endpoint, or arithmetic failure consumes the month flat.

### Entry

- Reject an owned position or a same-magic entry deal already present for the
  current normalized broker month.
- Both news axes and legacy news mode are OFF. Friday close is OFF.
- Reject crossed or negative quotes and a genuinely positive spread above
  1,500 points. A modeled zero `.DWX` spread remains valid.
- Require a valid completed-bar `ATR(20,D1)`, valid point/tick metadata, and a
  normalized stop distance of `3.5 * ATR`.
- Submit at most one market position with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one frozen broker hard stop, and no
  take-profit. Signal strength and split position never scale risk.

### Exit and management

- Repair malformed owned exposure before entry-only gates: duplicates, wrong
  symbol/magic, invalid volume, missing stop, or invalid open time close.
- Close on the first tick whose normalized broker month differs from the entry
  month.
- Close after forty elapsed calendar days as stale repair.
- There is no target, trail, break-even, partial close, opposite-signal exit,
  same-month re-entry, grid, martingale, scale-in, or pyramid.

## Parameters to test

Q02 uses one locked baseline and no optimization surface:

| parameter | default | Q02 status | role |
|---|---:|---|---|
| `strategy_month_returns` | 12 | locked | adjacent completed monthly log returns |
| `strategy_min_split` | 4 | locked | minimum old-segment return count |
| `strategy_max_split` | 8 | locked | maximum old-segment return count |
| `strategy_tie_epsilon` | `1e-12` | locked | path-maximum and zero-side tolerance |
| `strategy_history_bars` | 900 | locked | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | locked | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked | newest completed endpoint age ceiling |
| `strategy_atr_period` | 20 | locked | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen broker hard-stop multiple |
| `strategy_stale_days` | 40 | locked | survivor repair |
| `strategy_max_spread_points` | 1500 | locked | entry execution ceiling |

Changing the return count, centering, candidate splits, uniqueness rule,
tolerance, post-mean side, risk, or hold after observing Q02 is forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_METHOD_ACCESS_BOUNDARY | One durable source ID; full WTI paper record; Page metadata; complete NIST method page; explicit untested translation. |
| R2 | PASS | Clock, data, formula, ties, split, side, attempt, risk, stop, spread, and exits are exact. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native WTI D1 and MT5 state only; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native arithmetic only; no ML, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- WTI gaps, continuous-CFD roll/basis, financing, return-magnitude sensitivity,
  small-sample split instability, and month-label offsets are material risks.
- Retire on zero positions, fewer than five completed positions in any full
  post-warm-up year, nonpositive governed economics, or a failed deterministic
  fixture.
- Fail on current-month leakage, missing/duplicate months, wrong return order,
  wrong mean, omitted split, inclusion of terminal zero, tied-maximum entry,
  edge-split entry, wrong post-mean side, missing stop, wrong risk mode,
  same-month retry, or nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot, locked inputs, fixed-risk mode,
  month-grace, persistent attempt, endpoint integrity, signal integrity,
  position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached post-segment direction, one fixed-risk WTI order, frozen
  ATR hard stop, no target.
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
| v1 | 2026-08-31 | initial centered-CUSUM WTI return-regime shift card | G0 | APPROVED; build pending |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-31 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
