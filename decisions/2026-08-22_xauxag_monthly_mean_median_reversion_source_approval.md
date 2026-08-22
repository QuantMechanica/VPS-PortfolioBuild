# XAU/XAG Completed-Month Mean-Median Reversion - Source Approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on the `agents/board-advisor` branch on 2026-08-22. The
mission explicitly permits a market-neutral `XAUUSD~XAGUSD` gold/silver ratio
reversion basket, requires one new non-duplicate reputable-source card with
`RISK_FIXED` backtests, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-mmean-median-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026`
- carrier: exact `XAUUSD.DWX` and `XAGUSD.DWX`, synchronized D1 basket
- state: arithmetic mean versus ordinary median of all synchronized daily
  gold/silver log-ratio closes inside the immediately completed broker month
- action: fade the direction in which tail observations pull the mean away
  from the median, using opposite equal-notional legs for one broker month
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The governed records below were read completely before this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
   It records the named peer-reviewed Karsten Schweikert (2018) article,
   "Are gold and silver cointegrated? New evidence from quantile
   cointegrating regressions," *Journal of Banking & Finance* 88, 44-51,
   DOI `10.1016/j.jbankfin.2017.11.010`, plus the supporting Yaya, Vo, and
   Olayinka (2021) fractional-cointegration paper.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
   CME Group defines the gold/silver price ratio and its use as an
   intermarket spread carrier, while distinguishing gold's monetary and
   safe-haven exposure from silver's larger industrial-cycle exposure.

The bounded child extraction will be
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026/source.md`.

The peer-reviewed lineage supports a potentially state-dependent long-run
gold/silver relationship rather than a universal fixed equilibrium. CME
supports the ratio and tradable-spread carrier. Neither source tests a
completed-month arithmetic-mean-versus-median state, interprets that
displacement as tail bias, prescribes the contrarian side, or validates a
Darwinex continuous-CFD basket. Those are predeclared QM falsification
choices. No source return, density, cost, hedge ratio, neutrality, or
portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XAUUSD.DWX` host and `XAGUSD.DWX` companion, D1, slots zero
   and one, aggregate fixed-risk backtest inputs, both news axes OFF, and
   Friday close OFF.
2. On the first tradable exact XAU D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw open, reconstruct the immediately
   completed broker month from synchronized completed XAU/XAG D1 close pairs.
   Require 17 through 23 unique, strictly ordered, timestamp-identical
   sessions and no current-month observation.
3. For every valid session `d`, compute
   `r[d]=log(XAU_close[d])-log(XAG_close[d])`. Compute the arithmetic mean of
   all `r[d]`. Sort a copy and compute the ordinary sample median: the center
   value for odd `n`, or the arithmetic mean of the two center values for
   even `n`.
4. If `mean>median`, SELL XAU and BUY XAG. If `mean<median`, BUY XAU and SELL
   XAG. Exact equality, invalid arithmetic, missing synchronization, or an
   invalid month consumes the attempt flat. Displacement magnitude never
   changes eligibility or risk.
5. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, order failure, stop, or restart cannot retry
   that month.
6. Target one-to-one absolute entry notional and reject a rounded mismatch
   above 20 percent. Size both legs so their combined frozen-stop loss cannot
   exceed one `RISK_FIXED=1000` package budget, with `RISK_PERCENT=0`.
7. Attach a frozen `3.5 * ATR(20,D1)` hard stop to each leg. Use no target and
   cap entry spread at 1,500 XAU points and 500 XAG points. If leg two fails,
   flatten leg one; malformed or orphaned exposure is never a valid strategy.
8. Close both legs on the first tick of a later broker month or after forty
   elapsed calendar days. Never trail, partially close, scale in, grid,
   martingale, pyramid, retry, or add an external runtime dependency.

## Reputable-Source Criteria

- R1 `PASS_WITH_MEAN_MEDIAN_TAIL_TRANSLATION_RISK`: named peer-reviewed
  finance and resources-policy papers with DOI plus official CME carrier
  material; the internal completed-month mean-median state and contrarian map
  are disclosed as untested QM translations.
- R2 `PASS`: exact instruments, clock, synchronized month membership, sample
  bounds, log ratio, mean, odd/even median, strict side map, attempt, aggregate
  risk, notional tolerance, stops, spreads, atomic repair, and lifecycle are
  locked before testing.
- R3 `PASS_WITH_CFD_BASIS_AND_RESIDUAL_BETA_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 data plus MT5-native state provide every
  runtime input; Q02 owns history, density, costs, fills, financing, and
  continuous-CFD sufficiency.
