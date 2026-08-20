# XAU/XAG Weekly Sign-Streak Reversion - Source Approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch on 2026-08-21. The mission names
a market-neutral `XAUUSD` / `XAGUSD` gold/silver-ratio basket as an allowed
carrier, requires one new non-duplicate structural low-frequency edge under
the reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-wstreak3-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026`
- carrier: exact `XAUUSD.DWX` / `XAGUSD.DWX` D1 paired basket
- state: the newest three completed-week gold-minus-silver returns have one
  strict common sign and the immediately preceding weekly return has the
  strict opposite sign, marking the streak's first three-week completion
- direction: fade the fresh relative streak for one broker week with an
  equal-notional opposite-leg package
- lifecycle: one consumed attempt on the first tradable bar of each broker
  week and first-later-week flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed packets below were read completely before this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`,
   covering Karsten Schweikert (2018), *Journal of Banking & Finance* 88,
   44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and the supplemental robust
   fractional-cointegration lineage recorded there.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   covering CME Group's gold/silver ratio-spread research.

The bounded child extraction is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026/source.md`.
No new online page, blocked content, inferred table value, or unrecorded source
is used.

Schweikert supports testing a potentially state-dependent long-run gold/silver
relationship rather than assuming one immutable equilibrium. CME defines the
ratio and supports treating gold and silver as one intermarket relative-value
carrier. Neither source tests a fresh three-week relative-sign streak, its
contrarian direction, Darwinex continuous CFDs, equal-notional sizing, ATR
stops, or this lifecycle. Those are disclosed QM choices. No efficacy,
density, neutrality, CFD-equivalence, or decorrelation result transfers.

## Locked Mechanic

1. Repair orphan, duplicate, same-side, wrong-symbol, wrong-magic, stopless,
   notional-invalid, later-week, or stale owned exposure before entry gates.
2. Require exact `XAUUSD.DWX` D1 host, exact `XAGUSD.DWX` D1 companion,
   synchronized timestamps, and locked backtest/news/Friday inputs.
3. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of raw host-bar open, reconstruct the five immediately
   preceding consecutive completed synchronized week-end closes for both legs.
4. For completed week-end log-ratio endpoints `s0` newest through `s4`
   oldest, compute `r0=s0-s1` through `r3=s3-s4`. Require positive finite
   prices and finite non-zero returns. Qualify only strict `r0,r1,r2>0` with
   `r3<0`, or strict `r0,r1,r2<0` with `r3>0`. Equality, zero, a non-fresh
   streak, missing weeks, or timestamp disagreement remains flat.
5. Fade a positive streak with SELL XAU / BUY XAG and a negative streak with
   BUY XAU / SELL XAG. Return magnitude does not scale risk.
6. Persist the current Monday anchor before spread, quote, ATR, sizing, news,
   or order gates. A rejected or failed attempt may not retry that week.
7. Target one-to-one absolute entry notional with at most 20 percent lot-step
   mismatch. Constrain combined broker-normalized stop risk to one
   `RISK_FIXED=1000` package.
8. Attach one frozen `3.5*ATR(20,D1)` stop per leg, no target, and require
   XAU/XAG spreads at or below 1,500/500 points respectively.
9. Keep both news axes and Friday close OFF. Close the complete package at the
   first later Monday anchor or after ten elapsed calendar days. Never retry,
   trail, partially close, scale in, grid, martingale, or pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_STREAK_REVERSION_TRANSLATION_RISK`: one bounded
  `source_id` carries named peer-reviewed DOI and official exchange lineages;
  the three-week fade is explicitly an untested QM hypothesis.
- R2 `PASS`: endpoints, return orientation, strict fresh-streak state, side,
  attempt, aggregate risk, spreads, and lifecycle are locked and mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU
  and XAG D1 histories supply every runtime input; Q02 owns alignment and
  continuous-CFD basis falsification.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime data, adaptive fit, grid, martingale,
  scale-in, or pyramiding.

## Non-Duplicate Decision

The canonical `research_dedup_check.py` scan covered 4,565 registry rows and
625 root cards and returned `CLEAN`, with no exact or fuzzy match. Manual
family review distinguishes:

- `QM5_20275_gsr-runfade`, which requires five newest same-sign D1 relative
  returns plus a sixth-return break and exits on a counter-return, rather than
  three completed broker weeks and a fixed one-week hold;
- `QM5_41066`, `QM5_41075`, `QM5_41076`, and `QM5_41077`, which classify two
  adjacent completed-week relative returns by sign and magnitude rather than
  requiring a fresh three-week same-sign streak;
- `QM5_41060_xauxag-week-nr7-brk` and `QM5_41062_xauxag-wgap-fade`, which use
  range breakout and opposed weekend-gap states rather than completed-week
  relative-return signs;
- `QM5_41074_wti-wstreak3-mom`, which follows the same fresh sign-path topology
  on one outright WTI leg, while this candidate fades it on a paired relative-
  value carrier; and
- existing rolling ratio, fitted residual, robust-score, empirical-tail,
  calendar-rank, channel, flow-decomposition, and monthly-rank systems, none
  of which use this exact fresh completed-week relative-sign event.

The exact paired carrier, five synchronized week ends, four chronological
relative returns, strict `-+++` or `+---` state, contrarian package, weekly
attempt, equal-notional aggregate-risk package, and next-week exit are jointly
load-bearing. Verdict:
`CLEAN_XAUXAG_FRESH_THREE_WEEK_SIGN_STREAK_REVERSION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately five to nine completed packages per full
post-warm-up year. Q02 must retire below five per year, at zero trades or
nonpositive governed economics, or on any synchronization, week-anchor,
endpoint, return, sign, direction, attempt, basket, risk, lifecycle, or
determinism defect. No weak result may be rescued by changing streak length,
dropping the opposite predecessor, following instead of fading, changing the
hold, or adding a threshold, fitted center, beta, calendar, trend, or
volatility filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
