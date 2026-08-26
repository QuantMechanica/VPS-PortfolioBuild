# XTI/XNG Monthly Pettitt Ratio Reversion - Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue does not authorize a
manual tester dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission requests one new structural,
low-frequency commodity edge outside the directional XAU/SP500/NDX/XNG book,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xtixng-mpettitt-rv`
- proposed strategy ID:
  `VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026_S01`
- proposed source ID: `VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- proposed companion/traded slot 1: `XNGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade one unique central Pettitt rank-sum change point in thirteen
  completed synchronized oil-minus-gas log-ratio endpoints

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
   `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`.
   It preserves a complete U.S. EIA report by Villar and Joutz, a complete
   peer-reviewed *Energy Journal* paper by Ramberg and Parsons, and explicit
   adverse modern EIA evidence. The record supports a time-varying, weak
   oil/gas relation and error-correction experiment; it rejects a permanent
   fixed price ratio.
2. `strategy-seeds/sources/MOP-PETTITT-WTI-MSHIFT-TREND-2026/source.md`,
   SHA-256
   `A80A6F6C87C7FB1D5D9E4911A36C5CAFE7005319F4C844F0550B697577BA3C98`.
   It preserves A. N. Pettitt's named peer-reviewed record and complete pinned
   CRAN `trend` 1.1.7 method files. The exact method ranks the complete sample,
   calculates every cumulative rank sum, and locates every split attaining
   the maximum absolute value.
3. The governed composite packet
   `strategy-seeds/sources/VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026/source.md`.

The sources support a falsifiable paired-energy change-point experiment and
the exact non-parametric statistic, not the proposed trading conjunction. The
thirteen endpoints, central split band, contrarian direction, continuous-CFD
mapping, equal-notional construction, aggregate fixed-dollar risk, stops,
atomicity, consumed attempt, and lifecycle are disclosed QM choices.

No source return, alpha, probability, significance, Sharpe ratio, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, decorrelation, or
portfolio-correlation statistic transfers.

## Locked Mechanic

On the first synchronized executable D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before every fallible gate.
2. Reconstruct the latest exactly timestamp-matched XTI/XNG D1 close pair in
   each of the thirteen immediately prior consecutive completed broker
   months; reject malformed, stale, or tied ratio history.
3. Form chronological `s[i]=ln(XTI[i])-ln(XNG[i])`, assign strict ranks
   `R[i]`, and calculate `U[k]=2*sum(R[0..k-1])-14*k` for `k=1..12`.
   Require one and only one split attaining `U*=max(abs(U[k]))`, require
   `4<=K<=9`, and prove the permutation, range, and parity invariants.
4. If `U[K]<0`, SELL XTI and BUY XNG because the later ratio regime is
   higher. If `U[K]>0`, BUY XTI and SELL XNG because the later ratio regime is
   lower. Otherwise consume the month flat. No p-value, fitted hedge ratio,
   rolling center, or fallback exists.
5. Open at most one opposite-side, equal-target-absolute-USD-notional package
   under aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally and use a frozen
   `3.5*ATR(20,D1)` hard stop on each leg, no target, and bounded spreads.
6. Submit XTI first and XNG second, retain only a complete valid package,
   close at the next broker-month transition or after forty calendar days,
   and repair orphaned or malformed owned exposure immediately.

Both news axes, legacy news mode, and Friday close are OFF. No significance
threshold is imported. The central split band and uniqueness rule were fixed
before market testing as density and lifecycle choices.

## Reputable-Source Criteria

- R1 `PASS_WITH_RELATION_AND_METHOD_TRANSLATION_RISK`: complete U.S.
  government oil/gas research, a complete peer-reviewed oil/gas paper with
  adverse evidence, a named peer-reviewed Pettitt record, and complete pinned
  CRAN method files. The exact trading conjunction remains untested.
- R2 `PASS`: clock, synchronization, ratio orientation, ranks, every
  cumulative sum, unique central split, contrarian sides, attempt, aggregate
  risk, atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 histories plus MT5 state supply every runtime input.
- R4 `PASS`: deterministic prices, ranks, integer arithmetic, calendar, and
  execution state only; no trained output, banned signal method, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,674 EA-registry rows, 1,325 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_xtixng_mpettitt_rv_preallocation_dedup_20260827.json`,
SHA-256
`03FECB559F3EC214799DDF8D7A570D7479B23A8C6C26C652EFDF1620174DBACB`.

Manual functional review fixes a new state object and lifecycle:

- `QM5_41172_wti-mpettitt-shift-tr` ranks one outright WTI series, follows the
  post-shift direction, and owns one position. This candidate ranks a
  synchronized oil/gas ratio, fades the post-shift direction, and owns an
  atomic equal-notional two-leg package.
- `QM5_20237_xtixng-ecm-rv` fits a 252-D1 trend-augmented OLS residual and
  trades a z-score crossing. This rule performs no regression, estimates no
  beta, and uses thirteen completed monthly endpoints.
- `QM5_12578_eia-oilgas-ratio`, `QM5_12608_eia-oilgas-breakout`, and
  `QM5_12840_xti-xng-rspread` use rolling level/return centers, scale, or
  channels rather than a unique cumulative-rank-sum change point.
- XTI/XNG momentum, carry, same-calendar, tail, volatility, factor-rank, and
  weekday baskets calculate different state objects and use different clocks.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly paired-energy rank-change reversion.

Verdict:
`CLEAN_XTIXNG_MONTHLY_PETTITT_UNIQUE_CENTRAL_RATIO_SHIFT_CONTRARIAN_BASKET`.

## Kill And Safety Boundary

The pre-result density prior is four to eight completed packages per full
post-warm-up year. Q02 must retire the candidate below four in any full year,
at zero trades, with nonpositive governed economics, or on any endpoint,
rank, split, side, attempt, risk, atomicity, or lifecycle defect.

Equal target notionals reduce outright energy direction but do not prove
beta, factor, market, dollar, or portfolio neutrality. Unchanged Q09 alone
owns realized overlap. No failed result may be rescued by changing the
sample, rank rule, central band, direction, hedge construction, risk, hold, or
by adding a filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
