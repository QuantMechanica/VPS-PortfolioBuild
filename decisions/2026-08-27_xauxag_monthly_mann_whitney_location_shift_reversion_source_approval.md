# XAU/XAG Monthly Mann-Whitney Location-Shift Reversion - Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue does not authorize a
manual tester dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission requests one new structural,
low-frequency commodity edge outside the directional XAU/SP500/NDX/XNG book,
expressly permits a market-neutral-style `XAUUSD`/`XAGUSD` basket, requires
reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xauxag-mwilcoxon-shift-rv`
- proposed strategy ID:
  `SCHWEIKERT-MANNWHITNEY-CME-XAUXAG-MSHIFT-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-MANNWHITNEY-CME-XAUXAG-MSHIFT-RV-2026`
- proposed host/traded slot 0: `XAUUSD.DWX`, D1
- proposed companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade a fixed six-older versus six-newer Mann-Whitney location shift
  in twelve synchronized completed monthly gold-minus-silver log ratios at
  inclusive `U_new>=24` or `U_new<=12`

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
   does not establish one constant equilibrium or universal mean reversion.
2. `strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md`,
   SHA-256
   `8D42ED6DF1415B6EDF7FF29AE9349BCA576F0F66204A8021E2E0B8D73B0AEDE0`.
   It preserves H. B. Mann and D. R. Whitney's named 1947 peer-reviewed
   method record and complete pinned R Core `stats::wilcox.test` source and
   manual files from public `wch/r-source` commit
   `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. The exact no-tie statistic is
   the first sample's combined rank sum less its minimum possible rank sum,
   equivalently its favorable cross-sample pair count. The original 1947
   article body remains outside the complete-read claim.
3. The governed composite packet
   `strategy-seeds/sources/SCHWEIKERT-MANNWHITNEY-CME-XAUXAG-MSHIFT-RV-2026/source.md`,
   SHA-256
   `55563B88BB354B8722E44A88585A17E18625A6CD3C345743A7326A595A25C113`.

The records support a falsifiable paired-metal ratio experiment and exact
two-sample ordinal statistic, not the proposed trading conjunction. The
twelve endpoints, fixed six/six split, thresholds, contrarian direction,
synchronized CFD mapping, equal-notional construction, aggregate fixed-dollar
risk, stops, atomicity, consumed attempt, and lifecycle are disclosed QM
choices.

No source return, alpha, probability, significance, Sharpe ratio, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, decorrelation, or
portfolio-correlation statistic transfers.

## Locked Mechanic

On the first synchronized executable D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before every fallible gate.
2. Reconstruct the latest exactly timestamp-matched XAU/XAG D1 close pair in
   each of the twelve immediately prior consecutive completed broker months;
   reject malformed, stale, nonpositive, nonfinite, or tied ratio history.
3. Form chronological `s[i]=ln(XAU[i])-ln(XAG[i])`. Fix the older block
   `O=s[0..5]` and newer block `N=s[6..11]`. Count
   `U_new=count(N[j]>O[i])` over all 36 cross-block comparisons and prove the
   complementary `U_new+U_old=36` and rank-sum identities.
4. If `U_new>=24`, SELL XAU and BUY XAG. If `U_new<=12`, BUY XAU and SELL
   XAG. Otherwise consume the month flat. No p-value, variable split, maximum
   search, fitted center, fitted scale, endpoint fallback, or magnitude sizing
   exists.
5. Open at most one opposite-side, equal-target-absolute-USD-notional package
   under aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally and use frozen
   `3.5*ATR(20,D1)` hard stops, no targets, and bounded spreads.
6. Submit XAU first and XAG second, retain only a complete valid package,
   close at the next broker-month transition or after forty calendar days,
   and repair orphaned or malformed owned exposure immediately.

Both news axes, legacy news mode, and Friday close are OFF. The thresholds
were fixed before market testing. Exact enumeration of all
`choose(12,6)=924` no-tie assignments gives 182 observations at each tail and
a combined qualification rate of `364/924 = 0.3939393939393939`, or about
4.73 decisions per twelve monthly opportunities under random rank assignment.
This is a density design fact, not a gold/silver probability, significance,
or performance claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: peer-reviewed
  gold/silver relation evidence, official exchange carrier research, a named
  original Mann-Whitney journal record, and complete pinned R Core method
  files. The exact trading conjunction remains explicitly untested.
- R2 `PASS`: clock, synchronization, ratio orientation, fixed block
  membership, strict ties, pair-count/rank-sum identities, integer boundaries,
  contrarian sides, attempt, aggregate risk, atomicity, and lifecycle are
  fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories plus MT5 state supply every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, comparisons, integer
  arithmetic, calendar, ATR, and execution state only; no trained output,
  banned signal method, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,676 EA-registry rows, 1,327 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is
`artifacts/qm5_xauxag_mwilcoxon_shift_rv_preallocation_dedup_20260827.json`.

Manual functional review fixes a different state object from the nearest
neighbors:

- `QM5_41176_wti-mwilcoxon-shift-tr` uses the same fixed-block statistic on
  one outright WTI series, follows the shift, and owns one position. This
  candidate applies it to synchronized gold/silver log ratios, fades the
  shift, and owns an atomic equal-notional two-leg package.
- `QM5_41174_xauxag-mspearman-rv` ranks thirteen ratios and weights every
  endpoint's squared displacement from calendar rank. This candidate uses
  twelve ratios, ignores within-block order, and counts only 36 comparisons
  crossing one prespecified six/six boundary.
- `QM5_41168_xauxag-mcoxstuart-rv` uses fourteen ratios and seven fixed
  half-sample sign comparisons. This candidate compares every newer-block
  observation with every older-block observation and preserves ordinal
  separation magnitude through `U_new`.
- Pettitt scans possible split points for one dominant cumulative-rank-sum
  maximum; this candidate has one prespecified split and never searches or
  maximizes.
- XAU/XAG z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint,
  Theil-Sen, LAD, repeated-median, robust-consensus, path, flow, and calendar
  families calculate different state objects or lifecycles.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly paired-metal ordinal reversion.

For a thirteen-ratio rank path, the candidate uses the latest twelve values.
Path `[11,13,2,4,6,1,3,10,5,7,8,9,12]` gives candidate short-ratio at
`U_new=29`, while the existing thirteen-point Spearman score is flat at
`T=52` and Pettitt's unique maximum lies at edge split `K=2`. Path
`[1,8,3,5,7,11,9,4,2,12,13,6,10]` gives candidate flat at `U_new=20`, while
Spearman qualifies at `T=176`. Path
`[11,10,9,8,3,2,1,13,4,5,6,12,7]` gives candidate short-ratio at the inclusive
`U_new=24` boundary while the Spearman path stays flat.

Verdict:
`CLEAN_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_LOCATION_SHIFT_REVERSION_BASKET`.

## Kill And Safety Boundary

The pre-result density prior is four to eight completed packages per full
post-warm-up year. Q02 must retire the candidate below four in any full year,
at zero trades, with nonpositive governed economics, or on any endpoint,
fixed-split, tie, pair-count, threshold, side, attempt, risk, atomicity, or
lifecycle defect.

Equal target notionals reduce common outright-metal direction but do not prove
beta, factor, market, dollar, volatility, or portfolio neutrality. Unchanged
Q09 alone owns realized overlap. No failed result may be rescued by changing
the sample, split, boundary, direction, hedge construction, risk, hold, or by
adding a filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
