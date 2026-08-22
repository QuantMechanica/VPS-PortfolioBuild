# Q00 Decision - QM5_41103 XAU/XAG Monthly Ratio-Range Migration Reversion

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_xauxag_monthly_ratio_range_migration_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41103_xauxag-mrange-migrate-rv_card.md`.

## Identity

- EA ID: `QM5_41103`, allocated atomically by the governed registry sequence
  and committed at `47b8e7401`;
- slug: `xauxag-mrange-migrate-rv`;
- strategy ID: `SCHWEIKERT-CME-XAUXAG-MRANGE-MIGRATE-RV-2026_S01`;
- source ID: `SCHWEIKERT-CME-XAUXAG-MRANGE-MIGRATE-RV-2026`;
- source authorization: `d947ea184`;
- bounded source extraction: `0aeb42b12`;
- host: exact `XAUUSD.DWX`, D1, slot 0, planned magic `411030000`;
- companion: exact `XAGUSD.DWX`, D1, slot 1, planned magic `411030001`;
  and
- mechanic: fade strict same-direction migration of both endpoints of the
  synchronized daily-close gold/silver log-ratio range from one completed
  calendar month to the next.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41103`, after the registered custom-history admission
check, and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF and drawdown numbers are conservative build-ordering estimates only.
They are not gate evidence, expected-performance promises, or substitutes for
Q02.

## Gate Findings

- R1 `PASS_WITH_MONTHLY_RATIO_RANGE_STATE_TRANSLATION_RISK`: the sole bounded
  child source has named peer-reviewed authors, a DOI, official exchange
  lineage, complete repository packets, and durable hashes. Completed-month
  two-endpoint ratio-range migration is disclosed as an untested QM
  translation.
- R2 `PASS`: exact month arithmetic, first-month clock, two consecutive
  completed synchronized monthly packages, 17-to-23-session bounds, log-ratio
  construction, strict endpoint comparisons, mixed/equality-flat behavior,
  contrarian sides, durable attempt, aggregate fixed risk, hard stops, spreads,
  and lifecycle are mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state provide every
  runtime input. Q02 owns alignment, density, cost, fill, financing, and
  continuous-CFD falsification.
- R4 `PASS`: deterministic timestamp, close, logarithm, comparison, ATR,
  quote, position, deal-history, and terminal-state logic only; no trained
  model, banned signal, external feed, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,592 EA-registry identities,
1,271 repository cards, and 45 Strategy-Wiki nodes and returned `CLEAN`, with
no exact or fuzzy match. The post-allocation scan checked 4,593 registry
identities, 1,271 cards, and 45 Wiki nodes and found only the newly reserved
`QM5_41103` slug and strategy ID as exact self-hits. Manual semantic review
separates the candidate from:

- `QM5_20157_xau-xag-ratio`, whose rolling 60-day ratio z-score and rolling-
  center exit differ from two complete calendar-month range packages;
- `QM5_20161_xauxag-ols-rv`, which fits a rolling residual and hedge
  coefficient rather than using a fixed unit log ratio;
- `QM5_20202_xauxag-rev18`, which ranks eighteen-month per-leg returns;
- `QM5_20254_xauxag-vr-fade`, which combines a daily ratio z-score with a
  robust monthly variance-ratio gate;
- `QM5_41079_xauxag-wclose-extreme-rv`, which ranks the final weekly ratio
  close within one week;
- the `QM5_41066/41075/41076/41077` family, which classifies adjacent weekly
  relative-return signs and magnitudes;
- `QM5_41102_wti-mrange-migrate-mom`, a direct single-WTI continuation rule
  built from monthly highs and lows rather than synchronized two-leg closes;
- `QM5_12533`, whose basket recipe carries an EURJPY/GBPJPY cointegration
  signal; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback under a slow trend filter.

The exact XAU/XAG carrier, two immediate consecutive completed calendar-month
daily-close packages, 17-to-23 synchronized sessions each, strict migration
of both log-ratio range endpoints, equality/mixed flat rule, contrarian sides,
first-new-month entry, durable attempt, equal-notional aggregate fixed risk,
and next-month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_RATIO_RANGE_MIGRATION_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XAU D1 host slot zero and XAG D1 companion slot one under governed
  magic allocations;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- the immediately completed broker-calendar month and its exact parent, each
  containing 17 through 23 unique, timestamp-identical completed sessions;
- `log(XAU close)-log(XAG close)` only, with strict minimum and maximum for
  each complete month and no current-month signal input;
- SELL XAU / BUY XAG only when both newest ratio-range endpoints are strictly
  higher; BUY XAU / SELL XAG only when both are strictly lower;
- every equality, mixed, malformed, unsynchronized, or nonconsecutive state
  flat;
- one persistent `yyyymm` attempt recorded before fallible gates;
- one equal-notional package with at most 20 percent lot-step mismatch,
  aggregate `RISK_FIXED=1000`, frozen `3.5*ATR(20,D1)` per-leg hard stops, no
  target, and 1,500/500-point XAU/XAG spread ceilings;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, basket
  manifest validation, and static Q01 validation before any Q02 handoff.

No current-month price, rolling center, standard deviation, z-score,
regression, fitted hedge coefficient, return rank, migration-distance sizing,
range-width filter, season, weekday, moving average, volatility or volume
gate, event/inventory input, external data, retry, pending entry, target,
trail, scale-in, grid, martingale, pyramid, third-leg hedge, or after-result
rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one exact logical-basket
D1 `RISK_FIXED` backtest set, strict Q01, and one paced Q02 enqueue only if the
governed terminal and host-CPU ceilings permit it. It does not authorize a
manual tester dispatch or terminal control.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong month/session or
ratio-range state, entry at equality or mixed migration, wrong contrarian
side, current-month leakage, repeated attempt, invalid risk mode, missing
stop, broken basket atomicity, wrong month lifecycle, or nondeterminism. Q09
alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or `T_Live` manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