- R4 `PASS`: deterministic timestamps, sorting, logarithms, arithmetic, and
  framework state only; no trained logic, banned signal, external feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed pre-allocation checker, including author and mechanic fields
and the explicit Company Reference Wiki root, scanned 4,598 registry
identities, 1,277 repository cards, and 45 Strategy-Wiki nodes. It found no
exact or fuzzy identity. Receipt:
`artifacts/qm5_xauxag_mmean_median_rv_preallocation_dedup_20260822.json`.

Manual semantic review also separates:

- `QM5_41104_xauxag-mmedian-shift-rv`, which compares the medians of two
  non-overlapping completed months. This candidate compares one completed
  month's mean with its own median and therefore reacts to internal tail
  imbalance without any between-month location shift.
- `QM5_20263_xauxag-mad-rv`, which uses a rolling 63-D1 median/MAD z-score,
  threshold crossing, and rolling-center exit. This candidate estimates no
  scale, uses no threshold or crossing, and enters only once per month.
- `QM5_20268_xauxag-qtail-rv`, which uses frozen 126-observation empirical
  decile tail excursions and a central-band exit. This candidate uses every
  synchronized observation in one exact month, has no quantile threshold,
  and holds to the next month.
- `QM5_20233_xauxag-skew-rank`, which estimates each metal's standardized
  third moment over twelve complete months and buys the lower-skew metal.
  This candidate computes neither individual return skewness nor a
  cross-sectional rank; it compares mean and median of the single log-ratio
  level sample over one completed month and fades that internal displacement.
- `QM5_20157_xau-xag-ratio`, which fades a rolling 60-day ratio mean/standard-
  deviation score. This candidate uses no rolling window, standard deviation,
  z-score, or intramonth center exit.
- `QM5_12533`, which supplies the logical-basket manifest/order recipe but
  trades an EURJPY/GBPJPY rolling cointegration spread.
- certified `QM5_12567_cum-rsi2-commodity`, a single-symbol long-only two-day
  XNG oscillator pullback with no intermetal, monthly, median, or paired logic.

The exact carrier, one synchronized completed calendar month, ordinary
mean and odd/even median, strict internal displacement, contrarian paired
sides, consumed monthly attempt, equal-notional aggregate-risk package, and
next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_INTERNAL_MEAN_MEDIAN_TAIL_BIAS_REVERSION`.

## Portfolio Claim Boundary

The candidate is an opposite-leg relative-value package intended to reduce
outright precious-metal direction and expose gold-versus-silver repricing
outside the certified XAU/SP500/NDX/XNG book. Equal notional and opposite
legs do not prove dollar, beta, volatility, market, factor, or portfolio
neutrality. Q09 alone may establish realized overlap; this approval makes no
decorrelation or admission claim.

## Frequency, Kill, And Safety Boundary

Exact mean-median equality should be rare after a valid completed-month
sample, so the predeclared expectation is ten to twelve completed packages
per full post-warm-up year. Q02 must retire below the unchanged five-trades-
per-year floor, at zero trades or nonpositive governed economics, or on any
clock, synchronization, month-sample, mean, median, side, attempt, notional,
risk, atomicity, lifecycle, or determinism defect. No weak result may be
rescued by adding a displacement threshold, changing the direction or hold,
loosening session bounds, or adding volatility, volume, season, weekday,
moving-average, event, external-data, or prior-result state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or `T_Live` manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after strict compile/Q01 PASS and fresh exact-path tester and host-CPU checks
are below their ceilings. At the ceiling, stop before queue mutation and
record a non-live handoff.
