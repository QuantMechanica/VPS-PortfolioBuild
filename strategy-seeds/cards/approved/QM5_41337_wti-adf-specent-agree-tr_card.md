---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905_S01
variant_id: AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905_S01
source_id: AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905
ea_id: QM5_41337
slug: wti-adf-specent-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41337_wti-adf-specent-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41337_wti_monthly_adf_spectral_entropy_agreement_trend_g0.md
source_approval: decisions/2026-09-05_wti_monthly_adf_spectral_entropy_agreement_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; Jose Antonio Uriguen; Begona Garcia-Zapirain; Julio Artieda; Jorge Iriarte; Miguel Valencia; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "OpenAI Codex (2026), WTI monthly ADF and spectral-entropy agreement trend; Chan (2013), Algorithmic Trading, Wiley; Uriguen et al. (2017), PLOS ONE 12(9), DOI 10.1371/journal.pone.0184044; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). WTI monthly ADF and spectral-entropy agreement trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905/source.md
    quality_tier: governed_source
    role: exact_conjunction_sample_threshold_risk_and_lifecycle
  - type: approved_adf_source
    citation: "Chan, E. P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md
    quality_tier: A
    role: lag_one_constant_no_time_trend_adf_arithmetic_and_boundary_orientation
  - type: peer_reviewed_spectral_entropy_source
    citation: "Uriguen, J. A. et al. (2017). PLOS ONE 12(9), e0184044."
    location: strategy-seeds/sources/URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902/source.md
    quality_tier: A
    role: normalized_power_spectral_entropy_and_periodogram_convention
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: strategy-seeds/sources/MOP-TSMOM-2012/source.md
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-lag-one-intercept-adf-t-at-least-minus2p594-and-newest-forty-eight-log-returns-demeaned-length48-spectral-entropy-at-most-0p88-agreement-gated-twelve-month-return-sign-continuation
sources:
  - "[[sources/AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/dual-domain-persistence-agreement]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-price]]"
  - "[[indicators/augmented-dickey-fuller-statistic]]"
  - "[[indicators/spectral-entropy]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, dual-domain-agreement, augmented-dickey-fuller, spectral-entropy, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413370000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately five to seven completed WTI positions per full post-warm-up year is an uncalibrated planning prior; one attempt is consumed per broker month and either state gate may consume a month flat. Q02 must prove at least five completed positions in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE
r1_reasoning: "Approved complete ADF, peer-reviewed spectral-entropy/transparent implementation, and peer-reviewed WTI continuation records with hashes, read scopes, and non-transfer boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, sixty endpoints, ADF path, newest forty-eight returns, exact DFT and entropy path, inclusive thresholds, conjunction, twelve-month side, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gaps, and broker-month labels remain material risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS, deterministic DFT/entropy arithmetic, comparisons, ATR risk, quotes, positions, deals, and persistent state are used."
parameters_to_test: "Locked Q02 baseline only: 60 consecutive completed month-end closes; log levels; ADF 58 observations, intercept, one lagged difference, 55 residual degrees of freedom, determinant relative floor 1e-12, inclusive adf_t >= -2.594; newest 48 adjacent log returns from levels 11..59; subtract mean; length-48 DFT with no taper/padding; bins 1..24, paired bins doubled and Nyquist undoubled; normalized entropy inclusive <=0.88; total-power floor 1e-24; probability tolerance 1e-10; entropy tolerance [-1e-12,1+1e-10]; newest 12-month direction epsilon 1e-12; 1800 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly ADF and spectral-entropy agreement trend outside the certified XAU/SP500/NDX/XNG book. Verify shared endpoints, ADF arithmetic, return slice, DFT bins and weights, entropy, both inclusive boundaries, disagreement abstention, twelve-month side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_consecutive_completed_months, no_current_month_price, chronological_log_levels, adf_lag_one_constant_no_time_trend, adf_residual_dof_55, inclusive_adf_boundary, newest_forty_eight_returns, exact_demeaning, length48_dft, paired_power_doubling, nyquist_not_doubled, normalized_spectral_entropy, inclusive_entropy_boundary, both_gates_required, twelve_month_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-05 and decisions/2026-09-05_qm5_41337_wti_monthly_adf_spectral_entropy_agreement_trend_g0.md: R1-R4 pass within disclosed statistical-synthesis and continuous-CFD risks. Corrected-root dedup found no exact identity across 4,817 registry rows and 1,436 cards; the external Wiki root was unavailable. Four expected fuzzy neighbors are manually resolved by non-equivalent ADF, spectral, KPSS, and Phillips-Perron state geometry. Fixed fixtures prove both one-gate disagreement directions and reject a prior ADF-KPSS qualifier for high entropy. This identity decision is not a correlation claim."
---

