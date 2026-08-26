# XAU/XAG Monthly Cox-Stuart Paired-Sign Reversion — Source Approval

Date: 2026-08-26

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue is not authority to
dispatch a manual tester or work above the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits a market-neutral-style
`XAUUSD~XAGUSD` ratio-reversion basket, requires a genuinely new structural
low-frequency mechanic with reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xauxag-mcoxstuart-rv`
- proposed strategy ID:
  `SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026`
- host/traded slot 0: `XAUUSD.DWX`, D1
- companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a new broker month
- signal: fade the direction supported by at least five of seven fixed
  Cox-Stuart half-sample comparisons across fourteen synchronized completed
  month-end gold-minus-silver log ratios

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following governed packets were read completely before this decision:

1. `strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`,
   SHA-256
   `D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8`.
   It preserves Karsten Schweikert (2018), "Are gold and silver
   cointegrated? New evidence from quantile cointegrating regressions,"
   *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, together with the official CME Group
   "Gold & Silver Ratio Spread" carrier record. It supports testing a related
   but state-dependent gold/silver relation and identifies shared precious-
   metal/USD drivers alongside materially different monetary, safe-haven,
   industrial, and business-cycle exposures.
2. `strategy-seeds/sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026/source.md`,
   SHA-256
   `7E0D0F9595CCBDB2CA2B2FEDD02BE2E969CC129CE293C48F44C42BDDC9CBC629`.
   It preserves D. R. Cox and Alan Stuart (1955), "Some Quick Sign Tests for
   Trend in Location and Dispersion," *Biometrika* 42(1-2), 80-95, DOI
   `10.1093/biomet/42.1-2.80`, and the complete official NIST Dataplot
   algorithm record. For an even ordered sample, NIST fixes `c=n/2`, pairs
   `X_i` with `X_(i+c)`, and applies a sign test to the paired differences.

The original Cox-Stuart paper body is paywalled and is not represented as
completely read; the official bibliographic record and complete public NIST
algorithm are the bounded method evidence. Schweikert and CME do not specify
this statistic, horizon, direction, continuous-CFD mapping, or trade. The
Cox-Stuart record does not establish gold/silver reversion. The conjunction,
5-of-7 threshold, synchronized calendar, contrarian side mapping, fixed risk,
stops, spread caps, and lifecycle are disclosed QM hypotheses.

No source alpha, return, probability, significance, density, Sharpe ratio,
drawdown, cost, hedge ratio, neutrality, CFD equivalence, decorrelation, or
portfolio-correlation statistic transfers.

## Locked Mechanic

On the first synchronized executable `XAUUSD.DWX`/`XAGUSD.DWX` D1 tick after
each genuine broker-month transition:

1. Persist the current broker `yyyymm` as consumed before history, signal,
   news, spread, quote, ATR, sizing, margin, or order gates. Never retry the
   month after a flat signal, invalid state, reject, stop, partial fill, or
   restart.
2. Exclude the current month. Reconstruct exactly fourteen consecutive
   completed broker calendar months ending with the immediately prior month.
   For each month retain the latest close pair whose host and companion D1
   timestamps match exactly. Reject missing or duplicate months,
   nonchronological pairs, nonpositive closes, or a newest endpoint more than
   ten calendar days stale.
3. In chronological order form
   `s[i]=ln(XAU_close[i])-ln(XAG_close[i])`, `i=0..13`.
4. For `i=0..6`, compute the fixed Cox-Stuart difference
   `d[i]=s[i+7]-s[i]`. Require exactly seven finite, nonzero differences. Any
   tie consumes the month flat. Difference magnitudes never change direction
   or risk.
5. If at least five differences are positive, open SELL XAU / BUY XAG. If at
   least five are negative, open BUY XAU / SELL XAG. A 4/3 split or invalid
   state consumes the month flat.
6. Open at most one opposite-leg package with equal target absolute USD
   notionals, aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split the frozen stop-risk budget equally, attach
   `3.5*ATR(20,D1)` broker hard stops, attach no targets, cap entry spread at
   1,500 XAU points and 500 XAG points, and require realized absolute-notional
   mismatch no greater than 20%.
7. Submit XAU first and XAG second. Retain the package only when exactly one
   correctly directed, registered, stop-protected position exists in each
   slot. Flatten all owned exposure immediately after any second-leg or final-
   package validation failure.
8. Close both legs on the first tick in a later broker month, after forty
   calendar days, or whenever the package is orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, stopless, stale, or notional-invalid. Friday
   close and both news axes are OFF for the monthly hold.

The 5-of-7 boundary is fixed before market testing. Under an explicitly
non-empirical fair independent-sign thought experiment, the two directional
tails contain `2*(C(7,5)+C(7,6)+C(7,7))=58` of 128 sign vectors, or 45.3125%.
Twelve monthly decisions would therefore imply 5.4375 qualifying paths per
year. This is a density prior only; real ratio-pair signs are neither asserted
independent nor fair.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: named-author peer-
  reviewed gold/silver relationship research with DOI, official-exchange
  ratio-spread evidence, an official peer-reviewed Cox-Stuart record, and a
  complete official NIST pairing description. The exact trading conjunction
  is explicitly untested.
- R2 `PASS`: clock, synchronization, fourteen months, ratio orientation,
  seven fixed pairs, tie rule, 5-of-7 contrarian sides, durable attempt,
  aggregate risk, stops, atomicity, and exits are deterministic and locked.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply
  every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, comparisons, integer sign
  counts, ATR risk controls, and execution state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical fail-closed checker, run against the actual Company Reference
Vault, scanned 4,667 EA-registry rows, 1,318 card files, and 45 Strategy Wiki
nodes. It returned `CLEAN` with no exact or fuzzy match. Evidence is
`artifacts/qm5_xauxag_mcoxstuart_rv_preallocation_dedup_20260826.json`,
SHA-256 `B89423A13EFCE50F40FE8977561924FADA69281C8ACAFB475AEC6B8D701BE594`.

Manual functional review fixes a new state statistic:

- `QM5_41167_wti-coxstuart-tr` uses the same seven-pair statistic on one
  outright WTI series, follows the sign, and owns one leg. This candidate
  constructs a synchronized two-metal ratio, fades the sign, and owns an
  atomic equal-notional package.
- `QM5_41157`, `QM5_41160`, `QM5_41164`, and `QM5_41166` retain ratio-path
  magnitude through Theil-Sen, LAD, repeated-median, or unanimous robust-slope
  geometry. This candidate discards every difference magnitude after seven
  disjoint comparisons and fits no slope.
- `QM5_20050_xauxag-xmom12` and `QM5_20202_xauxag-rev18` use endpoint returns;
  `QM5_20161_xauxag-ols-rv` and `QM5_21526_xau-xag-cadf` fit regression state;
  monthly sign-breadth, block-vote, path, sequence, and location cards observe
  different state objects.
- On log-ratio ranks
  `[0,8,3,7,10,2,4,6,13,11,12,9,5,1]*0.01`, five of seven fixed pairs rise,
  so this candidate shorts the ratio; the latest-thirteen Mann-Kendall score
  is only `2`, the twelve-month endpoint falls, and four three-month block
  signs split 2/2.
- On log-ratio ranks
  `[12,4,0,3,7,8,13,2,5,1,9,6,10,11]*0.01`, the fixed pairs split 4/3 and
  this candidate stays flat, while the latest-thirteen Mann-Kendall score is
  `30`, the twelve-month endpoint rises, and three of four quarterly blocks
  rise.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither paired-metal exposure nor monthly paired-
  sign logic.

Verdict:
`CLEAN_XAUXAG_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_RATIO_REVERSION`.

## Kill And Safety Boundary

The pre-result density prior is five to eight completed packages per full
post-warm-up year. Q02 must retire below five completed packages in any full
post-warm-up year, at zero trades, with nonpositive governed economics, or on
any timestamp, month, ratio, pair, tie, count, side, attempt, risk, atomicity,
lifecycle, or determinism defect.

Opposite equal-notional legs reduce some common outright-metal direction but
do not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Q09 alone owns realized book correlation. No failed result may be rescued by
changing the sample, pairing, threshold, direction, carrier, risk, hold, or by
adding endpoint, regression, volatility, event, seasonal, external, or prior-
result state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
