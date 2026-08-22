# Q00 Decision - QM5_41106 WTI Completed-Month Body-Dominance Momentum

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_wti_monthly_body_dominance_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41106_wti-mbody-dominance-mom_card.md`.

## Identity

- EA ID: `QM5_41106`, allocated in the deterministic registry and committed
  at `9fb6f1548`;
- slug: `wti-mbody-dominance-mom`;
- strategy ID: `MOP-WTI-MBODY-DOMINANCE-MOM-2026_S01`;
- source ID: `MOP-WTI-MBODY-DOMINANCE-MOM-2026`;
- source authorization: `e0eb12c16`;
- bounded source extraction: `b1eedd804`;
- host: exact `XTIUSD.DWX`, D1, slot 0, planned magic `411060000`; and
- mechanic: follow the immediately completed month's open-to-close body only
  when that real body occupies strictly more than one half of the completed
  month's aggregate high-low range.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41106` after the registered custom-history admission
check and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF and drawdown numbers are conservative build-ordering estimates only.
They are not gate evidence, expected-performance promises, or substitutes for
Q02.

## Gate Findings

- R1 `PASS_WITH_MONTHLY_BODY_TRANSLATION_RISK`: the bounded child source has
  named peer-reviewed authors, a DOI, complete-paper evidence, a durable
  retrieval hash, and explicit WTI membership. Completed-month body-share
  qualification is disclosed as an untested QM translation.
- R2 `PASS`: exact label normalization, month arithmetic, first-month clock,
  one immediately completed monthly package, 17-to-23-session bounds, first
  open, final close, aggregate high/low, strict majority-body inequality,
  equality-flat behavior, own-body direction, durable attempt, fixed risk,
  hard stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5 state provides every runtime input. Q02
  owns label, density, cost, fill, financing, and continuous-CFD
  falsification.
- R4 `PASS`: deterministic timestamp, completed OHLC, arithmetic, comparison,
  ATR, quote, position, deal-history, and terminal-state logic only; no
  trained signal, banned indicator, external feed, grid, martingale, scale-in,
  or pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,595 EA-registry identities,
1,274 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and raised only the expected body-family fuzzy matches. Manual semantic review
separates the candidate from:

- `QM5_41092_wti-wbody-dominance-mom`, whose completed three-to-five-session
  week, strict two-thirds threshold, weekly turnover, and one-week hold differ
  from a complete 17-to-23-session calendar month, strict majority threshold,
  and next-month lifecycle;
- `QM5_41094_xng-wbody-dominance-mom`, a weekly natural-gas carrier;
- `QM5_20187_wti-tsmom1m`, which follows every nonzero return between two
  month-end closes without requiring the newest month's first open, aggregate
  range, or majority body;
- `QM5_41105_wti-mclose-location-mom`, which needs two consecutive final
  closes plus an outer-quartile settlement rather than one month's first-open
  to final-close body share;
- `QM5_41102_wti-mrange-migrate-mom`, which compares highs and lows across
  months and excludes opens and closes;
- `QM5_41091_wti-winside-body-mom`, which requires weekly parent-range
  containment absent here; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback beneath a slow trend filter.

The exact WTI carrier, immediately completed calendar-month package,
17-to-23 sessions, first open, final close, aggregate high/low, strict
`2*body>range`, own-body side, equality-flat rule, first-new-month entry,
durable attempt, fixed risk, and next-month exit are jointly load-bearing.
Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_MAJORITY_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

The post-allocation scan checked 4,596 registry identities, 1,274 cards, and
45 Wiki nodes and found only the newly reserved `QM5_41106` slug and strategy
ID as exact self-hits. It found no foreign identity collision. Evidence:
`artifacts/qm5_wti_mbody_dominance_mom_postallocation_dedup_20260822.json`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 host and slot zero under the governed magic allocation;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- uniform raw or `+1`-day energy-label normalization;
- the immediately completed broker-calendar month containing 17 through 23
  unique completed sessions;
- chronologically first `O0`, final `C0`, aggregate `H0` and `L0`, and exact
  strict arithmetic `2*abs(C0-O0)>H0-L0`;
- BUY only when the strict body condition holds and `C0>O0`, SELL only when it
  holds and `C0<O0`, with every equality or invalid state flat;
- one persistent decision `yyyymm` attempt recorded before fallible gates;
- one `RISK_FIXED=1000` position, frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-month price, parent-month comparison, close-location gate,
return-magnitude threshold beyond the body-share qualification, range-
migration test, signal-strength sizing, volatility/volume/season/weekday/
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
session or body-share state, entry at equality, wrong side, current-month
leakage, repeated attempt, invalid risk mode, missing stop, wrong month
lifecycle, or nondeterminism. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
