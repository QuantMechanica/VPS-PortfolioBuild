# Q00 Decision - QM5_41085 XAU/XAG Completed-Week Daily Relative-Sign Breadth Reversion

Date: 2026-08-21

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch, bounded by
`decisions/2026-08-21_xauxag_weekly_daily_relative_sign_breadth_reversion_source_approval.md`
at commit `25a9c6356`.

Approved card:
`strategy-seeds/cards/approved/QM5_41085_xauxag-wdaybreadth-rv_card.md`.

## Identity

- EA ID: `QM5_41085`, atomically allocated after the canonical dedup gate at
  commit `648639751`
- slug: `xauxag-wdaybreadth-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026_S01`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, slots 0/1,
  magics `410850000` and `410850001`
- mechanic: count five adjacent synchronized gold-minus-silver daily relative-
  return signs spanning one exact five-session completed broker week; require
  at least four signs plus the full-week net to agree; fade with opposite legs
- source packet:
  `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026/source.md`

## Deterministic Gates

- `skill_card_schema_lint.py`: required before build, with no missing sections
  or forbidden-token hits permitted.
- `skill_g0_card_lint.py`: required before build, with all required fields and
  module sections present.
- pre-card `research_dedup_check.py`: `CLEAN`, covering 4,572 registry rows,
  625 root cards, and no external vault nodes.
- post-card dedup may identify only this candidate card, as expected.
- registered native carriers: `XAUUSD.DWX` and `XAGUSD.DWX`, D1.
- fixed backtest contract: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Reputable-Source Review

- R1 `PASS_WITH_WEEKLY_DAILY_BREADTH_TRANSLATION_RISK`: the source lineage
  preserves named peer-reviewed DOI evidence for a state-dependent gold/silver
  relation plus CME's official ratio/spread carrier; weekly breadth efficacy is
  not claimed.
- R2 `PASS`: current/parent Monday anchors, exact synchronized parent plus five
  endpoints, chronological relative returns, zero handling, strict breadth/net
  conjunction, inverse sides, attempt, risk, atomicity, and lifecycle are fully
  locked.
- R3 `PASS_WITH_EXACT_FIVE_SESSION_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: exact
  registered XAU/XAG D1 histories and native framework state provide all
  runtime inputs. Q02 owns label, synchronization, holiday attrition, density,
  cost, and CFD-basis falsification.
- R4 `PASS`: deterministic price, timestamp, logarithm, counting, comparison,
  ATR, quote, position, deal, and terminal-state arithmetic only. No trained
  signal, banned indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid is authorized.

## Non-Duplicate Review

The candidate is not a renamed or parameter-only sibling:

- rolling ratio/residual builds estimate a center, regression, scale, robust
  score, or tail; this candidate does not;
- `QM5_41079` ranks a final ratio close inside a variable-session week without
  a parent endpoint or adjacent relative-return sign count;
- `QM5_41083` compares individual whole-week metal-return signs and has no
  within-week path state;
- `QM5_41030`, `QM5_41040`, and `QM5_41057` split overnight/session flows;
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify relative moves
  across multiple completed weeks;
- `QM5_41084` follows daily breadth on one directional WTI carrier, while this
  candidate fades a synchronized two-metal relative move with equal notionals;
  and
- `QM5_12567` is a long-only two-day cumulative-RSI2 pullback.

The paired carrier, parent endpoint, exact five-session synchronized week,
five adjacent relative-return signs, strict four-of-five breadth, same-sign
weekly net, contrarian pair sides, persistent attempt, equal-notional aggregate
risk, and next-week lifecycle are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_EXACT_FIVE_SESSION_DAILY_RELATIVE_SIGN_BREADTH_REVERSION_AFTER_FAMILY_REVIEW`.

## Risk And Lifecycle Contract

- one two-leg package and one consumed attempt per Monday-anchored broker week;
- attempt persisted before history, signal, spread, quote, ATR, sizing, news,
  or order gates;
- frozen `3.5 * ATR(20,D1)` per-leg hard stops, no target, and carrier-specific
  spread caps;
- exactly one aggregate `RISK_FIXED=1000` budget with `RISK_PERCENT=0`;
- target 1:1 absolute USD notionals with a 20-percent maximum mismatch;
- both news axes OFF and Friday close OFF;
- first-later-week close with ten-calendar-day stale repair; and
- no retry, scale-in, grid, martingale, pyramid, trail, break-even move, or
  partial close.

## Portfolio And Falsification Boundary

The card forms one opposite-leg gold/silver relative-value package designed to
remove common outright metal direction and is mechanically unlike the
certified XNG cumulative-RSI2 pullback. Design intent is not proof of factor,
beta, volatility, market, or portfolio neutrality. Q09 alone owns realized
portfolio overlap and any admission decision remains manual.

Q02 must retire on zero packages, fewer than five completed packages per full
post-warm-up year, nonpositive governed economics, any synchronization,
endpoint, session-count, return-orientation, breadth/net, side, attempt,
aggregate-risk, atomicity, lifecycle, or determinism defect. A weak result may
not be rescued by accepting four sessions, lowering breadth, removing net
agreement, changing direction or hold, or adding a fitted center, volatility,
volume, calendar, or external-data filter.

## Authorization Boundary

Q00 authorizes one branch-only V5 EA directory, deterministic slot-zero and
slot-one magic allocation, one locked logical-basket `RISK_FIXED` D1 setfile,
strict compile/Q01 validation, and one paced target-only Q02 enqueue only if
exact-path tester and whole-host CPU ceilings are below their limits.

It does not authorize a manual backtest, terminal dispatch or control, live,
demo, shadow, stress, optimization, AutoTrading, `T_Live`, deploy or T_Live
manifest edits, portfolio-gate edits, portfolio admission, a decorrelation
claim, or a correlation waiver. If the CPU ceiling is binding, stop before
queue mutation and record the non-live handoff.
