---
card_schema_version: 2
type: strategy
strategy_id: URIGUEN-MOP-WTI-SPECENT-20260902_S01
variant_id: URIGUEN-MOP-WTI-SPECENT-20260902_S01
source_id: URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902
ea_id: QM5_41312
slug: wti-mspectral-entropy-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41312_wti-mspectral-entropy-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41312_wti_monthly_spectral_entropy_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_spectral_entropy_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Jose Antonio Uriguen; Begona Garcia-Zapirain; Julio Artieda; Jorge Iriarte; Miguel Valencia; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "QuantMechanica governed WTI spectral-entropy synthesis; Uriguen et al. (2017), PLOS ONE 12(9), DOI 10.1371/journal.pone.0184044; SciPy 1.17.1 tagged periodogram source; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_statistical_method
    citation: "Uriguen, J. A., Garcia-Zapirain, B., Artieda, J., Iriarte, J., and Valencia, M. (2017). Comparison of background EEG activity of different groups of patients with idiopathic epilepsy using Shannon spectral entropy and cluster-based permutation statistical testing. PLOS ONE 12(9), e0184044."
    location: "DOI 10.1371/journal.pone.0184044; complete open-access article read via PubMed Central PMC5602520"
    quality_tier: A
    role: normalized_power_spectral_entropy_formula_and_complexity_interpretation
  - type: transparent_statistical_implementation
    citation: "SciPy 1.17.1, scipy.signal.periodogram and _spectral_helper, tagged source."
    location: "https://raw.githubusercontent.com/scipy/scipy/v1.17.1/scipy/signal/_spectral_py.py; SHA-256 9C1FA9FA599CE670EBE91617CE43D11229A9D95F4B7ADCBFD675BB2A44EB408E"
    quality_tier: A_method_implementation
    role: constant_detrending_one_sided_power_and_nyquist_weighting_semantics
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: governed_composite_source
    citation: "QuantMechanica (2026). WTI monthly spectral-entropy-gated trend."
    location: strategy-seeds/sources/URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902/source.md
    quality_tier: governed_source
    role: exact_conjunction_threshold_risk_attempt_and_lifecycle
strategy_mechanic: monthly-wti-forty-eight-completed-log-returns-demeaned-length48-one-sided-nondc-dft-power-normalized-spectral-entropy-inclusive-088-gated-newest-twelve-month-continuation
sources:
  - "[[sources/URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/spectral-entropy]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/spectral-entropy]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, spectral-entropy, discrete-fourier-transform, frequency-domain, complexity-gate, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413120000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately seven completed WTI positions per full post-warm-up year; one consumed attempt per broker month. A fixed-seed market-free null prior qualified 59.188%. Q02 must prove at least five trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_BOUNDARY
r1_reasoning: "Complete peer-reviewed open-access spectral-entropy method article, pinned official tagged periodogram source, complete governed peer-reviewed WTI trading-paper read, and explicit disclosure that the exact conjunction is untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, 49 endpoints, 48 returns, demeaning, exact length-48 DFT, bins 1-24, paired and Nyquist weights, unit power normalization, normalized entropy, inclusive 0.88 gate, newest-12m direction, consumed attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed prices, timestamps, logarithms, sums, deterministic trigonometry, bounded DFT loops, ATR risk, quotes, positions, deals, and persistent state; no trained output or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 49 consecutive completed month-end closes; 48 adjacent log returns; subtract arithmetic mean; length-48 DFT with no taper/padding; one-sided non-DC bins k=1..24; double squared magnitude for paired k=1..23; do not double Nyquist k=24; normalize 24 powers; Hspec=-sum(p*ln(p))/ln(24), zero-bin term zero; total-power floor 1e-24; probability-sum tolerance 1e-10; entropy range tolerance [-1e-12,1+1e-10]; inclusive Hspec ceiling 0.88; newest 12m direction epsilon 1e-12; 1500 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly spectral-entropy-gated continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, demeaning, DFT orientation/bins, paired/Nyquist power, normalization, exact entropy and inclusive boundary, newest-12m side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, forty_nine_consecutive_completed_months, no_current_month_price, forty_eight_adjacent_log_returns, chronological_return_orientation, exact_demeaning, length48_dft, one_sided_nondc_bins, paired_power_doubling, nyquist_not_doubled, unit_power_normalization, normalized_spectral_entropy, inclusive_entropy_088, newest_twelve_month_continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41312_wti_monthly_spectral_entropy_trend_g0.md: R1-R4 pass within disclosed synthesis and continuous-CFD risks. Corrected-root dedup returned CLEAN across 4,797 registry rows, 1,426 cards, and 45 Wiki nodes; manual review separates global frequency-power concentration from ordinal entropy, LZ76, von Neumann ratio, sample entropy, intraday Shannon entropy, pure momentum, variance-ratio, sign, regression, distribution, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41312 WTI Monthly Spectral-Entropy-Gated Trend

