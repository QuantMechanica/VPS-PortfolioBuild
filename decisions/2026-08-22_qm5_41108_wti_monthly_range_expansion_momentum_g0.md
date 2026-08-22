# Q00 Decision - QM5_41108 WTI Completed-Month Range-Expansion Momentum

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_wti_monthly_range_expansion_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41108_wti-mrange-expansion-mom_card.md`.

## Identity

- EA ID: `QM5_41108`, allocated in the deterministic registry and committed
  at `2de3e2cc9`;
- slug: `wti-mrange-expansion-mom`;
- strategy ID: `MOP-WTI-MRANGE-EXPANSION-MOM-2026_S01`;
- source ID: `MOP-WTI-MRANGE-EXPANSION-MOM-2026`;
- source authorization: `de681718f`;
- bounded source extraction: `a9a279cff`;
- host: exact `XTIUSD.DWX`, D1, slot 0, planned magic `411080000`; and
- mechanic: follow the immediately completed month's open-to-close body only
  when its aggregate high-low range is strictly wider than its consecutive
  parent month's range.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41108` after the registered custom-history admission
check and stamped expected frequency 6/year, PF prior 1.01, drawdown prior 30
percent, and the Q00 reasoning into the card.

The PF, drawdown, and frequency numbers are conservative build-ordering
estimates only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate Findings

- R1 `PASS_WITH_MONTHLY_RANGE_EXPANSION_TRANSLATION_RISK`: the bounded child
  source has named peer-reviewed authors, a DOI, complete-paper evidence, a
  durable retrieval hash, and explicit WTI membership. Completed-month range
  expansion and body-side qualification are disclosed as untested QM
  translations.
- R2 `PASS`: exact label normalization, month arithmetic, first-month clock,
  two consecutive completed monthly packages, 17-to-23-session bounds,
  chronological opens/closes, aggregate highs/lows, strict range comparison,
  equality-flat behavior, own-body direction, durable attempt, fixed risk,
  hard stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5 state provides every runtime input. Q02
  owns label, density, cost, fill, financing, and continuous-CFD
  falsification.
- R4 `PASS`: deterministic timestamp, completed OHLC, comparison, ATR, quote,
  position, deal-history, and terminal-state logic only; no trained signal,
  banned indicator, external feed, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,597 EA-registry identities,
1,276 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and raised only expected monthly/weekly body-family fuzzy matches. Manual
semantic review separates the candidate from:

- `QM5_41102_wti-mrange-migrate-mom`, whose absolute endpoint migration rule
  excludes opens and closes and may qualify while its range narrows;
- `QM5_41106_wti-mbody-dominance-mom`, which reads one month and compares its
  body with its own range rather than comparing two monthly ranges;
- `QM5_41107_wti-minside-body-mom`, whose strict containment necessarily
  makes the newest range narrower and is therefore disjoint from expansion;
- `QM5_41068_wti-waccel-mom`, which compares weekly close-return magnitudes
  and holds one week;
- weekly range-migration and outside-settlement cards, whose clock and state
  equations differ;
- `QM5_20187_wti-tsmom1m`, which follows every nonzero two-close monthly
  return without a completed-range condition or newest-month first open;
- `QM5_1385_demark-td-range-expansion-h4`, a DeMark H4 sequential setup; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback beneath a slow trend filter.

The exact WTI carrier, two consecutive completed calendar-month packages,
17-to-23 sessions each, strict `(H0-L0)>(H1-L1)`, newest first-open/final-
close body side, equality-flat rules, first-new-month entry, durable attempt,
fixed risk, and next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_RANGE_EXPANSION_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

The post-allocation scan checked 4,598 registry identities, 1,276 cards, and
45 Wiki nodes and found only the newly reserved `QM5_41108` slug and strategy
ID as exact self-hits. It found no foreign identity collision. Evidence:
`artifacts/qm5_41108_wti_mrange_expansion_mom_postallocation_dedup_20260822.json`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 host and slot zero under the governed magic allocation;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- uniform raw or `+1`-day energy-label normalization;
- the immediately completed month and consecutive parent, each containing 17
  through 23 unique completed sessions;
- chronological opens/closes, aggregate highs/lows, finite positive ranges,
  and exact strict `(H0-L0)>(H1-L1)`;
- BUY only when expansion holds and `C0>O0`, SELL only when it holds and
  `C0<O0`, with equal/narrower/invalid/doji states flat;
- one persistent decision `yyyymm` attempt recorded before fallible gates;
- one `RISK_FIXED=1000` position, frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-month signal price, current-month breakout, minimum expansion
ratio, endpoint-migration direction, containment gate, body-share or close-
location threshold, signal-strength sizing, volatility/volume/season/weekday/
event/inventory filter, moving average, regression, external data, retry,
pending entry, target, trail, scale-in, grid, martingale, pyramid, hedge, or
after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one exact D1 `RISK_FIXED`
backtest set, strict Q01, and one paced Q02 enqueue only if the governed
terminal and host-CPU ceilings permit it. It does not authorize a manual
tester dispatch or terminal control.

Q02 must retire on zero positions, fewer than five completed positions per
full post-warm-up year, nonpositive governed economics, wrong label/month/
session or range state, entry at range equality, wrong side, current-month
leakage, repeated attempt, invalid risk mode, missing stop, wrong month
lifecycle, or nondeterminism. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
