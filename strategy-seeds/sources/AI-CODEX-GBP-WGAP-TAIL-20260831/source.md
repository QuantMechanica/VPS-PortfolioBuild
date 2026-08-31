---
source_id: AI-CODEX-GBP-WGAP-TAIL-20260831
source_type: ai_originated_governed_synthesis
title: GBPUSD rolling-tail weekend-gap reversal
author: OpenAI Codex
supporting_authors: Thu-Mai Dao; Frank McGroarty; Andrew Urquhart
status: approved_source_complete
approval_basis: decisions/2026-08-31_gbpusd_weekend_tail_fade_source_approval.md
created: 2026-08-31
created_by: Codex
last_reviewed: 2026-08-31
cards_extracted: []
---

# GBPUSD Rolling-Tail Weekend-Gap Reversal

## Canonical origin

This packet is the single R1 lineage for one bounded AI-originated FX
strategy. The current OWNER mission asks for one new structural,
low-frequency sleeve on an instrument absent from the certified book after
the approved build backlog and diverse infrastructure-repair queue have been
exhausted. The certified survivors are confined to indices, metals, and
energy; this packet targets native `GBPUSD.DWX`.

Dao, McGroarty, and Urquhart (2016) supply the peer-reviewed weekend-gap
overreaction thesis, the GBP/USD carrier, the Monday-open contrarian side,
empirical gap tails, and a Friday-close holding horizon. The exact rolling
52-gap window, 10% order statistics, broker-D1 boundary proxy, ATR safety
stop, spread ceiling, and operational lifecycle are disclosed pre-result QM
choices. The paper does not test their conjunction.

## Supporting evidence and read boundary

The complete 22-page institutional-repository postprint was read end to end:

- Dao, Thu-Mai; McGroarty, Frank; and Urquhart, Andrew (2016), "A calendar
  effect: weekend overreaction (and subsequent reversal) in spot FX rates,"
  *Journal of Multinational Financial Management* 37-38, 158-167, DOI
  `10.1016/j.mulfin.2016.11.001`.
- Stable repository record:
  `https://irep.ntu.ac.uk/id/eprint/35555/`.
- Complete postprint:
  `https://irep.ntu.ac.uk/id/eprint/35555/1/13113_Dao.pdf`, 710,603 bytes,
  SHA-256
  `46AD758FA8341903A4B03203152F8AE05D21B344356467BB3F0B62A1976E8642`.

The paper studies seven major and nine emerging USD pairs from 2002 through
May 2014. It defines a weekend gap as the log change from Friday's US close
to Monday's Australian open, classifies large gaps with empirical 5%, 10%,
and 15% tails, and observes subsequent returns at several horizons. Its
out-of-sample strategy estimates 5% tails from five years of weekly gaps,
trades opposite an extreme gap at Monday open, and exits at the end of the
week. GBP/USD is explicitly included.

The source uses Bloomberg spot fixes, precise global-session boundaries,
interest-rate series, and a long historical estimation window. The QM
carrier has native broker D1 OHLC only. No source return, alpha, drawdown,
cost, significance, trade count, crisis behavior, or weak-form-efficiency
claim transfers to the CFD experiment.

## Locked hypothesis

Weekend information can move the first executable GBPUSD quote beyond the
range implied by recent weekend gaps. When the current broker-D1 Monday-open
gap lies strictly beyond a trailing empirical tail, fade the gap and allow
the reversal the rest of the broker week.

At the first executable D1 tick after a genuine broker-week transition:

1. Require exact host `GBPUSD.DWX`, D1, a current broker-Monday D1 bar, and an
   immediately preceding completed broker-Friday D1 bar.
2. Define the current gap as
   `g_now = log(current_monday_open / prior_friday_close)`.
3. From a bounded oldest-to-newest D1 buffer, reconstruct exactly 52 prior
   non-overlapping weekend gaps. Every historical observation must be a
   positive-price Monday open immediately following a completed Friday close.
   Exclude the current gap.
4. Sort the 52 prior gaps ascending. Lock the lower threshold to index 5 (the
   sixth smallest) and the upper threshold to index 46 (the sixth largest).
   This is the deterministic nearest-rank 10% translation for a 52-week
   window.
