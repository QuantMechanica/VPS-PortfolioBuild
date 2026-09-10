# XAU/XAG Fresh Two-Week Sign-Streak Continuation - Source Approval

Date: 2026-09-10

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced logical Q02 enqueue if the tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy sleeve mission delivered
to Codex on the `agents/board-advisor` branch. The mission names a market-neutral
`XAUUSD` / `XAGUSD` gold/silver basket as an allowed carrier, requires one new
non-duplicate structural low-frequency edge under reputable-source criteria and
fixed-risk backtests, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-wstreak2-cont`
- proposed strategy ID: `MOP-CME-XAUXAG-WSTREAK2-CONT-20260910_S01`
- proposed source ID: `MOP-CME-XAUXAG-WSTREAK2-CONT-20260910`
- carrier: exact `XAUUSD.DWX` / `XAGUSD.DWX` D1 paired basket
- state: the newest two completed-week gold-minus-silver returns have one
  strict common sign and the immediately preceding weekly return has the
  strict opposite sign, marking the streak's first two-week completion
- direction: follow the fresh relative streak for one broker week with an
  equal-notional opposite-leg package
- lifecycle: one consumed attempt on the first tradable bar of each broker
  week and first-later-week flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The bounded governed packets below were read completely before this approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, canonical committed-blob
   SHA-256 `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   covering Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
   Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, with a
   durable receipt for the complete 23-page author-hosted paper.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, canonical
   committed-blob SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   covering CME Group's gold/silver ratio and intermarket-spread research.

Moskowitz, Ooi, and Pedersen support testing own-return continuation across
liquid futures and report commodity-portfolio evidence. CME defines the
gold/silver relative-price carrier and explains the metals' differing economic
drivers. Neither source tests a fresh two-week relative-sign event, a Darwinex
continuous-CFD basket, equal-notional sizing, ATR stops, or this lifecycle.
Those are disclosed QM choices. No efficacy, density, neutrality,
CFD-equivalence, or decorrelation result transfers.

## Locked Mechanic

1. Repair malformed owned exposure before entry gates.
2. Require exact input-bound XAU D1 host and XAG D1 companion with synchronized
   timestamps; factory presets supply `XAUUSD.DWX` and `XAGUSD.DWX`.
3. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of the raw host-bar open, reconstruct the four
   immediately preceding consecutive completed synchronized week-end closes.
4. For completed week-end log-ratio endpoints `s0` newest through `s3` oldest,
   compute `r0=s0-s1`, `r1=s1-s2`, and `r2=s2-s3`. Qualify only strict
   `r0>0,r1>0,r2<0` or strict `r0<0,r1<0,r2>0`. Zero, a continuing older run,
   missing weeks, or timestamp disagreement remains flat.
5. Follow a fresh positive streak with BUY XAU / SELL XAG and a fresh negative
   streak with SELL XAU / BUY XAG. Return magnitude does not scale risk.
6. Persist the current Monday anchor before fallible entry gates. A rejected
   or failed attempt may not retry that week.
7. Target one-to-one absolute entry notional with at most 20 percent lot-step
   mismatch. Constrain combined normalized stop risk to one
   `RISK_FIXED=1000` package with `RISK_PERCENT=0`.
8. Attach one frozen `3.5*ATR(20,D1)` stop per leg, no target, and require
   XAU/XAG spreads at or below 1,500/500 points respectively.
9. Close the complete package at the first later Monday anchor or after ten
   elapsed calendar days. Never retry, trail, partially close, scale in, grid,
   martingale, or pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_SHORT_HORIZON_RELATIVE_TRANSLATION_RISK`: named peer-reviewed
  momentum research and official exchange carrier lineage; exact two-week
  relative continuation efficacy is untested.
- R2 `PASS`: endpoints, signs, fresh-state rule, sides, attempt, aggregate
  risk, stops, spreads, and lifecycle are deterministic.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU and
  XAG D1 histories supply every runtime market input.
- R4 `PASS`: deterministic native arithmetic and V5 state only; no banned
  indicator, ML, external runtime data, adaptive fit, grid, or martingale.

## Non-Duplicate Decision

`framework/scripts/research_dedup_check.py` scanned 4,898 registry rows, 1,508
repository cards, and 45 current Strategy Wiki nodes. It found no exact or
fuzzy identity and returned `CLEAN` in
`artifacts/qm5_41418_dedup_preallocation_20260910.json`.

Manual family review distinguishes the opposite-side `QM5_41417`, which fades
the same fresh event, and `QM5_41078`, which waits for a third same-sign week
and then fades it. `QM5_41414` follows a majority-sign flip over two overlapping
three-return windows, not the first completion of a two-week streak. Adjacent
two-return magnitude systems do not require the older opposite predecessor.
Verdict: `DISTINCT_XAUXAG_FRESH_TWO_WEEK_SIGN_STREAK_CONTINUATION`.

## Kill And Safety Boundary

An independent-sign design reference implies about thirteen raw events per 52
weeks before data and execution gates; this is a cadence hypothesis, not source
evidence. Q02 must retire below five completed packages per full post-warm-up
year, at zero trades or nonpositive governed economics, or on any data,
direction, attempt, basket, risk, lifecycle, or determinism defect.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings.
