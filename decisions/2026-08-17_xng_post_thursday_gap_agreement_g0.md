# G0 Decision — QM5_41052 XNG Post-Thursday Gap-Agreement Friday Continuation

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_xng_post_thursday_gap_agreement_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41052_xng-postthu-gap-agree_card.md`.

## Identity

- EA ID: `QM5_41052`, deterministically allocated in commit `d33a6d11f`
- slug: `xng-postthu-gap-agree`
- strategy ID: `EIA-WILLIAMS-MOP-XNG-POSTTHUGAP-2026_S01`
- source approval commit: `2b8178970`
- carrier: exact `XNGUSD.DWX`, D1, slot 0
- registered magic: `410520000`
- mechanic: after an exact completed standard Thursday, require completed
  event-session return to agree with the frozen Thursday-close/Friday-open
  gap, follow the common sign on Friday, and flatten at broker hour 21

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage,
  complete Tier-A Williams decomposition lineage, and complete-read peer-
  reviewed JFE futures-continuation evidence that includes natural gas. No
  source validates the exact conjunction; the academic horizon is longer and
  the same-Friday translation is QM-defined.
- R2 `PASS`: exact weekdays, energy-label normalization, completed endpoints,
  frozen Friday open, strict agreement, reconciliation, continuation side,
  attempt persistence, grace, fixed risk, hard stop, spread cap, and Friday
  exit are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XNGUSD.DWX` D1 OHLC
  and MT5 state supply every runtime input; energy-label normalization and the
  standard-Thursday proxy remain explicit carrier risks.
- R4 `PASS`: closed-form timestamp, calendar, and log-return arithmetic only;
  no trained output, banned signal indicator, external feed, grid, martingale,
  scale-in, hedge, or pyramid.

## Duplicate Review

The canonical checker scanned 4,539 registry rows and 625 root cards and
returned `CLEAN`. Manual review separates the frozen post-event Friday gap and
same-Friday lifecycle from the internal-Thursday flow pair (`QM5_41043`/
`QM5_41044`), Thursday/252-D1 trend conjunctions (`QM5_41047`/`QM5_41048`),
parameterized multiday storage drift (`QM5_12898`), M30 release-window
systems, Friday slow-trend short (`QM5_20160`), and cumulative-RSI pullback
(`QM5_12567`).

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_EVENT_SESSION_POST_EVENT_GAP_STRICT_AGREEMENT_FRIDAY_SESSION_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XNGUSD.DWX` D1 slot 0 and magic `410520000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current broker Friday plus completed Thursday, Wednesday, and Tuesday at
  exact calendar offsets zero through three, with no substitution;
- first-Friday decision within 180 minutes and one durable `yyyymmdd` attempt
  persisted before every fallible gate;
- completed Thursday open/close plus frozen Friday open, strict same-sign
  agreement, and `1e-10` reconciliation to Thursday-open/Friday-open return;
- positive total maps to BUY and negative maps to SELL;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.5 * ATR(20,D1)` hard stop, no target, and 3,000-point spread
  ceiling;
- both news axes OFF, framework Friday close ON at broker hour 21, first-
  later-D1 repair, and a four-day stale guard; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before Q02 handoff.

No storage number, event calendar file, magnitude threshold, volatility
signal, moving mean, oscillator, range, body, tail, breakout, season selector,
external runtime input, retry, scale-in, grid, martingale, hedge, pyramid,
optimization surface, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only below the
governed tester and host-CPU ceilings. It does not authorize a manual tester
dispatch or tester control.

Expected cadence is approximately twelve to twenty-eight completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong weekday/endpoints, current-Friday
signal leakage beyond the frozen open, absent agreement, wrong side, failed
reconciliation, late/repeated entry, wrong Friday lifecycle, invalid risk
mode, nondeterminism, or an unusable standard-Thursday proxy. Q09 alone may
establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
