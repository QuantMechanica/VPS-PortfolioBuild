# Q00 Decision - QM5_41111 WTI Completed-Month Daily-Sign Breadth Momentum

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_wti_monthly_daily_sign_breadth_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41111_wti-mdaybreadth-mom_card.md`.

## Identity

- EA ID: `QM5_41111`, allocated in the deterministic registry and committed
  at `733571b9d`;
- slug: `wti-mdaybreadth-mom`;
- strategy ID: `MOP-WTI-MDAYBREADTH-MOM-2026_S01`;
- source ID: `MOP-WTI-MDAYBREADTH-MOM-2026`;
- source authorization: `12ce51468`;
- bounded source extraction: `21d97081f`;
- host: exact `XTIUSD.DWX`, D1, slot 0, planned magic `411110000`; and
- mechanic: follow the immediately completed month's endpoint return only
  when a strict majority of all its daily close-to-close returns has the same
  sign.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41111` after the registered custom-history admission
check and stamped expected frequency 8/year, PF prior 1.01, drawdown prior 30
percent, and the Q00 reasoning into the card.

The PF, drawdown, and frequency numbers are conservative build-ordering
estimates only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate Findings

- R1 `PASS_WITH_MONTHLY_DAILY_BREADTH_TRANSLATION_RISK`: the bounded child
  source has named peer-reviewed authors, a DOI, complete-paper evidence, a
  durable retrieval hash, and explicit WTI membership. Within-month daily
  breadth is disclosed as an untested QM translation.
- R2 `PASS`: exact label normalization, month arithmetic, first-month clock,
  two consecutive completed monthly packages, 17-to-23-session bounds,
  parent-final-close anchor, all newest-month close returns, strict sign
  orientation, flat-return denominator, strict majority, endpoint agreement,
  durable attempt, fixed risk, hard stop, spread, and lifecycle are
  mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5 state provides every runtime input. Q02
  owns label, density, cost, fill, financing, and continuous-CFD
  falsification.
- R4 `PASS`: deterministic timestamp, completed close, comparison, ATR,
  quote, position, deal-history, and terminal-state logic only; no trained
  signal, banned indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,605 EA-registry identities,
1,279 repository cards, and 45 Strategy-Wiki nodes and found no exact or fuzzy
candidate match. Manual semantic review separates the candidate from:

- `QM5_41084_wti-wdaybreadth-mom`, whose five-session weekly package, weekly
  renewal, and one-week hold differ from two complete calendar months and a
  next-month hold;
- `QM5_20244_wti-trend-sign`, which counts twelve monthly signs instead of
  daily signs inside the immediately completed month;
- `QM5_20187_wti-tsmom1m`, which follows every nonzero one-month return
  without daily-path confirmation;
- `QM5_41105_wti-mclose-location-mom` and
  `QM5_41106_wti-mbody-dominance-mom`, which use completed-month OHLC geometry
  rather than daily sign breadth;
- `QM5_41107_wti-minside-body-mom` and
  `QM5_41108_wti-mrange-expansion-mom`, which compare monthly OHLC packages;
- `QM5_20273_wti-signrun-tr`, which finds a longest run among twelve monthly
  returns rather than a strict daily majority in one month; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback.

The exact WTI carrier, two consecutive completed calendar-month packages,
17-to-23 sessions each, parent-final-close anchor, every newest-month daily
return, strict majority, same-sign endpoint return, equality-flat rules,
first-new-month entry, durable attempt, fixed risk, and next-month exit are
jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_SIGN_MAJORITY_NET_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

The post-allocation scan checked 4,606 registry identities, 1,279 cards, and
45 Wiki nodes. Its only exact hits are the newly reserved `QM5_41111` slug and
strategy ID; no foreign identity collision exists. Evidence:
`artifacts/qm5_41111_wti_mdaybreadth_mom_postallocation_dedup_20260822.json`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 host and slot zero under the governed magic allocation;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- uniform raw or `+1`-day energy-label normalization;
- the immediately completed month and consecutive parent, each containing 17
  through 23 unique completed sessions;
- parent chronological final close as the first return anchor and every
  newest-month chronological close included exactly once;
- positive, negative, and flat close moves counted strictly, with flat moves
  retained in `n`;
- BUY only when `2*up>n` and newest final close is above the parent final
  close, SELL only when `2*down>n` and it is below, and every tie,
  non-majority, equality, disagreement, or invalid state flat;
- one persistent decision `yyyymm` attempt recorded before fallible gates;
- one `RISK_FIXED=1000` position, frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-month signal price, daily-sign magnitude weighting, optimized
majority fraction, flat-observation deletion, body/range or close-location
gate, signal-strength sizing, volatility/volume/season/weekday/event/inventory
filter, moving average, regression, external data, retry, pending entry,
target, trail, scale-in, grid, martingale, pyramid, hedge, or after-result
rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one exact D1 `RISK_FIXED`
backtest set, strict Q01, and one paced Q02 enqueue only if the governed
terminal and host-CPU ceilings permit it. It does not authorize a manual
tester dispatch or terminal control.

Q02 must retire on zero positions, fewer than five completed positions per
full post-warm-up year, nonpositive governed economics, wrong label/month/
session state, missing or duplicated return observations, wrong sign, flat
observations removed from the denominator, accepted majority equality,
breadth/net disagreement, current-month leakage, repeated attempt, invalid
risk mode, missing stop, wrong month lifecycle, or nondeterminism. Q09 alone
may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or `T_Live` manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
