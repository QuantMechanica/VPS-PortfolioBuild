# Q00 Decision - QM5_41109 XAU/XAG Completed-Month Mean-Median Reversion

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_xauxag_monthly_mean_median_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41109_xauxag-mmean-median-rv_card.md`.

## Identity

- EA ID: `QM5_41109`, allocated by the deterministic registry and committed
  at `f22c701a4`;
- slug: `xauxag-mmean-median-rv`;
- strategy ID: `SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026_S01`;
- source ID: `SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026`;
- source authorization: `4a1957e0c`;
- bounded source extraction: `088014c50`;
- host: exact `XAUUSD.DWX`, D1, slot 0, planned magic `411090000`;
- companion: exact `XAGUSD.DWX`, D1, slot 1, planned magic `411090001`; and
- mechanic: fade the strict signed difference between the arithmetic mean and
  ordinary median of the immediately completed month's synchronized daily
  gold/silver log-ratio closes.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41109` after the registered custom-history admission
check and stamped expected frequency 10/year, PF prior 1.01, drawdown prior 35
percent, and the Q00 reasoning into the card.

The PF, drawdown, and frequency values are conservative build-ordering and
density estimates only. They are not gate evidence, expected-performance
promises, or substitutes for Q02.

## Gate Findings

- R1 `PASS_WITH_MEAN_MEDIAN_TAIL_TRANSLATION_RISK`: the bounded child source
  has named peer-reviewed DOI lineage for a potentially state-dependent
  gold/silver relationship plus official CME ratio-spread carrier material.
  The completed-month internal mean-median state and contrarian map are
  disclosed as untested QM translations.
- R2 `PASS`: exact instruments, first-month clock, immediately completed
  month, 17-to-23 timestamp-identical sessions, log ratio, arithmetic mean,
  odd/even ordinary median, strict comparison, equality-flat behavior,
  contrarian sides, durable attempt, aggregate fixed risk, notional tolerance,
  atomic repair, hard stops, spreads, and lifecycle are mechanical.
- R3 `PASS_WITH_CFD_BASIS_AND_RESIDUAL_BETA_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 history plus MT5 state supplies every
  runtime input. Q02 owns synchronization, density, costs, fills, financing,
  continuous-CFD basis, and residual common-metal exposure.
- R4 `PASS`: deterministic timestamp, sorting, logarithm, arithmetic, ATR,
  quote, position, deal-history, and terminal-state logic only; no trained
  signal, banned indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,598 EA-registry identities,
1,277 repository cards, and 45 Strategy-Wiki nodes. It found no exact or
fuzzy identity. Manual semantic review separates the candidate from:

- `QM5_41104_xauxag-mmedian-shift-rv`, which compares ordinary medians across
  two non-overlapping months rather than mean versus median inside one month;
- `QM5_41103_xauxag-mrange-migrate-rv`, which compares monthly minimum and
  maximum endpoints and calculates neither mean nor median;
- `QM5_20263_xauxag-mad-rv`, which uses a rolling median/MAD standardized
  threshold crossing and rolling-center exit;
- `QM5_20268_xauxag-qtail-rv`, which uses frozen empirical deciles over 126
  observations and a central-band exit;
- `QM5_20233_xauxag-skew-rank`, which estimates each metal's own standardized
  return skewness over twelve months and ranks the legs;
- `QM5_20157_xau-xag-ratio`, which uses a rolling ratio mean/standard-
  deviation z-score and an intramonth center exit;
- `QM5_20057_xauxag-xmom1`, which follows two month-end relative returns;
- `QM5_12533`, whose validated logical-basket recipe carries an EURJPY/GBPJPY
  rolling cointegration signal; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback beneath a slow trend filter.

The exact XAU/XAG carrier, one synchronized immediately completed calendar
month, 17-to-23 sessions, arithmetic mean, ordinary odd/even median, strict
internal comparison, contrarian paired sides, equality-flat rule, consumed
monthly attempt, equal-notional aggregate fixed-risk package, and next-month
exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_INTERNAL_MEAN_MEDIAN_TAIL_BIAS_REVERSION`.

The post-allocation scan checked 4,599 registry identities, 1,278 cards, and
45 Wiki nodes. Its only exact matches are the newly reserved `QM5_41109` slug
and strategy ID in their own registry row; no foreign identity or fuzzy
collision exists. Evidence:
`artifacts/qm5_41109_xauxag_mmean_median_rv_postallocation_dedup_20260822.json`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XAU host and XAG companion D1 symbols under slots zero and one;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- the immediately completed month containing exactly 17 through 23 unique,
  timestamp-identical, positive finite close pairs inside a 40-bar buffer;
- `r=log(XAU close)-log(XAG close)` for every accepted pair;
- arithmetic mean from all values and ordinary median from a sorted copy,
  using the center value for odd samples and the exact two-center arithmetic
  mean for even samples;
- SELL XAU/BUY XAG only when `mean>median`, BUY XAU/SELL XAG only when
  `mean<median`, with equality and invalid states flat;
- one persistent decision `yyyymm` attempt recorded before fallible gates;
- one aggregate `RISK_FIXED=1000` budget, frozen `3.5*ATR(20,D1)` per-leg hard
  stops, one-to-one notional target, and a 20-percent mismatch ceiling;
- XAU 1,500-point and XAG 500-point spread ceilings, both news axes OFF,
  Friday close OFF, atomic second-leg rollback, next-month closure, and a
  forty-day stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-month signal price, second completed-month comparison, standard
deviation, MAD, quantile, skewness estimator, regression, fitted hedge ratio,
epsilon or magnitude threshold, signal-strength sizing, volatility/volume/
season/weekday/event/inventory filter, moving average, external data, retry,
pending entry, target, trail, scale-in, grid, martingale, pyramid, third hedge,
or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one exact D1
`RISK_FIXED` logical-basket backtest set, strict Q01, and one paced logical-
basket Q02 enqueue only if the governed terminal and host-CPU ceilings permit
it. It does not authorize a manual tester dispatch or terminal control.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong month or sample,
asynchrony, incorrect mean or median, entry at equality, wrong paired side,
current-month leakage, repeated attempt, invalid risk/notional mode, missing
stop, broken atomicity, wrong month lifecycle, or nondeterminism. Q09 alone
may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
