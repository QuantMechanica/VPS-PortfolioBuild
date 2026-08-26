# WTI Monthly Robust-Three Consensus Trend — Source Approval

Date: 2026-08-26

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Q02 enqueue does not authorize a manual tester
dispatch or work above the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits one new structural,
low-frequency `XTIUSD` edge, requires reputable-source criteria and
`RISK_FIXED` backtests, and forbids live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `wti-mrobust3-agree-tr`
- proposed strategy ID:
  `MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026_S01`
- proposed source ID:
  `MOP-THEILSEN-KOENKER-SIEGEL-WTI-MROBUST3-AGREE-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: follow WTI only when the Theil-Sen, least-absolute-deviation, and
  Siegel repeated-median slopes of the same thirteen completed month-end log
  prices have one unanimous strict sign

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md`, SHA-256
   `F83880B74B1DB645F6C20A58B76825DA96787E327C461D0E798CA01CAB72535E`.
   It preserves the complete-paper Moskowitz-Ooi-Pedersen time-series-
   momentum lineage, explicit NYMEX WTI membership, monthly renewal, exact
   thirteen-endpoint WTI carrier, and the pooled 78-slope Theil-Sen
   mechanization.
2. `strategy-seeds/sources/MOP-KOENKER-BASSETT-WTI-LAD-2026/source.md`,
   SHA-256
   `7F4630DCF4D10D2004F94FA098712810048E05F56A9E8EFF45F85079F3752D5A`.
   It preserves the complete-read peer-reviewed trading and quantile-
   regression lineage, the exact finite 78-breakpoint LAD reduction, median
   residual intercept, absolute-loss objective, and fixed tie convention.
3. `strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md`, SHA-256
   `199D39CB5ECAFC7B57F19BA7932DBEF6558529DD68AE00B66AD4531C7FA48E91`.
   It preserves the complete governed WTI packet and official Oxford
   Academic record for Andrew F. Siegel (1982), *Biometrika* 69(1), 242-244,
   DOI `10.1093/biomet/69.1.242`, plus exact nested-median arithmetic.

Moskowitz, Ooi, and Pedersen support a monthly own-price continuation test and
explicitly include WTI. The governed method records supply three different
robust slope functionals. No source tests their unanimous conjunction. The
consensus gate, continuous-CFD mapping, exact sample, fixed-dollar risk, stop,
attempt state, and lifecycle are disclosed QM hypotheses.

No source return, alpha, probability, Sharpe ratio, density, drawdown,
transaction cost, WTI-only result, CFD equivalence, estimator superiority,
decorrelation, or portfolio-correlation statistic transfers. No new online
route, blocked content, inferred table value, or ungoverned claim is used.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month after a flat signal, invalid state, reject, stop, or restart.
2. Exclude the current month. Reconstruct exactly thirteen consecutive
   completed broker calendar months ending with the immediately prior month.
   Retain the latest WTI D1 close in each month. Reject missing or duplicate
   months, nonchronological timestamps, nonpositive closes, or a newest
   endpoint more than ten calendar days stale.
3. In chronological order form `y[i]=ln(C[i])`, `i=0..12`, and enumerate all
   78 forward pair slopes `(y[j]-y[i])/(j-i)` for `0 <= i < j <= 12`.
4. Theil-Sen: sort all 78 slopes and average zero-based indexes 38 and 39.
5. LAD: for every one of the 78 slopes, take sorted residual index 6 as the
   intercept, sum thirteen absolute vertical residuals in chronological order,
   retain candidates within exactly `1e-12` of the minimum loss, sort the
   retained slopes, and take their ordinary median.
6. Repeated median: for each of thirteen pivots calculate the twelve forward-
   oriented slopes to every other endpoint, average sorted indexes 5 and 6,
   then sort the thirteen pivot medians and take index 6.
7. Buy only when all three final slopes are strictly positive. Sell only when
   all three are strictly negative. Any zero, disagreement, invalid count, or
   nonfinite value consumes the month flat. Slope magnitudes never change risk.
8. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen `3.5*ATR(20,D1)` broker
   hard stop. Attach no target and cap entry spread at 1,500 points.
9. Close on the first tick in a later broker month or after forty calendar
   days. Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   or stopless owned exposure.

Both news axes, the legacy news mode, and Friday close are OFF for the monthly
hold.

## Reputable-Source Criteria

- R1 `PASS_WITH_ENSEMBLE_TRANSLATION_RISK`: named-author peer-reviewed JFE
  trading evidence with complete-paper provenance and explicit WTI
  membership, complete-read peer-reviewed quantile-regression evidence, and
  an official peer-reviewed repeated-median method record. The conjunction is
  explicitly untested.
- R2 `PASS`: clock, month selection, logarithms, all 78 slopes, Theil-Sen
  indexes, LAD profiles/objectives/ties, repeated-median groups/indexes,
  unanimous signs, attempt, risk, stop, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1
  history plus native MT5 state supply every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic, sorting,
  absolute loss, comparisons, ATR risk controls, and execution state only; no
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,664 EA-registry rows, 1,315 card
files, and 45 Strategy Wiki nodes. It found no exact match and one expected
fuzzy match, the single-estimator `wti-theilsen-tr_card.md`, at score
`0.5833333333333334`. Evidence is
`artifacts/qm5_wti_mrobust3_agree_tr_preallocation_dedup_20260826.json`,
SHA-256
`469540A81B2615A7EAA97A071763BF72713D1B51B0934CEC02028F17D32F61F6`.

Manual functional review resolves the fuzzy family:

- `QM5_20271_wti-theilsen-tr` trades the pooled 78-slope median sign without
  computing LAD or repeated median.
- `QM5_41159_wti-lad-tr` minimizes thirteen-term absolute vertical loss and
  trades its minimizer sign without the other two gates.
- `QM5_41158_wti-repmedian-tr` trades the outer median of thirteen pivot-
  specific slope medians without the other two gates.
- On valid log-price levels
  `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen is
  `+0.00155555555555556`, LAD is `+0.00375`, and repeated median is `-0.0045`.
  The three existing systems take positions while this candidate consumes the
  month flat.
- On valid log-price levels
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
  `-0.002` while Theil-Sen and repeated median are positive. The candidate is
  again flat rather than aliasing any constituent.
- On `y[i]=0.01*i`, all three slopes equal `0.01` and the candidate buys, so
  the conjunction is executable rather than a permanently false filter.
- Return-sign votes, OLS, endpoint, adjacent-return, calendar, range, flow,
  and volatility systems aggregate different state objects. Certified
  `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG oscillator
  pullback with neither WTI exposure nor this monthly robust consensus.

Verdict: `CLEAN_AFTER_EXPECTED_THEILSEN_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Kill And Safety Boundary

The pre-result density prior is five to twelve completed WTI positions per
full post-warm-up year. This is not market evidence. Q02 must retire the
candidate below five completed positions in any full post-warm-up year, at
zero trades, with nonpositive governed economics, or on any month, slope,
objective, median, consensus, side, attempt, risk, lifecycle, or determinism
defect.

WTI is a direct crude-oil carrier absent from the current XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns the overlap verdict. No failed result may be rescued by changing the
sample, estimator, consensus rule, direction, risk, hold, or by adding an
endpoint, scale, event, seasonal, volatility, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