## Hypothesis

WTI carries physical supply, storage, transport, refining, geopolitical,
hedging, and demand risks absent from the certified XAU, SP500, NDX, and XNG
carrier set. When forty-eight completed monthly WTI returns concentrate more
of their demeaned power in fewer frequencies, the newest twelve-month
direction may persist for one more broker month.

This is a falsifiable direct-crude structural trend sleeve. It is not evidence
of profitability, predictability, significance, independence, periodicity, or
decorrelation. Q02 owns cadence and baseline economics; unchanged Q09 alone
owns portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902/source.md`,
SHA-256
`B0FBB9993C5FE3BF6643EC13E96AEBCDD669CA077D1A2A8A2677D65CAABE4514`,
approved at commit `a31de65127` before card extraction.

Uriguen et al. fix entropy over normalized spectral power and the zero-power
term. Tagged SciPy source pins constant detrending and the one-sided paired
versus Nyquist convention. Moskowitz, Ooi, and Pedersen supply only the WTI
carrier and monthly own-return continuation lineage. None tests this
conjunction, window, threshold, CFD, fixed risk, costs, lifecycle, activity,
or portfolio fit.

## Non-Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_wti_mspecent_tr_preallocation_dedup_20260902.json`, SHA-256
`5CC47A1D3CDDC1C1BE9F706D0D368666D44B635D9380D05CE51D071578BCF7E8`,
returned `CLEAN` across 4,797 registry rows, 1,426 cards, and all 45 Strategy
Wiki nodes.

- `QM5_41308` counts six rank-order labels from disjoint triples. It has no
  DFT or spectral powers.
- `QM5_41309` parses a twenty-bit sign word into LZ76 phrases. It discards
  magnitude and has no frequency distribution.
- `QM5_41310` compares squared adjacent changes with total dispersion. It has
  no entropy sum across DFT bins.
- `QM5_41311` counts local raw-magnitude template matches. It has no global
  frequency transform.
- `QM5_9520` trades intraday ternary Shannon-state crossings, not monthly WTI
  spectral entropy.
- Pure trend, variance-ratio, sign-run/count, rank, regression, location,
  scale, distribution-shift, calendar, event, and channel EAs use different
  state objects. Certified `QM5_12567` is a two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_ONESIDED_DFT_SPECENT_LE088_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and slot zero: `XTIUSD.DWX`, D1, governed magic `413120000`.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the host D1 boundary.
- Formation: forty-nine consecutive completed broker-month-end closes;
  current-month prices are excluded.
- Hold: next broker month, with forty-calendar-day stale repair.
- Expected cadence: approximately seven completed positions/year. Q02
  retires any full scored post-warm-up year below five.

## Exact Formula

For chronological completed-month closes `C[0..48]`:

```text
x[i] = ln(C[i+1] / C[i]), i=0..47
mean = sum(x[i]) / 48
y[i] = x[i] - mean
```

For one-sided non-DC DFT bins `k=1..24`:

```text
Re[k] = sum(y[i]*cos(2*pi*k*i/48), i=0..47)
Im[k] = -sum(y[i]*sin(2*pi*k*i/48), i=0..47)
raw[k] = Re[k]^2 + Im[k]^2
power[k] = 2*raw[k] for k=1..23
power[24] = raw[24]
total = sum(power[1..24])
p[k] = power[k]/total
Hspec = -sum(p[k]*ln(p[k]), p[k]>0)/ln(24)
mom12 = sum(x[36..47])

BUY  iff Hspec <= 0.88 and mom12 > +1e-12
SELL iff Hspec <= 0.88 and mom12 < -1e-12
FLAT otherwise
```

Require finite arithmetic, `total>1e-24`, unit probability sum within
`1e-10`, and entropy in `[-1e-12,1+1e-10]`. Clamp only admitted floating
roundoff to `[0,1]`. Nyquist bin 24 is never doubled. Entropy and momentum
magnitude never alter risk.

## Rules

- Consume the normalized broker month before history, signal, news, spread,
  quote, ATR, sizing, margin, or order gates. Never retry that month.
- Select the latest close in each immediately prior consecutive broker month
  from a bounded 1,500-D1 buffer.
- Reject current-month input, missing/duplicate/nonconsecutive month keys,
  nonchronological endpoints, nonpositive closes, a stale newest endpoint,
  invalid returns/DFT/powers/probabilities/entropy, high entropy, or neutral
  momentum.