5. Buy only when `g_now < lower`; sell only when `g_now > upper`; strict
   comparison means threshold ties consume the week flat.
6. Persist the normalized broker-week attempt key before history, signal,
   spread, ATR, sizing, margin, or order checks. Never retry that week.
7. Risk one fixed budget, attach a frozen `3.5*ATR(20,D1)` hard stop, use no
   target or scale-in, and close through the framework Friday 21:00 broker
   boundary. A seven-calendar-day stale guard and next-week repair flatten any
   survivor.

The 10% tails appear in the paper's overreaction tests, but its trading
strategy selects 5% tails and five years of estimation history. QM locks one
year and 10% solely as a pre-result activity/data translation: registered
`.DWX` history begins in 2017, while a five-year warm-up would starve the
2018-2022 Q02 window. This is an untested synthesis, not a source-exact
replication.

## Non-duplicate boundary

The corrected-root canonical checker scanned 4,751 registry identities,
1,389 card files, and 45 Strategy Wiki nodes. It found no exact or fuzzy
identity. Receipt:
`artifacts/qm5_gbpusd_weekend_tail_fade_preallocation_dedup_20260831.json`.

Manual mechanic review separates the nearest gap families:

- `QM5_10013_rw-fx-weekend-gap` uses a fixed `0.35*ATR` gap threshold, a gap-
  fill target, and a 24-hour/Tuesday exit. This rule uses a trailing empirical
  distribution, no gap-fill target, and a full-week hold.
- `QM5_12494_lean-gap-fade` detects every broker-day M1 boundary with a
  rolling close standard deviation and exits after five M1 bars. This rule is
  Monday-only, D1, empirical-tail qualified, and weekly.
- `QM5_11458_goodwin-friday-monday-gap-d1` enters from Friday range/close
  breakout structure and exits Monday. This rule observes the subsequent
  Monday gap and enters against it through Friday.
- `QM5_10946_zuck-weekend-cont` enters long late Friday before the gap and
  exits Monday. This rule enters after the observed gap in either direction.
- commodity and index weekend-gap sleeves use different carriers and mostly
  fixed ATR/point thresholds; none ranks 52 completed GBPUSD weekend gaps.

Verdict:
`DISTINCT_GBPUSD_WEEKLY_CURRENT_GAP_VERSUS_TRAILING_52_WEEK_EMPIRICAL_TAIL_CONTRARIAN_FRIDAY_EXIT`.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_BOUNDARY`: one durable AI source ID plus a
  complete peer-reviewed institutional-repository postprint with exact GBPUSD
  membership; the 52-week/10% translation is explicit.
- R2 `PASS`: week clock, current and historical gap identity, exact 52-sample
  membership, order-statistic indexes, strict tails, side, consumed attempt,
  fixed risk, stop, spread, and exits are locked.
- R3 `PASS_WITH_BROKER_DAY_PROXY_RISK`: registered `GBPUSD.DWX` D1 history
  covers 2017-2026. Broker D1 boundaries proxy the paper's Australian-open and
  US-close fixes; holidays, DST, gaps, financing, and CFD/spot basis remain
  binding risks.
- R4 `PASS`: native timestamps and OHLC, finite sort/comparison arithmetic,
  ATR risk control, quotes, positions, deals, and persistent state only; no
  ML, trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, significance, independence,
decorrelation, or portfolio fitness. Q02 kills zero trades, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, future leakage, malformed Friday-Monday pairs, wrong sorting or
tail indexes, missing stop, invalid risk mode, or nondeterminism. Failure may
not be rescued by changing the window, tail, direction, carrier, stop, or
hold.

This packet authorizes one card, deterministic identity/magic allocation, one
branch-only non-live build, strict Q01, and one paced Q02 handoff only while
the whole-host CPU ceiling remains clear. It authorizes no manual tester run,
live/demo/shadow/stress/optimization preset, AutoTrading action, `T_Live`
change, deploy/live manifest, portfolio-gate edit, correlation waiver, or
portfolio admission.
