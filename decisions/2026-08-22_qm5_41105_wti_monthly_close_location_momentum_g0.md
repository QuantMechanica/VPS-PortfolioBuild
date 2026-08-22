# Q00 Decision - QM5_41105 WTI Completed-Month Close-Location Momentum

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_wti_monthly_close_location_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41105_wti-mclose-location-mom_card.md`.

## Identity

- EA ID: `QM5_41105`, allocated atomically by the governed registry command
  and committed at `bc90249b8`;
- slug: `wti-mclose-location-mom`;
- strategy ID: `MOP-WTI-MCLOSE-LOCATION-MOM-2026_S01`;
- source ID: `MOP-WTI-MCLOSE-LOCATION-MOM-2026`;
- source authorization: `896f3cd59`;
- bounded source extraction: `678af6b6d`;
- host: exact `XTIUSD.DWX`, D1, slot 0, planned magic `411050000`; and
- mechanic: follow the immediately completed month's strict close-to-close
  sign only when its final close occupies the matching strict outer quartile
  of that completed month's own aggregate high-low range.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41105` after the registered custom-history admission
check, and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF and drawdown numbers are conservative build-ordering estimates only.
They are not gate evidence, expected-performance promises, or substitutes for
Q02.

## Gate Findings

- R1 `PASS_WITH_MONTHLY_CLOSE_LOCATION_TRANSLATION_RISK`: the bounded child
  source has named peer-reviewed authors, a DOI, complete-paper evidence, a
  durable retrieval hash, and explicit WTI membership. Completed-month
  close-location confirmation is disclosed as an untested QM translation.
- R2 `PASS`: exact label normalization, month arithmetic, first-month clock,
  two consecutive completed monthly packages, 17-to-23-session bounds,
  chronological closes, newest-month high/low, strict return/location
  conjunction, equality-flat behavior, durable attempt, fixed risk, hard
  stop, spread, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5 state provides every runtime input. Q02
  owns label, density, cost, fill, financing, and continuous-CFD
  falsification.
- R4 `PASS`: deterministic timestamp, completed OHLC, logarithm, arithmetic,
  comparison, ATR, quote, position, deal-history, and terminal-state logic
  only; no trained signal, banned indicator, external feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,594 EA-registry identities,
1,273 repository cards, and 45 Strategy-Wiki nodes. It found no exact identity
and raised expected family-level fuzzy matches. Manual semantic review
separates the candidate from:

- `QM5_41080_wti-wclose-location-mom`, whose two completed three-to-five-
  session weekly packages, outer-fifth thresholds, weekly turnover, and next-
  week hold differ from two complete 17-to-23-session calendar months,
  outer-quartile thresholds, and the next-month lifecycle;
- `QM5_41081_xng-wclose-location-mom`, a weekly natural-gas carrier;
- `QM5_20187_wti-tsmom1m`, which follows every nonzero completed-month return
  sign without a monthly range-position confirmation;
- `QM5_41016_wti-mclose-mom` and `QM5_41021_wti-mdual-mom`, whose final-five-
  session formation and first-five-session hold do not own a full monthly
  return stream;
- `QM5_41102_wti-mrange-migrate-mom`, which compares highs and lows across
  months and excludes closes rather than confirming return sign with the
  newest month's own close location;
- weekly widest-range, outside-settlement, and inside-body families, which
  require compression or parent-range geometry absent here; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback beneath a slow trend filter.

The exact WTI carrier, two immediately completed consecutive calendar-month
packages, 17-to-23 sessions each, parent-close-to-new-close sign, newest-
month own-range `0.75` / `0.25` confirmation, equality/disagreement-flat
rule, first-new-month entry, durable attempt, fixed risk, and next-month exit
are jointly load-bearing. Manual verdict:
`CLEAN_AFTER_EXPECTED_WEEKLY_CLOSE_LOCATION_FAMILY_FUZZY_REVIEW`.

The post-allocation scan checked 4,595 registry identities, 1,274 cards, and
45 Wiki nodes and found only the newly reserved `QM5_41105` slug and strategy
ID as exact self-hits. It found no foreign identity collision. Evidence:
`artifacts/qm5_wti_mclose_location_mom_postallocation_dedup_20260822.json`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI D1 host and slot zero under the governed magic allocation;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- uniform raw or `+1`-day energy-label normalization;
- the immediately completed broker-calendar month and its exact parent, each
  containing 17 through 23 unique completed sessions;
- chronological `C1` and `C0`, newest-month aggregate `H0` and `L0`,
  `r=ln(C0/C1)`, and `clv=(C0-L0)/(H0-L0)`;
- BUY only for strict `r>0 && clv>0.75`, SELL only for strict
  `r<0 && clv<0.25`, and every equality, invalid, interior, or disagreement
  state flat;
- one persistent `yyyymm` attempt recorded before fallible gates;
- one `RISK_FIXED=1000` position, frozen `3.5*ATR(20,D1)` hard stop, no
  target, and a 1,500-point spread ceiling;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic mechanic tests, strict compile, set/registry checks, and
  static Q01 validation before any Q02 handoff.

No current-month price, return-magnitude threshold, range-migration test,
signal-strength sizing, volatility/volume/season/weekday/event/inventory
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
session or close-location state, entry at equality or disagreement, wrong
side, current-month leakage, repeated attempt, invalid risk mode, missing
stop, wrong month lifecycle, or nondeterminism. Q09 alone may establish
realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
