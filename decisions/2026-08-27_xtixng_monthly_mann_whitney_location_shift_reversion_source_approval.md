# XTI/XNG Monthly Mann-Whitney Location-Shift Reversion - Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE_AFTER_DECLARED_FUZZY_REVIEW` for one bounded V5
Strategy Card, deterministic EA-ID allocation, one branch-only non-live build,
strict Q01 validation, and one paced non-live logical-basket Q02 enqueue.
Enqueue does not authorize a manual tester dispatch or work above the active
factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission requests one new structural,
low-frequency commodity edge outside the directional XAU/SP500/NDX/XNG book,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xtixng-mwilcoxon-rv`
- proposed strategy ID:
  `VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026_S01`
- proposed source ID: `VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- proposed companion/traded slot 1: `XNGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade an inclusive fixed-block Mann-Whitney location shift between
  six older and six newer synchronized oil-minus-gas log-ratio endpoints

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
2. `strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md`,
   SHA-256
   `8D42ED6DF1415B6EDF7FF29AE9349BCA576F0F66204A8021E2E0B8D73B0AEDE0`.
   It preserves complete-read peer-reviewed WTI trading lineage, the named
   Mann-Whitney journal record, and complete pinned R Core
   `stats::wilcox.test` source and manual. The exact operative statistic is a
   fixed-split rank sum or equivalent favorable cross-block pair count.
3. The governed composite packet
   `strategy-seeds/sources/VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026/source.md`.

The sources support a falsifiable paired-energy location-shift experiment and
the exact non-parametric statistic, not the proposed trading conjunction. The
twelve endpoints, six/six split, strict ties, inclusive boundaries,
contrarian direction, continuous-CFD mapping, equal-notional construction,
aggregate fixed-dollar risk, stops, atomicity, consumed attempt, and lifecycle
are disclosed QM choices.

No source return, alpha, probability, significance, Sharpe ratio, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, decorrelation, or
portfolio-correlation statistic transfers.

## Locked Mechanic

On the first synchronized executable D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before every fallible gate.
2. Reconstruct the latest exactly timestamp-matched XTI/XNG D1 close pair in
   each of the twelve immediately prior consecutive completed broker months;
   reject malformed, stale, or tied ratio history.
3. Form chronological `s[i]=ln(XTI[i])-ln(XNG[i])`; split once into older
   `s[0..5]` and newer `s[6..11]`; count all 36 strict cross-block pairs;
   prove `U_new+U_old=36` and `W_new-21=U_new`.
4. At `U_new>=24`, SELL XTI and BUY XNG. At `U_new<=12`, BUY XTI and SELL
   XNG. Otherwise consume the month flat. No p-value, variable split, maximum
   search, fitted hedge ratio, rolling center, or fallback exists.
5. Open at most one opposite-side equal-target-absolute-USD-notional package
   under aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally and use a frozen
   `3.5*ATR(20,D1)` hard stop per leg, no target, and bounded spreads.
6. Submit XTI first and XNG second, retain only a complete valid package,
   close at the next broker-month transition or after forty calendar days,
   and repair orphaned or malformed owned exposure immediately.

Both news axes, legacy news mode, and Friday close are OFF. The fixed 12/24
boundaries were locked before market testing from exact combinatorial density,
not imported as p-values.

## Reputable-Source Criteria

- R1 `PASS_WITH_RELATION_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete U.S.
  government oil/gas research, complete peer-reviewed oil/gas evidence with
  adverse findings, a named peer-reviewed Mann-Whitney record, and complete
  pinned R Core method files. The exact conjunction remains untested.
- R2 `PASS`: clock, synchronization, ratio orientation, fixed blocks, ties,
  every comparison, U identities, thresholds, contrarian sides, attempt,
  aggregate risk, atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XTI/XNG D1 histories plus MT5 state supply every runtime input.
- R4 `PASS`: deterministic prices, comparisons, integer arithmetic, calendar,
  and execution state only; no trained output, banned signal method, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,677 EA-registry identities, 1,328
card files, and 45 Strategy Wiki nodes. It found no exact match and returned
two declared fuzzy neighbors. Evidence is
`artifacts/qm5_xtixng_mwilcoxon_rv_preallocation_dedup_20260827.json`,
SHA-256
`F675A8FA910297733C86749A823355560FE9DBB9E858D7D7C5B5D1BC8B00911B`.

Research/QB functional review resolves both instead of renaming the candidate:

- `QM5_41177_xauxag-mwilcoxon-shift-rv` applies the same statistic to a
  precious-metal ratio under gold/silver relationship evidence. This
  candidate trades the separately sourced weak oil/gas relation, energy
  carrier, spread constraints, and energy-specific basis/atomicity risks.
- `QM5_41175_xtixng-mpettitt-rv` shares the paired-energy carrier but scans
  every split on thirteen ratios and requires one central maximum. This
  candidate fixes one six/six split on twelve ratios, counts only the 36
  cross-block comparisons, and uses inclusive U boundaries. It never searches
  for or maximizes a change point.
- `QM5_20237_xtixng-ecm-rv` fits a 252-D1 trend-augmented OLS residual and
  z-score crossing. This rule performs no regression, estimates no beta, and
  uses twelve monthly endpoints.
- Existing fixed ratio, return-spread, channel, momentum, carry, calendar,
  tail, volatility, and factor-rank baskets calculate different state objects.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly paired-energy ordinal reversion.

Fixed rank fixtures in the composite packet show Mann-Whitney short while
Pettitt is flat, Mann-Whitney flat while Pettitt qualifies, and an inclusive
Mann-Whitney boundary where Pettitt takes the opposite ratio side.

Verdict:
`CLEAN_AFTER_DECLARED_FUZZY_REVIEW_XTIXNG_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_RATIO_REVERSION`.

## Kill And Safety Boundary

The pre-result density prior is four to eight completed packages per full
post-warm-up year. Q02 must retire the candidate below four in any full year,
at zero trades, with nonpositive governed economics, or on any endpoint,
fixed-block, tie, U-identity, side, attempt, risk, atomicity, or lifecycle
defect.

Equal target notionals reduce outright energy direction but do not prove beta,
factor, market, dollar, or portfolio neutrality. Unchanged Q09 alone owns
realized overlap. No failed result may be rescued by changing the sample,
split, threshold, direction, hedge construction, risk, hold, or adding a
filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
