# Q00 Decision - QM5_41114 WTI Completed-Month Two-Half Agreement Momentum

Date: 2026-08-22

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_wti_monthly_two_half_agreement_momentum_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41114_wti-mhalfagree-mom_card.md`.

## Identity

- EA ID: `QM5_41114`, allocated atomically in the deterministic registry and
  committed at `97e2d2ddd`;
- slug: `wti-mhalfagree-mom`;
- strategy ID: `MOP-WTI-MHALFAGREE-MOM-2026_S01`;
- source ID: `MOP-WTI-MHALFAGREE-MOM-2026`;
- source authorization: `3e3264609`;
- bounded source extraction: `d0383641d`;
- host: exact `XTIUSD.DWX`, D1, slot 0, planned magic `411140000`; and
- mechanic: follow the immediately completed WTI month's direction only when
  its two exhaustive chronological cumulative-return halves share a strict
  sign.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-method hits. The G0-readiness lint also
returned `status=ok`. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41114` after the registered custom-history admission
check and stamped expected frequency six/year, PF prior 1.01, drawdown prior
30 percent, and the Q00 reasoning into the card.

The PF, drawdown, and frequency numbers are conservative build-ordering
estimates only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate Findings

- R1 `PASS_WITH_MONTHLY_TWO_HALF_TRANSLATION_RISK`: the bounded child source
  preserves named peer-reviewed JFE authors, DOI, complete-paper review,
  durable retrieval identity, and explicit WTI membership. The within-month
  two-half condition is disclosed as an untested QM translation.
- R2 `PASS`: exact normalized month clock, two consecutive completed
  17-to-23-session packages, parent-final anchor, deterministic
  `floor(n/2)` observation split, exhaustive adjacent-return partition,
  strict same-sign cumulative half returns, durable attempt, fixed risk, hard
  stop, spread gate, and lifecycle are mechanical.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5 state provides every runtime input. Q02
  owns history, label, density, cost, financing, and continuous-CFD
  falsification.
- R4 `PASS`: deterministic timestamp, completed-price, logarithm, indexing,
  arithmetic, comparison, ATR, quote, position, deal-history, and terminal-
  state logic only; no trained signal, banned indicator, external feed, grid,
  martingale, scale-in, or pyramid.

## Duplicate Review

The fail-closed pre-allocation checker scanned 4,610 EA-registry identities,
1,282 repository cards, and 45 Strategy-Wiki nodes and found no exact or fuzzy
candidate match. Manual semantic review separates the candidate from:

- `QM5_41021_wti-mdual-mom`, whose full-month/final-five nested agreement and
  five-session hold differ from two exhaustive completed-month halves and a
  one-month hold;
- `QM5_41023_wti-mends-mom`, whose fixed five-session opening/closing samples
  omit the middle path and hold five sessions;
- `QM5_41111_wti-mdaybreadth-mom`, which counts individual daily signs and
  requires a majority plus endpoint agreement rather than two cumulative
  chronological legs;
- `QM5_20187_wti-tsmom1m`, which follows every nonzero month without the
  internal-path agreement condition;
- `QM5_41064_wti-mflip-mom`, which requires disagreement between two complete
  monthly returns rather than agreement within one month;
- aggregate monthly OHLC cards `QM5_41105` through `QM5_41108`; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only short-horizon XNG
  oscillator pullback.

The exact WTI carrier, consecutive completed calendar months,
17-to-23-session bounds, parent-final-close anchor, floor split, exhaustive
non-overlapping adjacent-return halves, strict same-sign agreement, consumed
monthly attempt, fixed risk, and next-month exit are jointly load-bearing.
Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_TWO_HALF_CUMULATIVE_RETURN_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

The post-allocation scan checked 4,611 registry identities, 1,282 cards, and
45 Wiki nodes. Its only exact hits are the newly reserved `QM5_41114` slug and
strategy ID; no foreign identity collision exists. Evidence:
`artifacts/qm5_41114_wti_mhalfagree_mom_postallocation_dedup_20260822.json`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact WTI host, D1, and slot zero under governed magic allocation;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- the two immediately preceding consecutive calendar months, each containing
  17 through 23 unique completed closes;
- the parent chronological final close as the anchor and all newest-month
  closes in chronological order;
- `k=floor(n/2)`, first leg `log(C[k-1]/P)`, second leg
  `log(C[n-1]/C[k-1])`, and equality or sign disagreement flat;
- BUY only when both legs are positive and SELL only when both are negative;
- one persistent decision `yyyymm` attempt recorded before fallible gates;
- `RISK_FIXED=1000`, frozen `3.5*ATR(20,D1)` hard stop, no target, and a
  1,500-point WTI spread ceiling;
- both news axes OFF, Friday close OFF, next-month closure, and a forty-day
  stale guard; and
- deterministic split/mechanic tests, strict compile, set/registry checks,
  and static Q01 validation before Q02 handoff.

No current-month signal price, alternate split, individual daily-sign vote,
fitted center, regression, magnitude threshold, signal-strength sizing,
volatility/volume/season/weekday/event filter, external data, retry, pending
entry, target, trail, scale-in, grid, martingale, pyramid, overlay hedge, or
after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one logical D1
`RISK_FIXED` backtest set, strict Q01, and one paced Q02 enqueue only if the
governed tester and whole-host CPU ceilings permit it. It does not authorize a
manual tester dispatch or terminal control.

Q02 must retire on zero positions, fewer than five completed positions per
full post-warm-up year, nonpositive governed economics, wrong month/session
state, duplicated or omitted endpoints, wrong chronology or split index,
overlapping or omitted adjacent returns, accepted half equality, half-sign
disagreement entry, wrong side, current-month leakage, repeated attempt,
invalid risk mode, missing stop, wrong month lifecycle, or nondeterminism.
Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization presets,
AutoTrading, `T_Live`, deploy or `T_Live` manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, correlation waivers, and any live
use.