# QM5_41337 WTI Monthly ADF and Spectral-Entropy Agreement Trend

## Hypothesis

WTI supplies physical energy exposure through production, storage, transport,
refining, producer hedging, geopolitics, and end demand. Those drivers are
absent from the certified XAU/SP500/NDX/XNG book and differ from XNG weather
and storage sensitivity. The hypothesis is that a completed twelve-month WTI
move is suitable for one further broker month only when a lag-one ADF state
does not show strong error correction and the newest forty-eight monthly
returns exhibit concentrated, low-entropy frequency power.

The tests overlap and are not independent votes. Agreement does not prove a
unit root, periodicity, persistence, predictability, profit, or decorrelation.
Q02 owns cadence and economics; Q09 alone owns realized book overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905/source.md`,
approved and committed in `faea4503f7` before extraction. It binds complete
approved ADF, spectral-entropy, and WTI continuation records. The parents
define their methods separately. None validates this exact conjunction,
sample, thresholds, continuous CFD, costs, activity, or portfolio fit.

## Non-Duplicate Decision

The corrected-root receipt
`artifacts/qm5_wti_adf_specent_agree_tr_preallocation_dedup_20260905.json`
found no exact identity and returned four expected fuzzy family neighbors.

- `QM5_41319` admits ADF-qualified high-entropy paths.
- `QM5_41312` admits low-entropy paths even when ADF strongly rejects.
- `QM5_41336` requires KPSS rather than spectral entropy; the fixed random-
  walk fixture passes both ADF and KPSS but is rejected here at entropy
  `0.8845849634793777`.
- `QM5_41320` uses a lag-zero Phillips-Perron construction.

The fixture SHA-256 is
`B591901078B38B63168EEAC2D87AF3DF584944616464F297E83DAA68B1CD0FBC`.
Manual verdict:
`DISTINCT_PRICE_LEVEL_ERROR_CORRECTION_AND_FREQUENCY_POWER_CONJUNCTION`.
Shared WTI continuation can still correlate; Q09 receives no waiver.

## Markets, Timeframe, And Cadence

- Exact host/traded symbol: `XTIUSD.DWX`, D1, slot zero, intended magic
  `413370000` after deterministic allocation.
- Decide once on the first executable tick after a genuine broker-month
  transition, within 180 minutes of the raw D1 boundary.
- Formation: sixty consecutive completed broker-month-end closes; current-
  month prices are excluded.
- Hold through Friday until the next broker month; forty days is stale repair.
- Planning prior: five to seven completed positions/year. Q02 retires below
  five in any full post-warm-up scored year.

## Exact Formula

For chronological completed-month closes `C[0..59]`, set `x[t]=ln(C[t])`.

ADF for `t=2..59`:

```text
y[t]=x[t]-x[t-1]
z[t]=x[t-1]
w[t]=x[t-1]-x[t-2]
y=alpha+gamma*z+phi*w+error
adf_t=gamma/se_gamma
```

Fit centered OLS over 58 rows with residual variance `SSE/55`. Require the
governed energy and determinant floors. ADF qualifies inclusively at
`adf_t >= -2.594`.

For `i=0..47`, set `r[i]=x[12+i]-x[11+i]`, subtract the 48-return mean, and
compute the direct length-48 DFT. Use non-DC bins 1..24, double paired-bin
powers 1..23, leave Nyquist bin 24 undoubled, normalize the powers, and set:

```text
Hspec=-sum(p[k]*ln(p[k]))/ln(24)
```

Spectral state qualifies inclusively at `Hspec <= 0.88`.

```text
mom12=x[59]-x[47]
BUY  iff both gates qualify and mom12 > +1e-12
SELL iff both gates qualify and mom12 < -1e-12
FLAT otherwise
```

Only momentum sign chooses side. No statistic magnitude affects size.

## Rules

- Consume and persist the normalized broker month before history, signal,
  news, spread, quote, ATR, sizing, margin, or submission. Never retry.
- Select the latest close in each of the sixty immediately prior consecutive
  broker months from a bounded 1,800-D1 buffer.
- Fail closed on invalid endpoints, arithmetic, either state gate, or neutral
  momentum.
- Reject owned or foreign WTI exposure and an owned same-month entry deal.
- Both news axes, legacy news, Friday close, and stress are off.
- Q02 has one locked baseline and no optimization surface.

## Entry Rules

1. Require exact identity, `XTIUSD.DWX` D1, governed slot/magic, fixed-risk
   mode, and every locked input.
2. Process malformed-position and later-month/stale exits before entry gates.
3. Require a genuine new broker month inside the entry grace window.
4. Persist the attempt before every fallible gate.
5. Reconstruct sixty completed endpoints once; feed all levels to ADF and
   the exact newest return slice to spectral entropy.
6. Require both inclusive gates and a strict twelve-month side.
7. Require spread in `[0,1500]`, quotes, completed D1 ATR(20), valid metadata,
   positive fixed-risk sizing, and margin.
8. Open at most one position with a frozen `3.5*ATR` hard stop and no target.

## Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later normalized broker month.
3. Close after forty elapsed calendar days as stale repair.
4. Close duplicate, wrong-symbol/magic/side, invalid-time/volume, missing-stop,
   or inconsistent persisted-state exposure immediately.
5. No intramonth state exit or flip, target, trail, break-even, partial close,
   retry, scale-in, grid, martingale, or pyramid.

## Filters And Trade Management

Fail closed outside the exact host, identity, risk/news/Friday/stress and
locked-input contract. Lifecycle repair runs before entry-only gates on every
tick. Runtime may not read curves, inventory, volume, open interest, files,
APIs, forecasts, optimizer output, portfolio state, or trained artifacts.

## Parameters To Test

Q02 has exactly one baseline: 60 completed log endpoints; lag-one intercept
ADF with 58 rows, 55 residual degrees of freedom, determinant and energy
floors, inclusive `-2.594`; newest 48 returns; exact demeaned length-48
one-sided DFT; paired/Nyquist weighting; normalized spectral entropy inclusive
`0.88`; 12-month sign with `1e-12` epsilon; 1,800 bars; 180-minute grace;
10-day endpoint staleness; `3.5*ATR(20,D1)` stop; 40-day stale hold; and
1,500-point spread ceiling. Any change creates a new identity.

## Risk

- Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- One position has one frozen `3.5*ATR(20,D1)` hard stop and no target.
- Gaps can exceed modeled risk. The continuous CFD adds roll, basis,
  financing, spread, and broker-session risk.
- Small-sample ADF size, spectral leakage, fixed bins/thresholds, overlapping
  windows, and shared WTI momentum can invalidate the hypothesis.
- No live risk mode or live artifact is authorized.

## Data Requirements

Native `XTIUSD.DWX` D1 timestamps/closes and ATR, broker time/month, quotes,
symbol metadata, margin, positions, deals, and terminal-global state only.

## Framework Alignment

| card rule | module |
|---|---|
| identity, fixed contract, month attempt, endpoint reconstruction, both state paths | `Strategy_NoTradeFilter` and bounded helpers |
| conjunction, momentum side, spread, ATR, hard stop, one order | `Strategy_EntrySignal` |
| integrity repair, next-month and forty-day closure | `Strategy_ManageOpenPosition` |
| framework reason mapping | `Strategy_ExitSignal` and close helper |
| news disabled on both axes | `Strategy_NewsFilterHook` |

## Validation Plan

1. Match the fixed up, down, ADF-only/high-entropy, and spectral-only/ADF-
   reject fixtures with an independent reference implementation.
2. Verify the prior ADF-KPSS qualifier is rejected here for high entropy.
3. Verify endpoint ordering, no current-month leakage, exact regression and
   DFT bounds, inclusive thresholds, fixed risk, and lifecycle.
4. Run card lint, spec validation, reference tests, and strict Q01.
5. Enqueue exactly one fixed-risk Q02 item only after compile PASS and a fresh
   CPU window below the ceiling; never launch a tester manually.

## Failure Conditions And Safety Boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, formula/fixture mismatch, leakage, nonpositive governed
economics, invalid risk, missing stop, lifecycle defect, nondeterminism, or
downstream hard failure. Preserve failures without tuning.

Authorized: deterministic identity/magic allocation, branch-only non-live
build, reference tests, strict Q01, one fixed-risk set, and one paced Q02
enqueue below the CPU ceiling. Forbidden: optimization, manual backtests,
live/demo/shadow/stress sets, portfolio-gate edits, correlation waivers,
portfolio admission, deploy/live manifests, `T_Live`, AutoTrading, terminal
control, or live use.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial WTI ADF and spectral-entropy agreement card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-05 | APPROVED_SOURCE | `decisions/2026-09-05_wti_monthly_adf_spectral_entropy_agreement_trend_source_approval.md` |
| G0 Research Intake | 2026-09-05 | APPROVED | `decisions/2026-09-05_qm5_41337_wti_monthly_adf_spectral_entropy_agreement_trend_g0.md` |
| Q01 Build & Spec | TBD | PENDING | TBD |
| Q02 Baseline | TBD | NOT_ENQUEUED | TBD |
