# Q00 Decision - QM5_41113 XAU/XAG Completed-Month Two-Half Agreement Reversion

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_xauxag_monthly_two_half_agreement_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41113_xauxag-mhalfagree-rv_card.md`.

## Identity

- EA ID: `QM5_41113`, allocated atomically in the deterministic registry and
  committed at `4d68e13a3`;
- slug: `xauxag-mhalfagree-rv`;
- strategy ID: `SCHWEIKERT-CME-XAUXAG-MHALFAGREE-RV-2026_S01`;
- source ID: `SCHWEIKERT-CME-XAUXAG-MHALFAGREE-RV-2026`;
- source authorization: `895531aef`;
- bounded source extraction: `8356c6bba`;
- host: exact `XAUUSD.DWX`, D1, slot 0, planned magic `411130000`;
- companion: exact `XAGUSD.DWX`, D1, slot 1, planned magic `411130001`; and
- mechanic: fade the immediately completed month's ratio displacement only
  when its two exhaustive chronological cumulative-return halves have the
  same strict sign.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41113` after the registered custom-history admission
check and stamped expected frequency six/year, PF prior 1.01, drawdown prior
35 percent, and the Q00 reasoning into the card.

The PF, drawdown, and frequency numbers are conservative build-ordering
estimates only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate Findings

- R1 `TIER_A_WITH_MONTHLY_TWO_HALF_TRANSLATION_RISK`: the bounded child source
  preserves named peer-reviewed DOI and official-exchange lineage. The
  within-month two-half persistence fade is disclosed as an untested QM
  translation.
- R2 `PASS`: exact synchronized month clock, two consecutive completed
  17-to-23-session packages, parent-final ratio anchor, deterministic
  `floor(n/2)` observation split, exhaustive adjacent-return partition,
  strict same-sign cumulative half returns, inverse pair sides, durable
  attempt, aggregate risk, hard stops, atomicity, spread gates, and lifecycle
  are mechanical.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state provide every
  runtime input. Q02 owns history, holiday attrition, density, cost, fill,
  financing, and continuous-CFD falsification.
- R4 `PASS`: deterministic timestamp, completed price, logarithm, indexing,
  arithmetic, comparison, ATR, quote, position, deal-history, and terminal-
  state logic only; no trained signal, banned indicator, external feed, grid,
  martingale, scale-in, or pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,609 EA-registry identities,
1,281 repository cards, and 45 Strategy-Wiki nodes. It found no exact
collision and one fuzzy family neighbor, `QM5_41112_xauxag-mdaybreadth-rv`.
Manual semantic review separates the candidate from:

- `QM5_41112_xauxag-mdaybreadth-rv`, which counts every adjacent daily
  relative-return sign and requires a strict sign majority plus endpoint
  agreement. This card counts no individual daily signs; it partitions the
  complete path into two cumulative legs and requires both halves to agree;
- `QM5_41085_xauxag-wdaybreadth-rv`, whose exact five-session week,
  four-of-five rule, and one-week hold differ from one complete calendar month,
  two cumulative halves, and a next-month hold;
- `QM5_20275_gsr-runfade`, which classifies a fixed six-return rolling run;
- rolling-center, residual, robust-score, and tail cards `QM5_12577`,
  `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`;
- monthly range/location/distribution cards `QM5_41103`, `QM5_41104`,
  `QM5_41109`, and `QM5_41110`;
- session/overnight-flow cards `QM5_41030`, `QM5_41040`, and `QM5_41057`; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, deterministic
floor observation split, exhaustive non-overlapping adjacent-return halves,
strict same-sign half agreement, contrarian package side, consumed monthly
attempt, equal-notional aggregate-risk package, and next-month exit are jointly
load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_TWO_HALF_CUMULATIVE_RELATIVE_RETURN_AGREEMENT_REVERSION_AFTER_FAMILY_REVIEW`.

The post-allocation scan checked 4,610 registry identities, 1,281 cards, and 45
Wiki nodes. Its only exact hits are the newly reserved `QM5_41113` slug and
strategy ID; no foreign identity collision exists. Evidence:
`artifacts/qm5_41113_xauxag_mhalfagree_rv_postallocation_dedup_20260822.json`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XAU host, XAG companion, D1, and slots zero/one under governed magic
  allocation;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- the two immediately preceding consecutive calendar months, each containing
  17 through 23 unique synchronized close pairs;
- the parent chronological final log ratio as the anchor and all newest-month
  synchronized ratios in chronological order;
- `k=floor(n/2)`, first half `Q[k-1]-P`, second half
  `Q[n-1]-Q[k-1]`, and equality or sign disagreement flat;
- SELL XAU/BUY XAG only when both halves are positive and BUY XAU/SELL XAG
  only when both are negative;
- one persistent decision `yyyymm` attempt recorded before fallible gates;
- one aggregate `RISK_FIXED=1000` equal-notional package, frozen
  `3.5*ATR(20,D1)` per-leg hard stops, no target, and 1,500/500-point XAU/XAG
  spread ceilings;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic split/mechanic tests, strict compile, set/registry checks,
  `basket_manifest.json`, and static Q01 validation before Q02 handoff.

No current-month signal price, alternate split, daily-sign vote, fitted center,
regression, magnitude threshold, signal-strength sizing, volatility/volume/
season/weekday/event filter, external data, retry, pending entry, target, trail,
scale-in, grid, martingale, pyramid, overlay hedge, or after-result rescue is
approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical D1
`RISK_FIXED` basket backtest set, strict Q01, and one paced Q02 enqueue only if
the governed tester and whole-host CPU ceilings permit it. It does not
authorize a manual tester dispatch or terminal control.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, wrong month/session state,
asynchronous or duplicated endpoints, wrong chronology or split index,
duplicated or omitted adjacent returns, accepted half equality, half-sign
disagreement entry, wrong relative side, current-month leakage, repeated
attempt, invalid risk mode, incomplete package, missing stop, wrong month
lifecycle, or nondeterminism. Q09 alone may establish realized book
correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or `T_Live` manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