- Permit neither foreign `XTIUSD.DWX` exposure nor existing owned exposure.
- Both news axes, legacy news, Friday close, and stress rejection are OFF.
- Q02 has one locked baseline and no optimization surface.

## 4. Entry Rules

1. Require EA ID 41312, exact `XTIUSD.DWX` D1, slot zero, magic 413120000,
   fixed-risk mode, framework defaults, and every strategy input locked.
2. Run lifecycle repair before entry-only gates.
3. Require a genuine new broker month inside the 180-minute entry window.
4. Persist the month attempt before every fallible gate.
5. Reconstruct the exact endpoints and chronological log returns.
6. Apply exact demeaning, DFT angle/sign, bins, paired/Nyquist power weights,
   unit normalization, entropy sum, inclusive `0.88` gate, and newest twelve-
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
  demeaning, DFT component, power, total, probability sum, entropy, high
  entropy, neutral momentum, prior attempt/deal, spread, quote, ATR, sizing,
  or margin.
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
| completed month-end closes / returns | 49 / 48 |
| detrending | subtract 48-return arithmetic mean |
| transform | length-48 DFT, no taper, no padding |
| frequency bins | one-sided non-DC `k=1..24` |
| paired-bin power | `2*(Re^2+Im^2)`, `k=1..23` |
| Nyquist-bin power | `Re^2+Im^2`, `k=24` |
| normalization | 24 powers divided by total |
| spectral entropy | `-sum(p*ln(p))/ln(24)` |
| total / probability tolerances | `>1e-24` / `1e-10` |
| entropy tolerance / ceiling | `[-1e-12,1+1e-10]` / inclusive `0.88` |
| direction | newest 12-month log-return sign |
| direction epsilon | `1e-12` |
| D1 history buffer | 1,500 bars |
| entry grace / endpoint staleness | 180 minutes / 10 days |
| ATR stop / stale hold | `3.5*ATR(20,D1)` / 40 days |
| spread ceiling | 1,500 points |

Changing any value creates a new variant and requires fresh evidence.

## Expected Behavior And Frequency

The fixed-seed market-free receipt, SHA-256
`1C364172B3F4E9EE4FDC0AD882160E7C7D4F14B37FDE0E8C29F6B70EA820CE60`,
qualifies 59,188 of 100,000 independent standard-normal paths, or `7.10256`
states per twelve clocks. This is a cadence sanity check only, not WTI
evidence. Direction ties are probability zero in that continuous null but
still fail closed in runtime.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The broker stop is frozen at `3.5*ATR(20,D1)` and no
take-profit is attached. Gaps can exceed modeled stop risk. WTI's continuous
CFD adds roll, basis, financing, and broker-session risks. Short spectral
samples are noisy and the DFT assumes evenly spaced broker-month observations;
roll discontinuities can redistribute power. Live risk is not authorized.

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
  the forty-nine-month formation where the custom archive permits it.
- MT5-native history/execution state only; no external API, file, future bar,
  trained artifact, inventory series, or curve data.

## Reputable-Source Gate Findings

- R1: PASS with complete peer-reviewed method evidence, pinned official
  implementation semantics, complete governed WTI trading-paper evidence,
  and an explicit synthesis boundary.
- R2: PASS with exact deterministic signal, risk, and lifecycle rules.
- R3: PASS on registered native WTI D1, with explicit CFD transport risks.
- R4: PASS with bounded deterministic native arithmetic.

## Failure Modes And Kill Criteria

Retire or fail closed on formula/fixture mismatch, wrong return orientation,
wrong DFT sign or bin range, wrong paired/Nyquist weighting, power or
probability error, entropy/log/boundary error, zero positions, fewer than five
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
carrier. The spectral state is also mechanically distinct from existing WTI
time-domain complexity gates. This is a diversification hypothesis only. Q09
must measure realized correlation and may reject it without a waiver.

## Validation Plan

1. Reference-test endpoint/return orientation, demeaning, DFT components,
   one-sided weights, Parseval-consistent power, normalization, entropy,
   boundary, direction, and fixed fixtures against an independent transform.
2. Run card schema lint and strict Q01 compile/build checks.
3. Enqueue one canonical `RISK_FIXED` Q02 item only if CPU admission is clear.
4. Preserve any zero-trade, activity, or economic failure without changing
   the locked rule.

## Framework Alignment

| card rule | module |
|---|---|
| identity, risk/news/Friday contract, month attempt, endpoint and spectral state | `Strategy_NoTradeFilter` and bounded helpers |
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
| v1 | 2026-09-02 | initial WTI spectral-entropy trend card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_wti_monthly_spectral_entropy_trend_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41312_wti_monthly_spectral_entropy_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
