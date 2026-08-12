# FTMO Joint-MAE Book Progress - 2026-07-12

## Status

**RESEARCH ONLY / NO GO.** The requested `>=80%` FTMO Phase-1 pass rate within
30 calendar days has not been demonstrated. The best locked, sealed result is
currently **69.9001%** in the threshold reconstruction and **59.3438%** in the
adverse reconstruction. No paid-challenge or live deployment is authorized by
this document.

The objective contract is FTMO 2-Step Phase 1: `+10%` profit target, `5%`
Maximum Daily Loss, `10%` Maximum Loss, at least four trading days, and no
external time limit. Thirty calendar days are an internal speed target. These
rules were revalidated on 2026-07-12 against the
[official FTMO Trading Objectives](https://ftmo.com/en/trading-objectives/).

## Current Research Anchor

The selected research scenario is `path_01_11095_gbpusd_down2` in
`artifacts/ftmo_joint_eleven_sleeve_incumbent_weight_path_manifest_2026-07-12.json`.
Its locked governor policy is:

- nominal risk multiplier: `25.0`
- daily entry stop: `4500`
- full-risk room: `4000`
- room retention: `0.20`
- profit-risk ladder: none
- candidate selection: development/training data only
- sealed evaluation: 2024-2025 only, opened once at the locked 5% candidate weight

Risk-neutral sleeve weights sum to one:

| EA | Symbol | Weight |
|---:|---|---:|
| 10440 | NDX.DWX | 11.103705% |
| 12969 | USDJPY.DWX | 12.992091% |
| 12990 | GBPUSD.DWX | 11.405847% |
| 10377 | XAUUSD.DWX | 15.786901% |
| 10558 | EURUSD.DWX | 14.125122% |
| 11095 | GBPUSD.DWX | 7.901941% |
| 10715 | USDJPY.DWX | 2.336147% |
| 10286 | XTIUSD.DWX | 8.652395% |
| 10375 | NDX.DWX | 9.613773% |
| 11708 | EURUSD.DWX | 0.971088% |
| 1142 | USDJPY.DWX | 5.110990% |

Several sleeves are admitted only to a research reconstruction despite weak or
failed individual pipeline gates. This is not a deployable manifest.

## Locked Sealed Result

Both evaluations contain 701 rolling 30-day start windows from 2024-2025.

| Reconstruction | Prior eleven-sleeve anchor | Selected reweight | Delta | Selected 95% CI |
|---|---:|---:|---:|---:|
| Threshold / report-reconciled MAE | 67.0471% | **69.9001%** | +2.8531 pp | 66.4037-73.1797% |
| Adverse execution / MAE | 56.6334% | **59.3438%** | +2.7104 pp | 55.6663-62.9194% |

Threshold outcomes for the selected reweight: 0% daily breach, 0% maximum-loss
breach, and 30.0999% target not reached. Adverse outcomes: 20.1141% daily
breach, 10.9843% maximum-loss breach, and 9.5578% target not reached. These are
historical rolling-window reconstructions, not independent Bernoulli trials and
not a promise of future challenge results.

The reweight was selected on development data only. A one-factor screen found
that reducing `QM5_11095 GBPUSD` by two absolute percentage points improved
normal training from 54.6689% to 56.7063% and adverse training from 46.1800% to
49.2926%. A predeclared second coordinate-descent pass found no further change
that improved both models. The risk-multiplier fine grid from 20 through 28
also retained 25; no alternative improved both training reconstructions.

## New Sleeve Evidence

`QM5_1142` on `USDJPY.DWX M30` was rerun from 2017-2025 twice under native MT5
Model 4 with identical output: 1,662 trades, native PF 1.26, net profit
278,833.13, and maximal equity drawdown 39,593.41 on the research account
scale. The exported joint-MAE stream reconciles exactly to the report after
the declared duplicate-closing-commission adjustment.

Current FTMO cost reconstruction produces PF 1.262332 and net profit
278,745.20. Annual FTMO-cost results are positive in 2017-2022 and 2024-2025;
2023 is slightly negative. Frozen cross-symbol tests on EURUSD, GBPUSD, and
USDCAD were all materially loss-making, so the mechanism is treated as
USDJPY-specific rather than a reusable family.

Primary evidence:

- `artifacts/ftmo_1142_usdjpy_fresh_stream_reconciliation_2026-07-12.json`
- `artifacts/ftmo_1142_usdjpy_current_report_cost_reconciliation_2026-07-12.json`
- `artifacts/ftmo_bar_governor_1142_locked_sealed_holdout_threshold_2026-07-12.json`
- `artifacts/ftmo_bar_governor_1142_locked_sealed_holdout_adverse_2026-07-12.json`

## Falsified Paths

- `QM5_10814 USDJPY H1`: fresh deterministic PF 1.21, but current FTMO-cost PF
  1.177779 failed the strict Q02 threshold. Raw, Asia-only, 20-day-trend, and
  causal long-horizon filters failed the predeclared robust-improvement hurdle.
- `QM5_11886 USDJPY M5`: corrected native invocation produced 143 trades, PF
  0.27, -94,083.10 net profit, and 94.43% drawdown. Rejected immediately.
- `QM5_10163`: volatility-active variants did not improve both normal and
  adverse training objectives. The holdout remained sealed.
- Launch-gate and same-year shadow-trade filters produced no pre-holdout
  survivor. The holdout remained sealed.
- `QM5_1142` cross-symbol cohort: EURUSD PF 0.79, GBPUSD PF 0.86, USDCAD PF
  0.81. No additional symbol sleeve or magic allocation was made.
- NDX 2020 joint-bar export was unavailable from terminal history. No proxy or
  synthetic bar series was substituted; sealed evaluation remains 2024-2025.
- `QM5_12971 SP500 H1` exposed and repaired a stale canonical binary. The fresh
  V2 build produced two identical 56-trade runs and exact MAE reconciliation.
  At 1% it improved the old anchor holdout to 67.3324% normal and 57.2040%
  adverse, but its interaction with the selected reweight failed adverse
  training (48.2739% versus 49.2926%). It remains a separate reserve, not part
  of the selected book.
- `QM5_10916 GDAXI H1` passed current-cost Q02 and a causal 20-day fade filter,
  but the locked 1% portfolio holdout fell to 66.1912% normal. Rejected despite
  an adverse improvement.
- `QM5_10118 NDX H1`: 716 deterministic trades, current FTMO-cost PF 1.015658.
  `QM5_9267 GBPJPY H4`: 632 deterministic trades, current FTMO-cost PF
  1.048126. Both failed before portfolio admission.
- `QM5_10672 NDX M15`: three infrastructure-invalid runs followed by one valid
  full-history run with 4,821 trades, PF 0.98, -24,665.15 net and 76.29%
  drawdown. The short-window archive result was falsified.
- `QM5_13137`, `QM5_10939`, and `QM5_9929` all produced fresh deterministic,
  report-reconciled streams and positive current-cost standalone PFs. None had
  a weight that improved both normal and adverse training against the selected
  reweight, so their portfolio holdouts remained closed.
- `QM5_11132 SP500 D1` produced 73 deterministic trades and current-cost PF
  1.571203, but 2023 was negative and no causal filter survived the pre-holdout
  gate. It was stopped before portfolio testing.
- The sealed USDJPY broker-clock range screen evaluated 21 configurations over
  608,798 native M5 bars. No configuration passed the development plus 2023
  validation gate, so 2024-2025 was never opened.
- `QM5_10692 NDX H1` produced two identical 676-trade reports and an exact MAE
  stream. Current FTMO costs reduced pooled PF to 1.128409, but the causally
  selected `trend_consensus_align` rule survived its standalone holdout at PF
  1.319732 over 106 trades. A predeclared 3% weight improved both development
  reconstructions, then failed the one-time portfolio holdout: normal fell from
  69.9001% to 68.9016% and adverse from 59.3438% to 56.2054%. Subsequent
  training-only NDX substitution probes found no setting that improved both
  models, so no further holdout was opened.
- `QM5_10706 GBPUSD H1` repaired the prior stale-stream result and now has two
  identical 367-trade reports, exact stream reconciliation, and current-cost PF
  1.324531. No causal filter survived. Every raw marginal weight from 0.5% to
  10% worsened at least one development reconstruction; portfolio holdout was
  not opened.
- `QM5_11891 GBPJPY D1` produced two identical 402-trade reports and exact MAE
  reconciliation. GBPJPY commission and multi-day swaps reduced pooled PF from
  1.385502 to 1.300830, while both 2024 and 2025 became loss-making. No causal
  filter survived, so the sleeve was rejected before portfolio admission.
- `QM5_2012 GBPUSD H4` produced two identical 383-trade reports and an exact
  stream. Current FTMO costs reduced PF to 1.154952; 2024 and 2025 were both
  slightly negative and no causal filter survived.
- `QM5_10804 USDJPY H1` produced 664 deterministic trades and current-cost PF
  1.226341. Its selected `us_only` filter failed standalone holdout, and every
  raw portfolio weight worsened the adverse development reconstruction.
- `QM5_10815 GDAXI H1` completed two identical post-framework-fix reports with
  79 trades, native PF 2.13, exact MAE reconciliation, and current-cost PF
  2.146181. It failed the annual-density gate, no causal filter survived, and
  every portfolio weight worsened adverse development.
- `QM5_12484 USDJPY H1` produced 530 deterministic trades and current-cost PF
  1.214290. Its card/set D1-versus-H1 lineage conflict remains explicit. No
  filter survived and no raw weight improved both development models.
- `QM5_13202 WS30 M15` now has two deterministic current reports and an exact
  368-trade stream at native `RISK_FIXED=100`, normalized by a tested factor of
  ten. Current-cost PF is 1.231471. The causal `trend_20d_align` rule passed its
  standalone holdout, but even 0.5% portfolio weight reduced adverse training.
- A proportional aggregate-open-risk cap was implemented with a zero-cap
  regression that exactly reproduced 56.706282% normal and 49.292586% adverse
  training. Cap factor 4 left normal unchanged and improved adverse to
  49.632145%; it did not satisfy the predeclared strict improvement in both.
  A bounded cap/risk Stage-2 grid also found no joint improvement.
- A 28-rule ex-ante calendar launch screen selected February without reading
  2024-2025 (development 75.00%/72.32%, 2023 validation 71.43%/71.43%). Its
  one-time sealed evaluation failed at 66.67% normal and 63.16% adverse over 57
  eligible starts. Other months remained closed.
- A separate 30-rule pre-launch market-regime family used only completed bars
  before challenge start. No development-plus-2023 survivor was found, so its
  holdout remained closed.
- A full leave-one-out screen found no incumbent whose complete removal
  improved both models. Dropping `11095` raised normal to 57.05% but reduced
  adverse to 47.37%; dropping `11708` produced the opposite trade-off at
  56.42%/49.58%.
- `QM5_11128 SP500 D1` was recovered after a sibling wrapper failure from two
  reports with identical metrics and exact round-trip sequences. Its current
  FTMO PF is 1.237767, but every 0.5%-10% weight worsened at least one training
  model. `QM5_12361 WS30 D1` fell to current-cost PF 1.165026 and was rejected.
  `QM5_11128 NDX D1` remains infrastructure-blocked. T4 produced one valid
  current-framework 163-trade report. The byte-identical standard binary on T2
  instead returned a cached 146-trade legacy report and only 75 legacy Q08
  rows without entry time or MAE. A byte-identical uniquely named binary on T3
  produced three `M0/1970` reports after explicit NDX history synchronization
  errors. These three mutually incompatible program/history-cache outcomes do
  not support a strategy verdict.
- A predeclared 60-candidate causal launch-model family used only shadow-book,
  market, and calendar information available before each challenge start. The
  frozen `ridge_10_joint_top_0.15` winner passed development and 2023 validation,
  then failed its one-time 2024-2025 holdout at 67.4556% normal and 59.7633%
  adverse over 169 eligible starts. No model substitution or post-holdout
  threshold change was made.
- Tighter internal daily stops all reduced normal development pass rate: the
  best tighter value, 4,250, scored 54.8387% versus 56.7063% at 4,500. The
  adverse and holdout stages therefore remained closed. A separate
  loss-sensitive throttle family, normalized to the same initial risk, also
  failed normal development; pass rate declined as low as 49.3492%.
- A causal deadline accelerator produced one joint development survivor by
  retaining risk 25 through day 19 and using risk 35 from day 20. Its locked
  holdout left normal unchanged at 69.9001% and reduced adverse pass rate to
  59.2011%, so the constant-risk incumbent remains selected.
- A predeclared ten-policy anti-martingale screen started below or at risk 25
  and increased risk only after fixed realized-profit thresholds. An initial
  shard set was explicitly invalidated because 2026 was omitted from the
  excluded-year list; the unchanged grid was rerun with only 2018, 2019, 2021,
  and 2022 eligible. No policy improved both fills. The closest, `pf22_a`,
  scored 57.3466% normal and 49.3581% adverse versus fixed-25 controls of
  59.0585% and 51.3552%. Validation and sealed years remained closed.
- `QM5_11124 SP500 D1` produced two identical fresh 72-trade reports and an
  exact MAE stream. The current binary achieved native PF 1.07; current FTMO
  costs raised PF only to 1.130031, below the strict 1.20 research gate. The
  older archive PF was not carried forward.
- A separate nine-policy early-risk-burst family raised risk only for the first
  5, 7, or 10 calendar days and then reverted to 25. Every candidate failed the
  stronger predeclared normal-development hurdle; the best scored 54.7821%
  versus 56.7063% for the incumbent. Adverse and holdout stages stayed closed.
- `QM5_10513 XAUUSD D1` produced two identical 76-trade reports and an exact
  MAE stream. Current FTMO costs reduce native PF 1.456990 to 1.288812, but the
  strict Q02 density gate fails because 2018 has only four trades and is
  loss-making. It did not enter a portfolio screen.
- `QM5_10940 XAUUSD H4` produced two identical 51-trade reports and an exact
  MAE stream. Current FTMO costs reduce native PF 1.526458 to 1.368689. The
  strict Q02 density and annual-quality gate still fails: 2018 has only four
  losing trades, and 2019, 2020, 2022, and 2025 are also loss-making. It did
  not enter a portfolio screen.
- The predeclared all-sleeve causal-regime application used the nine rules
  selected on development plus 2023 validation and kept every incumbent
  weight unchanged. Normal development pass rate fell to 45.0481% from
  56.7063%, mainly because accepted-entry density collapsed. The adverse and
  sealed portfolio stages remained closed.
- `QM5_1556 XAUUSD D1` failed the cross-terminal deterministic admission
  contract. The first T3 report contained no XAU round trips, the second
  contained 53 trades at PF 1.93, and an independent current-framework T4 run
  contained 64 trades at PF 1.99. A cache-cold, uniquely named compile of the
  current source then reproduced the exact 53-trade T3 sequence, including its
  round-trip digest, while still disagreeing with T4 by 11 trades. The 53-row
  MAE stream reconciles to its own T3 report, but no stream, cost result, or
  portfolio result was admitted across the unresolved terminal divergence.
- `QM5_10410 GDAXI H1` falsified its old short-window archive result on a
  fresh full-history run. Two identical reports contain 2,283 trades, native
  PF 0.887699, -95,829.65 net profit, and 96.52% reported equity drawdown. The
  2,283-row MAE stream reconciles exactly; current FTMO costs leave PF at only
  0.889309. It was rejected before any portfolio screen.
- `QM5_10816 GDAXI H1` also failed to carry its old 2024 result into the full
  history. Two identical current-framework reports contain 1,926 trades and an
  exact MAE stream. Current FTMO swaps reduce pooled PF from 1.160916 to
  1.143946 with 29,151.58 close-to-close drawdown, below the strict cost gate.
  It did not enter a portfolio screen.
- `QM5_10468 GDAXI H1` produced 2,953 deterministic full-history trades and an
  exact MAE stream, but the old short-window edge disappeared: native PF is
  0.995131 and current FTMO PF is 0.994936 with 80,097.15 close-to-close
  drawdown. It was rejected before any portfolio screen.
- A predeclared 72-candidate regularized global weight search perturbed all
  eleven incumbent sleeves while capping each weight at 25% and total L1
  distance at 35%. Only `global_sigma_0p3_019` cleared both development gates
  (60.1284% normal and 52.4964% adverse), but it failed untouched 2023
  validation at 41.9643% normal and 35.7143% adverse versus control rates of
  43.7500% and 36.9048%. The selection status is `NO_SURVIVOR`; combined
  preholdout and sealed evaluation remained closed.
- `QM5_11090 USDJPY H1` produced two identical 2,026-trade full-history
  reports. Current FTMO commissions and swaps reduce pooled PF from 1.016997
  to 0.993454 and net profit from 10,190.35 to -3,953.17, with 67,896.05
  close-to-close drawdown. It was rejected before any portfolio screen.
- `QM5_12475 XAUUSD H1` produced two identical valid 2,041-trade reports after
  one empty warm-up attempt. Current FTMO costs reduce pooled PF from 1.150604
  to 0.983694, turn net profit from 135,301.05 to -15,623.89, and raise
  close-to-close drawdown to 121,178.06. It was rejected before any portfolio
  screen.
- `QM5_10594 USDJPY H4` produced two reports with identical metrics and exact
  1,328-trade sequences after recovery from an outer wrapper timeout. Current
  FTMO commissions and swaps reduce pooled PF from 1.087502 to 1.047319 and
  net profit from 32,834.37 to 18,054.81. It failed the strict cost gate before
  any portfolio screen.
- `QM5_11114 USDJPY H1` produced two identical 2,062-trade reports and an
  exactly reconciled current MAE stream. Current FTMO commissions and swaps
  reduce pooled PF from 1.168894 to 1.140741 and raise close-to-close drawdown
  to 52,875.37. The sleeve also loses money in 2017, 2018, 2019, and 2023, so
  it failed the strict cost gate before portfolio admission.
- `QM5_10469 GDAXI H4` produced two identical 2,409-trade full-history reports
  and an exact MAE stream. The old one-year PF 1.2962 did not persist: native
  PF is 1.058909 and current FTMO PF is 1.050462, with 2018, 2019, and 2023
  loss-making. It was rejected before portfolio admission.
- `QM5_12450 USDJPY H1` produced two identical 1,116-trade reports and an
  exactly reconciled MAE stream. The fresh native run is already negative at
  PF 0.921353 and -17,820.60; current FTMO costs reduce it further to PF
  0.903880 and -21,995.34. Six of nine calendar years are negative.
- `QM5_10582 XAUUSD H6` produced two identical 3,115-trade reports and an
  exactly reconciled MAE stream. Current XAU costs and rollover reduce native
  PF 1.106509 to 0.985050 and turn net profit from +56,638.07 to -8,416.30;
  six calendar years are negative. It was rejected before portfolio admission.
- `QM5_10585 XAUUSD H6` produced two identical 1,972-trade reports. Native PF
  is marginally below the gate at 1.197137; current FTMO costs reduce it to
  1.055264, and three calendar years are negative. The current framework also
  emitted no mandatory joint-MAE stream, so both economic and stream gates
  reject the sleeve without a portfolio screen.
- `QM5_10595 USDJPY H4` produced two identical 1,819-trade reports and an exact
  MAE stream. Current FTMO costs reduce native PF 1.055309 to 1.021199 and
  increase close-to-close drawdown to 42,397.95. It was rejected before any
  portfolio or sealed-holdout stage.
- The fully frozen `FTMO25-123A` three-market A-Star candidate completed its
  single authorized physical Segment-A run and was killed economically, not
  technically. Two independent engines matched 31,410 enrichment rows and all
  seven complete streams exactly; coverage, occupancy, risk, and MAE passed.
  Baseline performance was nevertheless PF 0.658443, -65.344039R, Sharpe
  -2.998128, and 65.969039R drawdown. Every year, symbol, side, and variant was
  negative. B/C, portfolio screening, EA build, and deployment remain sealed.
- The five user-supplied secret Research Survivors were carried into a
  predeclared joint bar-MAE marginal screen without fabricated EA IDs. Across
  49 representation/weight combinations, none improved both development
  fills. The closest result, XAU SMA50 at 3%, moved normal from 59.0585% to
  59.4151% but reduced adverse from 51.3552% to 50.2140%. The 2023 validation
  and all later portfolio stages remained closed.
- The retired `QM5_13201 GDAXI H1` convex ORB exposed an optimistic screen
  bias. The old screen omitted H1 bars that crossed both pending thresholds
  and reported PF 1.91/1.91/1.85 for development/2023/holdout. Native MT5
  produced 199 trades in 2024 at PF 0.91. Regenerating all 312 configurations
  with dual-touch days counted as pessimistic stops produced no preholdout
  survivor; the old winner fell to development PF 0.976602 and 2023 PF
  0.845129. The corrected screen also produced the same 199 trades in 2024,
  confirming the native falsification rather than an EA implementation rescue.
- A new causal M15 opening-range sweep-reversal family evaluated 720 fixed
  configurations across GDAXI, NDX, SP500, WS30, and XAU. Entry was delayed to
  the next bar after a completed sweep-and-return signal, with current costs
  and stop-first resolution. No configuration passed development plus 2023;
  the best development PF was only 0.818905 over 72 trades. The sealed holdout
  was never opened.
- A separate causal session-VWAP mean-reversion family evaluated 405 fixed
  configurations with next-bar entry and a signal-time frozen VWAP target.
  No configuration passed development plus 2023. The best row, WS30 with a
  12-bar warmup, achieved only development PF 0.850916 over 946 trades and
  remained loss-making in 2023. The sealed holdout was never opened.
- A gap-confirmed opening-impulse continuation family evaluated 1,215 fixed
  M15 configurations. Its NDX near-miss reached development PF 1.172214 and
  2023 PF 1.109393 over 375/99 trades, but 2018 was materially negative, so no
  base configuration passed the annual robustness gate. A disclosed nested
  filter screen then froze that base and used 2018-2023 only. `momentum5_align`
  made all five available research years positive but reduced pooled PF from
  1.16 to 1.14, failing the predeclared strict-improvement rule. Candidate-
  specific 2024 validation and 2025 holdout remained closed.
- A separately predeclared peer-breadth follow-up tested SP500 and WS30 gap and
  opening-impulse confirmation on the same frozen NDX near-miss. Requiring both
  peer impulses raised research PF from 1.158835 to 1.235533 over 323 trades,
  but its worst annual PF was only 0.640807. No filter passed the annual
  robustness gate, so 2024 validation and 2025 holdout remained unopened.
- The first close-confirmed opening-compression screen evaluated 320 fixed M15
  configurations but exposed a predeclared unit error: comparing a 4-8-bar
  range directly with at most 1.25 single-bar ATR produced at most four
  development trades. A disclosed variance-scaled follow-up then treated all
  2018-2023 observations as research and evaluated 480 fixed configurations.
  No candidate passed; the best row had development PF 1.183382 but only 45
  trades and only three 2023 trades. The untouched 2024/2025 stages stayed
  closed.
- A new opening-impulse pullback-continuation family evaluated 320 fixed M15
  configurations with next-bar entry after a completed 25% or 50% retracement.
  No row passed development plus 2023. The best dense row was WS30 at
  development PF 0.939891 over 444 trades and 2023 PF 1.009480 over 92 trades;
  the sealed holdout was not opened.
- `QM5_10110 GBPUSD H1` falsified its old 2024 archive result on two identical
  1,483-trade full-history reports. Native PF is 0.862187 and current FTMO PF
  is 0.865747 with -64,546.97 net; seven of nine years are negative. Its Q08
  stream reconciles on exact count and within 1.26 of report net, inside the
  predeclared 14.83 tolerance. It was rejected before portfolio admission.
- `QM5_10423 XAUUSD H1` produced two identical 1,648-trade reports and an exact
  Q08 stream. Current FTMO gold commission and rollover reduce native PF
  1.094405 to 0.940633 and turn +61,853.56 native net into -41,561.38. Six
  calendar years are negative, so no portfolio or sealed stage was opened.
- `QM5_10543 EURUSD H1` produced two identical 750-trade reports and a
  reconciled Q08 stream. Native PF is 0.754473 and current FTMO PF is 0.757259;
  every year from 2018 through 2025 is negative. The old one-year FX result was
  rejected without a portfolio screen.
- `QM5_11629 NDX M15` remains infrastructure-blocked rather than economically
  admitted. T4 produced one valid 1,578-trade report, then three `M0/1970`
  reports after NDX history file error 32. A fresh strict compile on T1 then
  produced four `M0/1970` reports after NDX history synchronization errors.
  The single-run stream was retained only as a diagnostic; no current-cost,
  portfolio, or sealed result was computed from it.
- `QM5_10477 NDX H1` hit the same symbol-history lock after one valid report.
  The valid run itself is already negative at 1,619 trades, native PF 0.92,
  -43,974.94 net, and 50,132.56 equity drawdown; its three retries were
  `M0/1970` reports after history error 32. Because the second deterministic
  report is missing, both report and Q08 stream remain diagnostic-only and no
  cost or portfolio stage was opened.
- `QM5_10805 GDAXI H1` produced two identical 1,239-trade reports and an exact
  Q08 stream. The old 2024-only result did not persist: native PF is 1.041992,
  while current `GER40.cash` swaps reduce PF to 1.014181 and net profit to
  7,399.47. The sleeve loses money in 2018, 2019, and 2022 and was rejected
  before portfolio admission.
- `QM5_10133 GDAXI M1` produced two identical 310-trade reports but falsified
  its old archive result at native PF 0.672346, -75,332.38 net, and 84,961.18
  reported equity drawdown. Current FTMO costs leave PF at only 0.685151. Its
  Q08 output independently fails admission with 294 rows versus 310 report
  trades, all 294 rows missing mandatory MAE, and corrected-net delta
  -10,893.61. No portfolio or sealed stage was opened.
- A separately predeclared first-bar gap-response family evaluated 810 causal
  M15 configurations. No row passed the development plus 2023 gate. A
  disclosed nested research pass froze the strongest WS30 gap-fade near-miss;
  `momentum5_align` improved 2018-2023 research PF from 1.145825 to 1.284226
  over 260 trades and made all six research years positive. It then failed the
  once-opened 2024 validation at 50 trades, PF 1.038287, and +1.429112R. The
  2025 holdout remained closed. A second disclosed nested pass froze the NDX
  continuation near-miss. `majority_2_of_3_align` reached research PF 1.249615
  over 206 trades and passed 2024 validation at PF 1.431696 over 45 trades,
  but failed the once-opened 2025 holdout at PF 0.867108, -5.623165R, and 58
  trades. No gap-response candidate reached native-EA or portfolio admission.
- A predeclared 2-hour/4-hour session-displacement family evaluated 360 M15
  continuation and fade configurations. No row passed development plus 2023;
  the best common score was only 1.002633, despite 896 development trades.
  The 2024/2025 holdout remained unopened.
- A predeclared synchronized US-index relative-strength family evaluated 216
  NDX/SP500/WS30 convergence and continuation configurations. It also had no
  preholdout survivor: the best development PF was 0.912932 over 672 trades.
  No candidate-specific holdout, native EA, or portfolio stage was opened.
- The M15 baseline screen was expanded to the previously unused UK100, XAG,
  XTI, and XNG exports under predeclared sessions and conservative round-trip
  costs. Across 576 ORB, opening-impulse, and session-gap configurations there
  was no preholdout survivor. The best family row was an XTI impulse fade with
  only a 0.88 common score, so all native and holdout stages remained closed.
- `QM5_11118 USDJPY H4` produced two identical 3,128-trade reports and an
  exactly reconciled Q08 stream. Native PF is 0.965253 and current FTMO costs
  reduce it to 0.934652, with -53,500.20 net and 69,394.86 close-to-close
  drawdown. Seven of nine calendar years are negative, so it was rejected
  before portfolio admission.
- Approved `QM5_12897 XAGUSD D1` produced two identical 89-trade reports and
  an exactly reconciled Q08 stream. Native PF is 0.649930; current FTMO silver
  commission and rollover reduce PF to 0.555024 and net to -12,514.99. Seven
  calendar years are negative, so it was rejected before portfolio admission.
- Approved `QM5_13120 XTI/XNG D1` produced two identical 24-trade reports.
  Native PF is only 1.06 with +163.76 net and the run is below the predeclared
  40-trade density floor. It was rejected before current-cost or portfolio
  admission because it fails both the native PF 1.2 floor and density gate.
- Approved `QM5_13132 XTI/XNG D1` produced two identical 18-trade reports and
  an exactly reconciled Q08 stream. Native PF is 0.182320 with -3,256.02 net,
  so it fails both the native PF 1.2 floor and the 40-trade density gate. No
  current-cost or portfolio stage was opened.
- Approved `QM5_13018 XAGUSD D1` produced two identical 63-trade reports and
  an exactly reconciled Q08 stream. Native PF is 0.543523; current FTMO silver
  commission and rollover reduce PF to 0.484644 and net to -10,313.16. It also
  has no 2025 trades, so it was rejected before portfolio admission.
- Approved `QM5_12967 UK100 D1` produced two identical 65-trade reports and
  an exactly reconciled Q08 stream. Native PF is 0.636801; current FTMO
  rollover reduces PF to 0.584583 and net to -9,380.43. It was rejected before
  portfolio admission.
- `QM5_1241 USDJPY H1` is no longer infrastructure-pending. Per-ticket/per-bar
  request guards and the full runner label produced two identical 1,519-trade
  reports plus an exact MAE stream without another log bomb. The strategy was
  then rejected economically: native PF is 0.981854 and current FTMO costs
  reduce it to 0.966121 with -15,696.87 net. No portfolio stage was opened.
- A predeclared market-neutral US-index pair screen evaluated 486 NDX/SP500/
  WS30 relative-value reversion configurations with equal ATR-normalized legs
  and pessimistic joint intrabar MAE. No row passed development plus 2023; the
  best row reached only PF 0.327208 in development and 0.397926 in validation.
  The 2024/2025 holdout remained closed.
- A disclosed direction-flip follow-up retained the same 486 pair definitions,
  costs, stops, targets, and gates but tested relative momentum. It also had no
  preholdout survivor; the best common row reached PF 0.457956 in development
  and 0.580079 in validation. No native EA or portfolio stage was opened.
- A previously generated fixed-session screen contained a standalone WS30
  Friday-long survivor: PF 1.251949 in 2018-2022, 1.442239 in 2023, and
  1.132820 in the already-opened 2024-2025 confirmation. Its exact 13:30 New
  York entry, cash-close exit, and one-ATR stop were frozen before a new joint
  screen. Every risk-neutral weight from 0.5% through 10% reduced the normal
  book development result; the best 1% row reached 58.9158%. Adverse,
  validation, native-EA, and deployment stages stayed closed.
- `QM5_10115 GDAXI M15` produced two identical 430-trade reports but the old
  pipeline PF did not persist. Native PF is 1.083800 and current FTMO swaps
  reduce it to 1.071001; 2018-2020 are negative. Its Q08 stream independently
  fails with 392 rows versus 430 report trades, all rows missing MAE, and a
  corrected-net delta of -10,034.11. No portfolio stage was opened.
- A separately predeclared WS30 Friday-session substitution transferred only
  risk from weak donor `11095:GBPUSD`. The 3% row improved both development
  fills, from 59.0585%/51.3552% to 59.2725%/52.3538%, but failed the independent
  2023 validation at 42.5595%/36.3095% versus controls of 43.7500%/36.9048%.
  The 2024-2025 holdout remained closed.
- `QM5_10142 SP500 D1` produced two identical 73-trade reports and an exact MAE
  stream. Current FTMO costs improve pooled PF from 1.338189 to 1.428888, but
  2019, 2020, and 2022 are negative and 2022 has only three trades. A raw 3%
  proportional weight improved normal development from 59.0585% to 59.6291%
  but reduced adverse to 50.0000%. Ten separately predeclared transfers from
  the two NDX donors all failed normal development. No validation was opened.
- `QM5_11181 XAUUSD M5` produced two identical 216-trade reports and an exact
  MAE stream. Current XAU costs reduce PF from 1.589531 to 1.275711; the
  predeclared annual-density gate fails with only two 2017 trades, while 2023
  and 2025 are negative. The candidate stopped before portfolio admission.
- `QM5_12375 XAUUSD D1` produced two identical 330-trade reports, but current
  XAU rollover reduces PF from 1.489332 to 1.105232 and raises close-to-close
  drawdown to 17,927.42. Its Q08 stream also contains only 59 of 330 trades and
  no MAE values. It failed both cost and stream gates before portfolio testing.
- `QM5_11165 AUDCAD H1` produced two identical 133-trade reports and an exact
  MAE stream. Native PF is 1.154236 and current FTMO costs reduce it to
  1.110893; 2019 and 2021 are negative, while 2017 and 2021 miss annual density.
  It was rejected before portfolio admission.
- `QM5_13013 NDX M15` remains infrastructure-blocked without a strategy
  verdict. Four fresh T1 attempts returned empty `M0/1970` reports after an
  explicit NDX history-synchronization error despite a strict clean compile.
- Two new causal concentration policies were implemented and tested. Per-symbol
  caps and a joint EURUSD/GBPUSD/USDJPY cluster cap both reduced normal
  development at every predeclared setting. Their closest rows reached 58.8445%
  and 58.9158%, respectively, versus the uncapped 59.0585% control; adverse,
  validation, and holdout stages remained closed.
- `QM5_12864 XTIUSD/XAGUSD D1` produced two identical 106-trade basket
  reports and an exact mixed-symbol MAE stream. Native PF was only 1.052285;
  leg-specific current FTMO costs reduced PF to 0.977582 and net profit to
  -163.52. The basket was rejected before portfolio admission.
- `QM5_10938 GDAXI H1` ablation 02 produced two identical 61-trade reports and
  an exactly reconciled MAE stream. Current `GER40.cash` PF is 1.272453, but
  2021, 2022, and 2024 lose money and the frozen development years total
  -2,063.01 after current costs. No portfolio or sealed stage was opened.
- `QM5_10476 USDCAD H1` produced two identical 257-trade reports, an exact MAE
  stream, and current FTMO PF 1.331920. A frozen 5% risk-neutral weight was the
  only row to improve both development fills, from 59.0585%/51.3552% to
  59.9857%/51.6405%. It improved normal 2023 validation to 46.1310% but failed
  adverse validation at 31.5476% versus the 36.9048% control. The 2024-2025
  holdout remained closed.
- `QM5_11421 EURUSD D1` produced two identical 92-trade reports and an exact
  MAE stream. Current FTMO PF is only 1.140661; 2019, 2020, and 2022 are
  negative and 2017/2019 miss the annual density floor. It was rejected before
  portfolio admission.
- `QM5_12989 XAUUSD H4` produced two identical 51-trade reports and an exact
  MAE stream. Current gold costs leave a strong pooled PF of 1.523585, but
  every active development year from 2018 through 2022 loses money. The entire
  edge appears only in 2023-2025, so opening validation or the sealed holdout
  would be forward-selection leakage; both stayed closed.
- The distinct `QM5_10163 GDAXI H1` sleeve, not the rejected NDX sleeve,
  produced two identical 628-trade reports and an exact MAE stream. The fresh
  reconstruction falsified its 355-trade archive: current FTMO PF fell from
  the archived 1.280342 to 1.104062. It was rejected before portfolio testing.
- `QM5_12567 XNGUSD D1` produced two identical 58-trade reports and an exact
  MAE stream. Current `NATGAS.cash` costs reduce PF from 1.310950 to 1.214927,
  but 2018, 2022, 2023, and 2024 are negative and four calendar years miss the
  five-trade density floor. It was rejected before portfolio admission.
- `QM5_13117 EURGBP/AUDJPY D1` produced two identical 180-trade basket reports
  and an exact mixed-symbol stream. Current-cost pooled PF is 1.412223 and the
  two legs are structurally distinct, but the predeclared calendar-density
  gate fails because 2017 and 2025 have no trades. No post-hoc leg ablation or
  portfolio weight was opened.
- A predeclared nested filter test on the EURUSD Tuesday London-midday short
  selected `prior_week_return_positive` from 2018-2023 research at PF 1.27.
  It failed the once-opened 2024 validation with 29 trades, PF 0.865738, and
  -1.041910R. The 2025 holdout remained unopened.
- `QM5_10558 EURUSD H6 grid_007` produced two identical 213-trade reports and
  an exact stream. Current-cost PF is 1.473122, but the same-ID, same-symbol,
  same-weight incumbent replacement reduced normal development from 59.0585%
  to 58.7019% and only tied adverse development at 51.3552%. It failed the
  strict dual-fill improvement gate; 2023 and 2024-2025 stayed closed.
- `QM5_10788 XAUUSD H4` produced two identical 224-trade reports and an exact
  stream. Current XAU rollover reduces PF from 1.446351 to 1.127058, and all
  active development years 2018, 2019, 2021, and 2022 are negative. It was
  rejected before portfolio admission.
- A new predeclared FX cross-sectional London-open family evaluated 54
  one-trade-per-day momentum and mean-reversion variants across EURUSD,
  GBPUSD, USDJPY, and GBPJPY. No row passed development plus 2023. The best
  common row had 1,285 development trades but only PF 0.962561 and negative
  development expectancy; the 2024-2025 holdout remained unopened.
- A new causal realized-volatility governor replayed four predeclared 3-/5-day
  RMS targets. Its disabled path exactly reproduced 59.0585% normal and
  51.3552% adverse development. Every active policy reduced both fills; the
  closest row reached only 57.0613%/47.6462%. Validation and holdout remained
  closed.
- `QM5_10588 USDJPY H6` produced two identical 344-trade reports and an exact
  Q08 stream. Current USDJPY costs reduce pooled PF from 1.217504 to 1.169520;
  2017 has only three trades and 2023 is negative at PF 0.820687. The candidate
  stopped before portfolio testing, and 2024-2025 remained closed.
- `QM5_12511 XAUUSD D1` produced two identical 213-trade reports, but current
  gold rollover removes the native edge: PF falls from 1.420822 to 0.988951 and
  net becomes -62.54. Its Q08 stream has only 20 rows versus 213 report trades,
  all without MAE, while 2023 is also negative. No portfolio or 2025 stage was
  opened.
- `QM5_1258 GBPJPY H1` falsified its 2024 density archive over fresh 2017-2023
  history. Both runs had 2,758 trades, native PF 0.906429, and -16,496.14;
  current FTMO costs leave PF 0.904411. The Q08 stream is 96 trades short and
  has no MAE. The candidate was rejected before portfolio testing and 2025
  remained closed.
- A predeclared causal cross-asset family evaluated 1,728 DAX/gold-to-US-index
  lead configurations. No row passed development plus 2023. The best common
  score was only PF 0.936067 on development with -47.658240R, so the 2024-2025
  holdout remained unopened.
- `QM5_10501 USDJPY H1` and `QM5_10540 EURUSD H1` both produced exact MAE
  streams and two identical fresh reports, but each lost money in every year
  from 2017 through 2023. Current FTMO PFs are 0.853806 and 0.842934 with net
  losses of -103,236.86 and -88,860.10. Both stopped before portfolio testing;
  2024-2025 remained closed.
- A fixed incumbent weekday filter mechanically excluded only Wednesday from
  `10715:USDJPY` and Friday from `10286:XTIUSD`, based on four negative years
  out of 2018-2022. It reduced normal development from 59.0585% to 57.7746%
  and adverse from 51.3552% to 50.4280%. The 2023 and sealed stages remained
  closed.
- A current-swap, stop-first overnight-premium screen evaluated 2,700 fixed
  configurations. Six passed development plus 2023; the single locked global
  winner was a WS30 Wednesday short with PF 1.404667 in 2018-2022 and 1.319502
  in 2023. Its once-opened holdout failed in both years: PF 0.842273 in 2024,
  PF 0.484431 in 2025, and -31.348126R pooled. No runner-up holdout was opened.
- `QM5_10700 XAUUSD H1` produced two identical 317-trade reports and an exact
  MAE stream. Current gold rollover reduces PF from 1.237628 to 1.085234 and
  consumes 23,537.54 in swap. The selection-known 2024 year supplies more than
  the entire pooled current-cost profit while 2018 loses 12,094.61, so no
  portfolio or 2025 stage was opened.
- A global cross-market pair screen reused the pessimistic joint-extreme engine
  for DAX/UK100, gold/silver, and oil/gas across 972 reversion and momentum
  configurations. No row passed development plus 2023; the highest common
  score was only PF 0.369782/0.340392. The 2024-2025 holdout remained closed.
- `QM5_9206 GDAXI H1` failed the deterministic evidence contract: only one of
  four attempts produced a valid report and the other three returned zero
  bars. The sole valid run was already negative before FTMO recosting, with
  1,870 trades, PF 0.94, -47,939.94 net, and 80,842.02 equity drawdown.
- `QM5_11476 USDJPY H1` produced two identical 2,506-trade reports and an exact
  Q08 stream. Current costs reduce PF to 1.003310; 2018, 2019, 2021, and 2023
  lose money, while the selection-known 2024 gain exceeds pooled profit. It
  was rejected before portfolio admission and 2025 remained closed.
- `QM5_1120 GBPUSD M15` produced two identical 1,731-trade reports and an exact
  stream, but native PF is 0.983865 and current-cost PF is 0.993428. Four of
  five development years lose money, so no portfolio stage was opened.
- `QM5_10590 XAUUSD H4` produced two identical 1,644-trade reports and an exact
  stream. Current gold rollover of -60,269.08 turns native PF 1.044003 and
  +21,310.03 net into PF 0.914810 and -44,184.19; four development years and
  2023 validation lose money.
- `QM5_10132 NDX H1` produced two identical 1,664-trade reports and an exact
  stream. Current `US100.cash` costs improve PF to 1.118085 and net to
  58,186.08, but it misses the frozen 1.20 floor and the selection-known 2024
  gain supplies most of pooled profit. Portfolio and 2025 stages stayed closed.
- The completed broad M15 causal screen evaluated 1,670 configurations and
  found zero preholdout survivors. Its 2024-2025 holdout was not opened and no
  native EA was authorized.
- A predeclared causal sleeve-edge policy exactly reproduced the normal and
  adverse controls at 59.0585% and 51.3552%. Every active trailing-performance
  rule failed the dual-fill development gate; validation and holdout stayed
  closed.
- A separate breadth-following trailing-stop family evaluated 648 fixed
  configurations. None survived development plus 2023; the best row remained
  loss-making at PF 0.876885 in development and 0.758943 in validation.
- The local USD CPI calendar timestamps were checked against official BLS
  releases and corrected by the fixed declared transform `local + 1 day - 7
  hours`. The subsequent 108-configuration surprise-drift screen found no
  preholdout survivor. Its strongest row had PF 1.513866 on 38 development
  trades and PF 8.194136 on six validation trades, but missed the frozen
  40/8 minimum-density gates; 2024-2025 remained sealed.
- `QM5_10580 USDJPY H4` produced two identical 1,366-trade reports and an exact
  Q08 stream. Native PF 0.988645 falls to 0.958611 under current costs, while
  2019-2021, 2023, and 2024 lose money. It stopped before portfolio admission.
- `QM5_11116 USDJPY H4` produced two identical 1,544-trade reports and an exact
  stream. Native PF is 0.948322, current-cost PF is 0.922392, and 2023
  validation is negative at PF 0.813279. The positive selection-known 2024
  result did not authorize opening 2025.
- A broader US macro-surprise basket normalized 903 CPI, core PCE, payroll,
  unemployment, retail-sales, and advance-GDP components into 521 fixed
  release packages after BLS/Census/BEA timestamp validation. None of 324
  drift configurations survived development plus 2023. The best common row
  was still negative at PF 0.983357 on 114 development trades and PF 0.983262
  on 16 validation trades; 2024 and partial 2025 remained unopened.
- A causal conditional-deadline governor tested ten policies that accelerated
  only accounts already above starting balance but below target. Under the V1
  zero-breach-increase rule none survived, although `d23_p0_9500_r40` improved
  development normal/adverse fills from 59.0585%/51.3552% to
  59.9857%/51.9971% while increasing adverse daily breach by 0.2853 points.
  V1 remained closed. A separately predeclared V2 locked exactly that row and
  allowed at most 0.5 points of individual breach increase. The replay passed,
  but once-opened 2023 validation tied both controls at 43.7500%/36.9048%
  rather than strictly improving them. The 2024-2025 holdout stayed closed.

## Operational Boundary

All work is restricted to isolated Strategy Tester terminals T1-T5. T5 remains
disabled due to its existing defect. `T_Live`, installed FTMO terminals,
AutoTrading state, and live accounts were not touched. The factory-off flag
must remain present while this research continues.

The fresh `QM5_10815 GDAXI` stream rebuild exposed a tester-only framework
defect: account-currency conversion queried unsuffixed `EURUSD` before the
available `.DWX` custom pair, causing shutdown history timeouts and invalid
reports. `QM_FrameworkCurrencyRateToAccount` now prefers the `.DWX` pair when
the tested symbol is `.DWX`; the regression test is in
`tools/strategy_farm/tests/test_ftmo_q08_currency_resolution.py`. A fresh
post-fix deterministic run has now completed and was evaluated as described
above.

## Next Gate

The remaining gap is 10.0999 percentage points in the threshold reconstruction
and 20.6562 points in the adverse reconstruction. A candidate is allowed to
open the sealed holdout only after it improves both normal and adverse
development results under a predeclared weight grid. Passing the 80% objective
requires the final sealed estimate and its adverse counterpart to be reported
separately; a normal-only or in-sample result is insufficient.
