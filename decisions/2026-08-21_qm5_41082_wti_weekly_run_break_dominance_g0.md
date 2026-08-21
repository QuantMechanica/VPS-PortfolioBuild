# G0 Decision - QM5_41082 WTI Completed-Week Run-Break Dominance

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch, bounded by
`decisions/2026-08-21_wti_weekly_run_break_dominance_source_approval.md` at
commit `f02d2a56e`.

Approved card:
`strategy-seeds/cards/approved/QM5_41082_wti-wrunbreak-dom_card.md`.

## Identity

- EA ID: `QM5_41082`, the next free numeric identity after 4,569 registry rows
- slug: `wti-wrunbreak-dom`
- strategy ID: `MOP-WTI-WRUNBREAK-DOM-2026_S01`
- host: exact `XTIUSD.DWX`, D1, slot 0, magic `410820000`
- mechanic: the two older of three adjacent completed weekly returns must
  share a strict sign; the newest must oppose them and have an absolute move
  strictly larger than both older moves combined; follow the newest and
  cumulative-three-week sign for one broker week
- source packet: `strategy-seeds/sources/MOP-WTI-WRUNBREAK-DOM-2026/source.md`

## Deterministic Gates

- `skill_card_schema_lint.py`: `OK`, no missing sections and no ML-ban hits.
- `skill_g0_card_lint.py`: `OK`, all required fields and module sections
  present.
- pre-card `research_dedup_check.py`: `CLEAN`, covering 4,569 registry rows,
  625 root cards, and no external vault nodes.
- post-card dedup identifies only the candidate draft itself, as expected.
- registered native carrier: `XTIUSD.DWX`, D1, slot zero.
- fixed backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Reputable-Source Review

- R1 `PASS_WITH_WEEKLY_PATH_TRANSLATION_RISK`: the source lineage is the
  complete-read, named-author, peer-reviewed Moskowitz-Ooi-Pedersen JFE paper
  with DOI and explicit WTI membership. Weekly path efficacy is not claimed.
- R2 `PASS`: four completed week-end closes, chronological return orientation,
  older-pair sign equality, opposed newest return, strict combined-erasure
  inequality, direction, attempt, stop, and lifecycle are fully locked.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: exact registered
  `XTIUSD.DWX` D1 and native framework state provide all runtime inputs. Q02
  owns data density and CFD-basis falsification.
- R4 `PASS`: deterministic price, timestamp, logarithm, comparison, ATR,
  spread, and native trade-state arithmetic only. No trained signal, banned
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid is
  authorized.

## Non-Duplicate Review

The candidate is not a renamed or parameter-only sibling:

- `QM5_41065` has a generic two-week sign handoff and no second older run week
  or combined-erasure proof.
- `QM5_41069` follows the older sign after a strictly smaller counterweek;
  this card requires one newest counterweek to erase two older same-sign weeks
  combined and follows the newest sign.
- `QM5_41068` and `QM5_41070` require the newest two returns to share a sign.
- `QM5_41071` and `QM5_41072` require an outer/opposed-middle/restored-outer
  topology, unlike this older-pair/newest-break topology.
- `QM5_41073` uses completed weekly highs, lows, and settlement location.
- `QM5_41074` requires three same-sign weekly returns.
- `QM5_13050` fades a single weekly return under a volatility regime.
- `QM5_12567` is a long-only two-day cumulative-RSI2 pullback on the incumbent
  commodity sleeve.

The exact WTI carrier, four consecutive week-end closes, three adjacent
returns, same-sign older pair, opposed newest return, strict newest-over-
combined-older magnitude, newest/net-sign direction, persisted weekly attempt,
and next-week lifecycle are jointly load-bearing. Verdict:
`CLEAN_WTI_TWO_WEEK_RUN_DOMINANT_BREAK_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Risk And Lifecycle Contract

- one position and one consumed attempt per Monday-anchored broker week;
- attempt persisted before history, signal, spread, quote, ATR, sizing, news,
  or order gates;
- frozen `3.5 * ATR(20,D1)` hard stop, no target, and 1,500-point spread cap;
- both news axes OFF and Friday close OFF;
- first-later-week close with ten-calendar-day stale repair;
- no retry, scale-in, grid, martingale, pyramid, hedge, trail, break-even move,
  or partial close.

## Portfolio And Falsification Boundary

Direct WTI physical-energy price risk is economically outside the certified
XAU/SP500/NDX/XNG book, and the mechanic is unlike `QM5_12567`. This does not
pre-approve low correlation or portfolio admission. Q09 alone owns realized
correlation.

Q02 must retire on zero trades, fewer than two completed positions per full
post-warm-up year, nonpositive governed economics, any label/anchor/endpoint/
sign/dominance/direction/attempt/lifecycle defect, or nondeterminism. A weak
result may not be rescued by accepting equality, weakening combined erasure,
changing direction or hold, removing a week, or adding a threshold, calendar,
volatility, or volume filter.

## Authorization Boundary

G0 authorizes one branch-only V5 EA directory, slot-zero registry allocation,
one locked `RISK_FIXED` D1 backtest setfile, strict compile/Q01 validation, and
one paced target-only Q02 enqueue only if exact-path tester and host-CPU
ceilings are below their limits.

It does not authorize a manual backtest, terminal dispatch or control, live,
demo, shadow, stress, optimization, AutoTrading, `T_Live`, deploy or T_Live
manifest edits, portfolio-gate edits, portfolio admission, a decorrelation
claim, or a correlation waiver. If the CPU ceiling is binding, stop before
queue mutation and record the non-live handoff.
