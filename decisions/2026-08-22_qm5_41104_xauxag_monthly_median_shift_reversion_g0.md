# Q00 Decision - QM5_41104 XAU/XAG Monthly Ratio-Median Shift Reversion

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_xauxag_monthly_median_shift_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41104_xauxag-mmedian-shift-rv_card.md`.

## Identity

- EA ID: `QM5_41104`, allocated atomically by the governed registry sequence
  and committed at `54c2d3df6`;
- slug: `xauxag-mmedian-shift-rv`;
- strategy ID: `SCHWEIKERT-CME-XAUXAG-MMEDIAN-SHIFT-RV-2026_S01`;
- source ID: `SCHWEIKERT-CME-XAUXAG-MMEDIAN-SHIFT-RV-2026`;
- source authorization: `65f571311`;
- bounded source extraction: `ceebb96ea`;
- host: exact `XAUUSD.DWX`, D1, slot 0, planned magic `411040000`;
- companion: exact `XAGUSD.DWX`, D1, slot 1, planned magic `411040001`;
  and
- mechanic: fade strict displacement between the ordinary sample medians of
  synchronized daily gold/silver log ratios in the two immediately completed
  calendar months.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41104`, after the registered custom-history admission
check, and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF and drawdown numbers are conservative build-ordering estimates only.
They are not gate evidence, expected-performance promises, or substitutes for
Q02.

## Gate Findings

- R1 `PASS_WITH_MONTHLY_MEDIAN_STATE_TRANSLATION_RISK`: the sole bounded child
  source has named peer-reviewed authors, a DOI, official exchange lineage,
  complete repository packets, and durable hashes. Comparing two completed-
  month ratio medians is disclosed as an untested QM translation.
- R2 `PASS`: exact month arithmetic, first-month clock, two consecutive
  completed synchronized monthly packages, 17-to-23-session bounds, log-ratio
  construction, exact odd/even median arithmetic, strict comparison, equality-
  flat behavior, contrarian sides, durable attempt, aggregate fixed risk, hard
  stops, spreads, and lifecycle are mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state provide every
  runtime input. Q02 owns alignment, density, cost, fill, financing, and
  continuous-CFD falsification.
- R4 `PASS`: deterministic timestamp, close, logarithm, sorting, arithmetic,
  comparison, ATR, quote, position, deal-history, and terminal-state logic
  only; no trained signal, banned indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,593 EA-registry identities,
1,272 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and raised one expected family-level fuzzy match to `QM5_41103`. Manual
semantic review separates the candidate from:

- `QM5_41103_xauxag-mrange-migrate-rv`, which requires the minimum and maximum
  of the newest ratio sample both to migrate in the same direction from the
  parent endpoints. `QM5_41104` ignores range endpoints and compares one
  ordinary median per completed month, so the signal state can exist with
  overlapping ranges or mixed endpoint migration;
- `QM5_20263_xauxag-mad-rv`, whose rolling median/MAD score, standardized
  threshold, fresh-cross gate, and rolling-center exit differ from two bounded
  non-overlapping calendar samples, no scale, and a month lifecycle;
- `QM5_20057_xauxag-xmom1`, which follows the relative month-end winner rather
  than fading robust ratio-location displacement built from all synchronized
  daily closes;
- `QM5_20157_xau-xag-ratio`, which uses a rolling mean/standard-deviation score
  and rolling-center exit;
- `QM5_20161_xauxag-ols-rv`, which fits a rolling residual and hedge
  coefficient;
- `QM5_41039_xauxag-mflow-div`, which compares overnight and session-return
  components rather than ratio-location samples;
- `QM5_12533`, whose basket recipe carries an EURJPY/GBPJPY cointegration
  signal; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback under a slow trend filter.

The exact XAU/XAG carrier, two immediate consecutive completed calendar-month
daily-close packages, 17-to-23 synchronized sessions each, independent
ordinary sample medians, strict comparison, equality-flat rule, contrarian
sides, first-new-month entry, durable attempt, equal-notional aggregate fixed
risk, and next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_AFTER_EXPECTED_MONTHLY_RATIO_FAMILY_FUZZY_REVIEW`.

The post-allocation scan checked 4,594 registry identities, 1,273 cards, and
45 Wiki nodes and found only the newly reserved `QM5_41104` slug and strategy
ID as exact self-hits. It found no foreign identity collision. Evidence:
`artifacts/qm5_xauxag_mmedian_shift_rv_postallocation_dedup_20260822.json`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XAU D1 host slot zero and XAG D1 companion slot one under governed
  magic allocations;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- the immediately completed broker-calendar month and its exact parent, each
  containing 17 through 23 unique, timestamp-identical completed sessions;
- `log(XAU close)-log(XAG close)` only, sorted independently within each month,
  with the center element for odd counts and mean of the two center elements
  for even counts;
- SELL XAU / BUY XAG only when the newest median is strictly higher, and BUY
  XAU / SELL XAG only when it is strictly lower;
- equality, malformed, unsynchronized, or nonconsecutive state flat;
- one persistent `yyyymm` attempt recorded before fallible gates;
- one equal-notional package with at most 20 percent lot-step mismatch,
  aggregate `RISK_FIXED=1000`, frozen `3.5*ATR(20,D1)` per-leg hard stops, no
  target, and 1,500/500-point XAU/XAG spread ceilings;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, basket
  manifest validation, and static Q01 validation before any Q02 handoff.

No current-month price, rolling center, mean, standard deviation, MAD scale,
z-score, regression, fitted hedge coefficient, displacement threshold, range
endpoint, return rank, signal-strength sizing, season, weekday, moving average,
volatility or volume gate, event/inventory input, external data, retry, pending
entry, target, trail, scale-in, grid, martingale, pyramid, third-leg hedge, or
after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one exact logical-basket
D1 `RISK_FIXED` backtest set, strict Q01, and one paced Q02 enqueue only if the
governed terminal and host-CPU ceilings permit it. It does not authorize a
manual tester dispatch or terminal control.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong month/session or
median state, entry at equality, wrong contrarian side, current-month leakage,
repeated attempt, invalid risk mode, missing stop, broken basket atomicity,
wrong month lifecycle, or nondeterminism. Q09 alone may establish realized
book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or `T_Live` manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
