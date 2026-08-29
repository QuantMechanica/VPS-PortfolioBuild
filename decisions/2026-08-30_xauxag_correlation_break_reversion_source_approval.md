# XAU/XAG Weekly Correlation-Break Relative-Value Fade - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced logical-basket Q02 enqueue if the active factory is below its CPU
ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified directional
XAU/SP500/NDX/XNG book, explicitly permits a market-neutral XAU/XAG basket,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xauxag-corrbreak-rv`
- proposed strategy ID:
  `KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026_S01`
- proposed source ID: `KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- clock: first executable host D1 tick of each genuine broker week
- state: a disjoint 60-session baseline versus 20-session recent
  gold/silver return-correlation break plus a five-session standardized
  relative displacement
- lifecycle: fade the relative winner with one atomic equal-notional
  opposite-leg package until a frozen halfway retracement or time exit

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

The complete bounded packet is
`strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-CORRBREAK-2026/source.md`,
SHA-256
`7AF659643DF0CCD6AF645815882545F7336CA96705DC678A76880A91613416D3`.
Its complete-read parent paths and exact hashes are fixed in
`artifacts/qm5_xauxag_corrbreak_rv_source_provenance_20260830.json`, SHA-256
`898BC2A49163348842560F0C487B59D17A06F231C23D58FD9D53D977946442B2`.

Krawiec and Gorska (2015), *Quantitative Methods in Economics* 16(2),
13-22, supply complete-read daily gold/silver dependence and causal-ordering
evidence: positive contemporaneous log-return correlation of 0.6061 and
gold-to-silver Granger ordering in their 2008-2013 London-price sample.
Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`, supplies complete-read state-dependent
gold/silver relation evidence and explicit adverse evidence against one stable,
automatically profitable spread. CME's governed exchange packet supplies the
gold/silver intermarket carrier and distinct monetary/industrial driver
context.

No source tests the exact disjoint Pearson/Fisher state change, the five-day
relative-displacement score, a halfway-retracement exit, Darwinex continuous
CFDs, or the current book. No performance, significance beyond the reported
historical tests, density, cost, drawdown, hedge, CFD-equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XAUUSD.DWX` D1 tick of a genuine broker week:

1. Repair malformed owned exposure and persist the broker-week key before
   every fallible entry gate. Never retry that week after any outcome.
2. Under one uniform native or `+1` metal D1-label convention, load exactly
   81 synchronized positive completed close pairs and form 80 adjacent log
   returns for each metal. The current bar is excluded.
3. Compute Pearson `rho_old` on the oldest 60 returns and `rho_new` on the
   newest disjoint 20. Compute
   `z_drop=(atanh(rho_old)-atanh(rho_new))/sqrt(1/57+1/17)` after transform-only
   clamping to `+/-0.999999999`.
4. Require `rho_old>=0.50`, `rho_new<=0.35`,
   `rho_old-rho_new>=0.25`, and `z_drop>=1.645`.
5. On the same old 60 observations compute relative return
   `d=r_xau-r_xag`, its mean and sample standard deviation. Require finite
   positive scale and calculate
   `score5=(sum(newest five d)-5*mean)/(sd*sqrt(5))`.
6. At `score5>=+1.25`, sell XAU and buy XAG. At
   `score5<=-1.25`, buy XAU and sell XAG. Consume flat otherwise. Signal
   magnitude never changes size.
7. Freeze the log-ratio halfway point between the completed signal ratio and
   its exact five-session-prior anchor. It is the cross-leg convergence exit.
8. Split one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` package budget equally by per-leg stop risk. Target
   equal USD notionals, reject post-rounding mismatch above 20%, attach frozen
   `3.5*ATR(20,D1)` hard stops, and set no broker target.
9. Reject genuinely positive spreads above 1,500 XAU points or 3,000 XAG
   points. Flatten partial, same-side, duplicate, missing-state, or otherwise
   malformed composition immediately.
10. Close at the first completed-ratio halfway retracement, after 15 completed
    host D1 bars, or after 24 calendar days.

Both news axes, legacy news mode, and framework Friday close are OFF. No
fallback window, equilibrium center, hedge regression, same-calendar sample,
current-bar signal, magnitude sizing, target optimization, trained output,
banned indicator, or external runtime feed is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_STATE_TRANSLATION_AND_CFD_RISK`: complete-read
  peer-reviewed dependence/state evidence and governed exchange carrier; the
  exact correlation-break fade is an untested QM translation and source
  adverse evidence remains binding.
- R2 `PASS`: clock, synchronization, exact counts, disjoint blocks, Pearson
  and Fisher arithmetic, four break boundaries, relative scale, score,
  package sides, attempt/target state, shared risk, stops, atomicity,
  retracement, and time exits are locked before Q02.
- R3 `PASS_WITH_SYNCHRONIZATION_CONTINUOUS_CFD_AND_LEGGING_RISK`: registered
  native XAU/XAG D1 histories and MT5 state provide all inputs; history labels,
  density, rolls, spreads, fills, and CFD basis remain explicit Q02 risks.
- R4 `PASS`: deterministic dates, logarithms, sums, products, square roots,
  `atanh`, comparisons, and ATR risk plumbing only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker examined 4,706 registry identities and 1,352 card
files. Its configured Strategy Wiki root was missing, so no Wiki coverage is
claimed. It found no exact identity and only the expected fuzzy
`QM5_41031_xauxag-goldlead` family. Receipt:
`artifacts/qm5_xauxag_corrbreak_rv_preallocation_dedup_20260830.json`,
SHA-256
`970112BA5AF89F0645D21AED1F28BACB50746D9C180FB4C802F0C8BD9295B1BF`.

Manual review separates the executable identity:

- `QM5_41031` uses one gold shock and bounded silver under-response, never
  estimates a correlation transition, and exits on the next D1 bar;
- ratio, OLS/CADF, MAD, empirical-tail, and conditional-quantile baskets
  estimate relative levels or fitted centers; this card estimates none;
- `QM5_12862` fades a rolling return-spread z-score without a disjoint
  high-to-low Pearson/Fisher state break;
- variance-ratio cards estimate return memory rather than a dependence-state
  transition; and
- weekly flow/path/common-shock and same-calendar baskets observe different
  information objects.

Verdict:
`FUZZY_GOLDLEAD_RESOLVED_DISTINCT_DISJOINT_CORRELATION_BREAK_PLUS_FIVE_SESSION_RELATIVE_DISPLACEMENT_FADE`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate at zero trades, below five completed
packages in any full post-warm-up year, with nonpositive governed economics,
or on any label, endpoint, synchronization, sample-membership,
Pearson/Fisher, relative-scale, score, side, attempt, target, atomicity,
fixed-risk, stop, lifecycle, or determinism defect. No failed result may be
rescued by moving a boundary, changing a window, fitting a hedge, dropping a
leg, extending the hold, or modifying a gate.

The opposite legs target a relative dependence break but do not prove dollar,
beta, volatility, or portfolio neutrality. Only unchanged Q09 owns realized
decorrelation. This approval excludes manual backtests; live/demo/shadow/
stress/optimization setfiles; terminal control; AutoTrading; `T_Live`;
deploy or live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers.
