# Q00 Decision - QM5_41084 WTI Completed-Week Daily-Sign Breadth Momentum

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch, bounded by
`decisions/2026-08-21_wti_weekly_daily_sign_breadth_momentum_source_approval.md`
at commit `8ca5ed7fa`.

Approved card:
`strategy-seeds/cards/approved/QM5_41084_wti-wdaybreadth-mom_card.md`.

## Identity

- EA ID: `QM5_41084`, atomically allocated after the canonical dedup gate
- slug: `wti-wdaybreadth-mom`
- strategy ID: `MOP-WTI-WDAYBREADTH4-MOM-2026_S01`
- host: exact `XTIUSD.DWX`, D1, slot 0, magic `410840000`
- mechanic: count the signs of five adjacent close-to-close returns spanning
  one exact five-session completed broker week; follow at least four matching
  signs only when the full-week net return strictly agrees
- source packet:
  `strategy-seeds/sources/MOP-WTI-WDAYBREADTH4-MOM-2026/source.md`

## Deterministic Gates

- `skill_card_schema_lint.py`: required before build, with no missing sections
  or ML-ban hits permitted.
- `skill_g0_card_lint.py`: required before build, with all required fields and
  module sections present.
- pre-card `research_dedup_check.py`: `CLEAN`, covering 4,571 registry rows,
  625 root cards, and no external vault nodes.
- post-card dedup may identify only this candidate card, as expected.
- registered native carrier: `XTIUSD.DWX`, D1, slot zero.
- fixed backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Reputable-Source Review

- R1 `PASS_WITH_WEEKLY_DAILY_BREADTH_TRANSLATION_RISK`: the source lineage is
  the complete-read, named-author, peer-reviewed Moskowitz-Ooi-Pedersen JFE
  paper with DOI and explicit WTI membership. Weekly breadth efficacy is not
  claimed.
- R2 `PASS`: current and prior Monday anchors, parent final close, exactly five
  newest-week session closes, chronological return orientation, zero handling,
  strict breadth/net conjunction, direction, attempt, stop, and lifecycle are
  fully locked.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: exact registered
  `XTIUSD.DWX` D1 and native framework state provide all runtime inputs. Q02
  owns label, density, holiday attrition, and CFD-basis falsification.
- R4 `PASS`: deterministic price, timestamp, logarithm, counting, comparison,
  ATR, spread, and native trade-state arithmetic only. No trained signal,
  banned indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid is authorized.

## Non-Duplicate Review

The candidate is not a renamed or parameter-only sibling:

- `QM5_41080` confirms one weekly return by within-week high-low close
  location and does not count component daily return signs.
- `QM5_41020` uses fixed Tuesday and Friday endpoints plus a partial-next-week
  lifecycle, not five daily intervals and a full-week hold.
- `QM5_41065` through `QM5_41074` and `QM5_41082` classify multi-week paths,
  ranges, settlement, or magnitudes rather than within-one-week breadth.
- `QM5_41029` through `QM5_41036` split session and overnight flows rather
  than count adjacent close-to-close return signs.
- `QM5_13150`, `QM5_20244`, and `QM5_20273` operate on twelve monthly returns
  under monthly renewal clocks.
- `QM5_13049` uses a five-D1 magnitude return and volatility-rank gate without
  component-sign breadth.
- `QM5_12567` is a long-only two-day cumulative-RSI2 pullback on the incumbent
  commodity sleeve.

The exact WTI carrier, parent final close, exactly five newest-week session
closes, five adjacent daily return signs, strict four-of-five breadth,
same-sign full-week net, persisted weekly attempt, and next-week lifecycle are
jointly load-bearing. Verdict:
`CLEAN_WTI_EXACT_FIVE_SESSION_DAILY_SIGN_BREADTH_WITH_WEEKLY_NET_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Risk And Lifecycle Contract

- one position and one consumed attempt per Monday-anchored broker week;
- attempt persisted before history, signal, spread, quote, ATR, sizing, news,
  or order gates;
- frozen `3.5 * ATR(20,D1)` hard stop, no target, and 1,500-point spread cap;
- exactly one `RISK_FIXED=1000` budget with `RISK_PERCENT=0`;
- both news axes OFF and Friday close OFF;
- first-later-week close with ten-calendar-day stale repair; and
- no retry, scale-in, grid, martingale, pyramid, trail, break-even move, or
  partial close.

## Portfolio And Falsification Boundary

The card carries direct WTI physical-energy price risk outside the certified
XAU/SP500/NDX/XNG book and is mechanically unlike `QM5_12567`. Carrier and
mechanic difference do not prove low correlation. Q09 alone owns realized
portfolio overlap and any admission decision remains manual.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, any label/anchor/endpoint/
session-count/return-orientation/breadth/net/direction/attempt/lifecycle
defect, or nondeterminism. A weak result may not be rescued by accepting a
four-session week, lowering the breadth threshold, removing the net check,
changing direction or hold, or adding a magnitude, volatility, volume,
calendar, or external-data filter.

## Authorization Boundary

Q00 authorizes one branch-only V5 EA directory, deterministic slot-zero magic
allocation, one locked `RISK_FIXED` D1 setfile, strict compile/Q01 validation,
and one paced target-only Q02 enqueue only if exact-path tester and whole-host
CPU ceilings are below their limits.

It does not authorize a manual backtest, terminal dispatch or control, live,
demo, shadow, stress, optimization, AutoTrading, `T_Live`, deploy or T_Live
manifest edits, portfolio-gate edits, portfolio admission, a decorrelation
claim, or a correlation waiver. If the CPU ceiling is binding, stop before
queue mutation and record the non-live handoff.
