# Q00 Decision - QM5_41112 XAU/XAG Completed-Month Daily Relative-Sign Breadth Reversion

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_xauxag_monthly_daily_relative_sign_breadth_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41112_xauxag-mdaybreadth-rv_card.md`.

## Identity

- EA ID: `QM5_41112`, allocated atomically in the deterministic registry and
  committed at `f6ba77e4a`;
- slug: `xauxag-mdaybreadth-rv`;
- strategy ID: `SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026_S01`;
- source ID: `SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026`;
- source authorization: `6b0270433`;
- bounded source extraction: `191e20d0f`;
- host: exact `XAUUSD.DWX`, D1, slot 0, planned magic `411120000`;
- companion: exact `XAGUSD.DWX`, D1, slot 1, planned magic `411120001`; and
- mechanic: fade the immediately completed month's endpoint ratio displacement
  only when a strict majority of all its synchronized daily relative-return
  signs agrees.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41112` after the registered custom-history admission
check and stamped expected frequency 8/year, PF prior 1.01, drawdown prior 35
percent, and the Q00 reasoning into the card.

The PF, drawdown, and frequency numbers are conservative build-ordering
estimates only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate Findings

- R1 `PASS_WITH_MONTHLY_DAILY_BREADTH_TRANSLATION_RISK`: the bounded child
  source preserves named peer-reviewed DOI and official-exchange lineage. The
  within-month daily relative-sign breadth fade is disclosed as an untested QM
  translation.
- R2 `PASS`: exact synchronized month clock, two consecutive completed
  17-to-23-session packages, parent-final ratio anchor, every newest-month
  daily relative-return sign, equality-inclusive denominator, strict majority,
  endpoint agreement, inverse pair sides, durable attempt, aggregate risk,
  hard stops, atomicity, spread gates, and lifecycle are mechanical.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state provide every
  runtime input. Q02 owns history, holiday attrition, density, cost, fill,
  financing, and continuous-CFD falsification.
- R4 `PASS`: deterministic timestamp, completed price, logarithm, comparison,
  counting, ATR, quote, position, deal-history, and terminal-state logic only;
  no trained signal, banned indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,608 EA-registry identities,
1,280 repository cards, and 45 Strategy-Wiki nodes and found no exact or fuzzy
candidate match. Manual semantic review separates the candidate from:

- `QM5_41085_xauxag-wdaybreadth-rv`, whose exact five-session week,
  four-of-five rule, and one-week hold differ from two complete calendar
  months, every newest-month relative return, strict majority, and next-month
  hold;
- `QM5_20275_gsr-runfade`, which classifies a fixed six-return rolling run;
- rolling-center, residual, robust-score, and tail cards `QM5_12577`,
  `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`;
- monthly range/location/distribution cards `QM5_41103`, `QM5_41104`,
  `QM5_41109`, and `QM5_41110`;
- session/overnight-flow cards `QM5_41030`, `QM5_41040`, and `QM5_41057`;
- `QM5_41111_wti-mdaybreadth-mom`, which follows one outright WTI carrier
  rather than fading a synchronized two-metal relative move; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, every newest-
month relative-return sign, equality-inclusive denominator, strict majority,
same-sign endpoint displacement, contrarian package side, consumed monthly
attempt, equal-notional aggregate-risk package, and next-month exit are jointly
load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_RELATIVE_SIGN_MAJORITY_NET_AGREEMENT_REVERSION_AFTER_FAMILY_REVIEW`.

The post-allocation scan checked 4,609 registry identities, 1,280 cards, and 45
Wiki nodes. Its only exact hits are the newly reserved `QM5_41112` slug and
strategy ID; no foreign identity collision exists. Evidence:
`artifacts/qm5_41112_xauxag_mdaybreadth_rv_postallocation_dedup_20260822.json`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XAU host, XAG companion, D1, and slots zero/one under governed magic
  allocation;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- the two immediately preceding consecutive calendar months, each containing
  17 through 23 unique synchronized close pairs;
- the parent chronological final log ratio as the first return anchor and
  every newest-month close pair included exactly once;
- positive, negative, and equal relative returns counted strictly, with equal
  returns retained in `n`;
- SELL XAU/BUY XAG only when `2*positive>n` and newest final ratio is above the
  parent anchor, BUY XAU/SELL XAG only when `2*negative>n` and it is below, and
  every tie, non-majority, equality, disagreement, or invalid state flat;
- one persistent decision `yyyymm` attempt recorded before fallible gates;
- one aggregate `RISK_FIXED=1000` equal-notional package, frozen
  `3.5*ATR(20,D1)` per-leg hard stops, no target, and 1,500/500-point XAU/XAG
  spread ceilings;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks,
  `basket_manifest.json`, and static Q01 validation before Q02 handoff.

No current-month signal price, relative-return magnitude weighting, optimized
majority fraction, equality deletion, fitted center, regression, signal-
strength sizing, volatility/volume/season/weekday/event filter, external data,
retry, pending entry, target, trail, scale-in, grid, martingale, pyramid,
overlay hedge, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical D1
`RISK_FIXED` basket backtest set, strict Q01, and one paced Q02 enqueue only if
the governed terminal and whole-host CPU ceilings permit it. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong month/session state,
asynchronous or duplicated endpoints, wrong relative-return orientation,
equality removed from the denominator, accepted majority equality,
majority/net disagreement, current-month leakage, repeated attempt, invalid
risk mode, incomplete package, missing stop, wrong month lifecycle, or
nondeterminism. Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or `T_Live` manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
