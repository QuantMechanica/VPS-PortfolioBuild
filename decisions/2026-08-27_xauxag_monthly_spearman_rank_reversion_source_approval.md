# XAU/XAG Monthly Spearman Rank Reversion - Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue does not authorize a
manual tester dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission requests one new structural,
low-frequency commodity edge outside the directional XAU/SP500/NDX/XNG book,
expressly permits a market-neutral-style XAUUSD/XAGUSD basket, requires
reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xauxag-mspearman-rv`
- proposed strategy ID:
  `SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026`
- proposed host/traded slot 0: `XAUUSD.DWX`, D1
- proposed companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade only a strong Spearman association between thirteen completed
  synchronized gold-minus-silver log-ratio ranks and their calendar ranks

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`,
   SHA-256
   `D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8`.
   It preserves Karsten Schweikert (2018), *Journal of Banking & Finance* 88,
   44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and official CME Group
   gold/silver ratio-spread carrier research. It supports a related but
   state-dependent gold/silver relation and distinct metal demand drivers; it
   does not establish a constant hedge ratio or universal mean reversion.
2. `strategy-seeds/sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026/source.md`,
   SHA-256
   `38B53FD42A8E9CBA533957D5A376D8F8D4E5CA0F8EBB249D8464F761C8D2AB98`.
   It preserves C. Spearman's named peer-reviewed record and complete pinned
   R Core `stats::cor` method files from public GitHub commit
   `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. The exact method is ordinary
   correlation after rank-transforming both ordered inputs.
3. The governed composite packet
   `strategy-seeds/sources/SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026/source.md`.

The sources support a falsifiable paired-metal ratio experiment and exact
rank statistic, not the proposed trading conjunction. The thirteen endpoints,
integer threshold, contrarian direction, continuous-CFD mapping, equal-
notional construction, aggregate fixed-dollar risk, stops, atomicity,
consumed attempt, and lifecycle are disclosed QM choices.

No source return, alpha, probability, Sharpe ratio, drawdown, transaction
cost, hedge ratio, neutrality, CFD equivalence, decorrelation, or portfolio-
correlation statistic transfers.

## Locked Mechanic

On the first synchronized executable D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before every fallible gate.
2. Reconstruct the latest exactly timestamp-matched XAU/XAG D1 close pair in
   each of the thirteen immediately prior consecutive completed broker
   months; reject malformed, stale, or tied ratio history.
3. Form chronological `s[i]=ln(XAU[i])-ln(XAG[i])`, assign strict ranks
   `R[i]`, calculate `D=sum((R[i]-(i+1))^2)` and `T=364-D`, and prove the
   permutation, range, and parity invariants.
4. If `T>=104`, SELL XAU and BUY XAG. If `T<=-104`, BUY XAU and SELL XAG.
   Otherwise consume the month flat. This is exactly `abs(rho)>=2/7`; no
   p-value, fitted hedge ratio, center, scale, or fallback exists.
5. Open at most one opposite-side, equal-target-absolute-USD-notional package
   under aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally and use a frozen
   `3.5*ATR(20,D1)` hard stop on each leg, no target, and bounded spreads.
6. Submit XAU first and XAG second, retain only a complete valid package,
   close at the next broker-month transition or after forty calendar days,
   and repair orphaned or malformed owned exposure immediately.

Both news axes, legacy news mode, and Friday close are OFF. The threshold was
fixed before market testing. Exact enumeration of all `13!` no-tie rank paths
gives a two-tail qualification rate of `0.3436382463986631`, or about 4.12
monthly decisions per twelve attempts. This is a density design fact, not a
gold/silver probability, significance, or performance claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: peer-reviewed
  gold/silver relation evidence, official exchange carrier research, named
  original Spearman journal record, and complete pinned R Core method files.
  The exact trading conjunction remains explicitly untested.
- R2 `PASS`: clock, synchronized endpoint selection, strict ranks, integer
  score, threshold, contrarian sides, attempt, aggregate risk, atomicity, and
  lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories plus MT5 state supply every runtime input.
- R4 `PASS`: deterministic prices, ranks, integer arithmetic, calendar, and
  execution state only; no trained output, banned signal method, external
  feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,673 EA-registry rows, 1,324 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is
`artifacts/qm5_xauxag_mspearman_rv_preallocation_dedup_20260827.json`.

Manual functional review fixes a new state object and lifecycle:

- `QM5_41173_wti-mspearman-tr` uses the same rank statistic on one outright
  WTI series, follows its sign, and owns one position. This candidate ranks a
  synchronized paired-metal ratio, fades the sign, and owns an atomic equal-
  notional two-leg package.
- `QM5_41168_xauxag-mcoxstuart-rv` compares seven fixed lag-seven pairs among
  fourteen ratios and discards their positions within each half. This rule
  uses every one of thirteen exact time-rank displacements.
- XAU/XAG z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint,
  quarterly-vote, Theil-Sen, LAD, repeated-median, and robust-consensus cards
  calculate different state objects and use different gates.
- Ratio-rank vector `[3,2,10,1,4,12,11,8,7,9,6,5,13]` gives `T=170`, so this
  rule shorts the ratio, while the existing thirteen-point Mann-Kendall gate
  is flat at `S=20`. Vector
  `[13,1,4,12,5,2,3,6,7,8,9,10,11]` gives `T=98`, so this rule is flat while
  Mann-Kendall qualifies at `S=28`.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly paired-metal rank reversion.

Verdict:
`CLEAN_XAUXAG_MONTHLY_SPEARMAN_TIME_RATIO_RANK_T104_CONTRARIAN_BASKET`.

## Kill And Safety Boundary

The pre-result density prior is four to seven completed packages per full
post-warm-up year. Q02 must retire the candidate below four in any full year,
at zero trades, with nonpositive governed economics, or on any endpoint,
rank, threshold, side, attempt, risk, atomicity, or lifecycle defect.

Equal target notionals reduce common outright-metal direction but do not
prove beta, factor, market, dollar, or portfolio neutrality. Unchanged Q09
alone owns realized overlap. No failed result may be rescued by changing the
sample, rank rule, threshold, direction, hedge construction, risk, hold, or
by adding a filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
