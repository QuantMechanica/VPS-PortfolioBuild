# WTI Fixed Week-Closing Segment Momentum - G0 Decision

Date: 2026-08-16

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-16_wti_week_closing_momentum_source_approval.md` at commit
`db5a2c257`.

## Candidate

- EA: `QM5_41020_wti-wclose-mom`, allocated by the deterministic registry
  command after source approval and semantic dedup review
- slug: `wti-wclose-mom`
- strategy ID: `MOP-WTI-WCLOSE-MOM-2026_S01`
- source ID: `MOP-WTI-WCLOSE-MOM-2026`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410200000`
- lifecycle: one Monday continuation entry from the completed prior
  Tuesday-to-Friday broker-week closing segment, held through Tuesday and
  closed at the first Wednesday D1 boundary

## Source Decision

The approved packet is
`strategy-seeds/sources/MOP-WTI-WCLOSE-MOM-2026/source.md`. Moskowitz, Ooi,
and Pedersen (2012) supply the own-return-sign continuation family and WTI's
membership in their commodity-futures universe. They do not test this exact
weekly formation or executable CFD package.

The fixed Tuesday-through-Friday sequence, Monday entry, 180-minute restart
boundary, Wednesday exit, CFD mapping, ATR stop, and fixed-dollar risk are QM
translation choices. No source return, coefficient, significance, cost,
density, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Rule

1. Admit decisions only on a genuine broker Monday D1 bar whose immediately
   preceding completed bars are exactly Friday, Thursday, Wednesday, and
   Tuesday. Never shift a missing holiday session.
2. Require the first observed Monday tick within 180 minutes of the current D1
   bar timestamp; consume a later observation flat.
3. Persist the exact Monday `yyyymmdd` attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates and never retry it.
4. Compute `log(PriorFridayClose / PriorTuesdayClose)` from positive finite
   completed closes only. BUY on a positive sign, SELL on a negative sign, and
   stay flat on exact zero or invalid history. Wednesday and Thursday are
   continuity observations; current Monday prices never enter the signal.
5. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0` budget, frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread cap.
   Signal magnitude never scales risk.
6. Close on the first genuine broker-Wednesday D1 boundary. Close malformed
   exposure, Thursday/Friday carry, or a position five calendar days old
   before entry-only gates. Framework Friday close at broker hour 21 remains
   enabled as an additional fail-safe.
7. Both news axes remain OFF. One owned position, no re-entry, scale-in,
   pyramid, grid, martingale, partial exit, trailing stop, or break-even move.

The weekday sequence, completed endpoints, sign, entry grace, no-shift and
no-retry rules, fixed risk, stop, spread, Wednesday exit, and stale repair are
load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_TRANSLATION_RISK`: peer-reviewed JFE paper, named
  authors, DOI, complete-paper receipt, durable hash, WTI membership, and an
  explicit untested weekly-horizon boundary.
- R2 `PASS`: signal endpoints, weekday sequence, sign, timing, attempt, risk,
  stop, spread, and exits are deterministic and frozen.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history supplies all runtime
  inputs.
- R4 `PASS`: native deterministic arithmetic and framework state only,
  without trained output, banned signal methods, external feeds, grid,
  martingale, scale-in, or pyramid.

Both deterministic card linters returned `status: ok` for both canonical card
copies before this decision was written. The copies had identical SHA-256
`6178A7574E69DCCB8C24041F1371BF3A06B119389A62AC2CB0B6A751DF6A3D8A`.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,507 registry rows and 603 root cards.
It found no exact identity match and raised only the expected fuzzy sibling
`QM5_41019_wti-wopen-mom`. Manual review separates:

- the week-opening sibling, which forms Friday-to-Tuesday, enters Wednesday,
  and exits Friday; this candidate forms the disjoint Tuesday-to-Friday
  segment, enters Monday, and exits Wednesday;
- rolling one-week momentum, which uses a magnitude threshold, volatility-rank
  gate, any-new-day clock, and seven-day or reversal exit;
- Monday gap momentum/fades, which use the Monday opening gap and range or
  volatility thresholds;
- Monday slow-trend and unconditional weekday packages; and
- weekly range-breakout/fade and commodity oscillator families.

Registry row `21503,xti-weekly-tsmom-lowvol` has no card, EA directory,
setfile, or magic row in this branch; it is not an already-built mechanic, but
its family-level name is disclosed in the source packet and card.

Verdict:
`CLEAN_WTI_FIXED_WEEK_CLOSING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

The atomic `farmctl reserve-ea-ids` command allocated `QM5_41020`; no ID was
inferred or hand-edited. Expected cadence is approximately 45-52 completed
positions/year. Q02 must retire on zero trades, below five/year, wrong or
shifted weekdays, current-bar leakage, late/repeated entries, carry past
Wednesday repair, invalid risk mode, nondeterminism, or nonpositive governed
economics. Q09 alone may establish realized portfolio correlation.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio-gate edits; portfolio
admission; and correlation waivers. Enqueue Q02 once, but do not dispatch or
control a tester when the factory resource ceiling is binding.
