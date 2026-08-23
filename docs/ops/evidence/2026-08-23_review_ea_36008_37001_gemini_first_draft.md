# Claude review_ea — QM5_36008 / QM5_37001 (Gemini first-draft builds)

**Router tasks:** `b92a7b1b-ee6c-4e1c-85f7-6d37e1c747ee` (QM5_36008),
`44c27df5-5676-4697-89d2-e17c399a0d4f` (QM5_37001)
**Reviewer:** Claude (headless orchestration cycle), 2026-08-23
**Reason:** `codex_review_required_for_gemini_code`, `source_verdict: DRAFT_READY_FOR_CODEX_REVIEW`

## Scope

Both are fresh Gemini first-draft builds (not remediations). Per CLAUDE.md
hard rules, Gemini-authored code requires mandatory Codex review before
acceptance; this is the Claude-side correctness pass and does not substitute
for it. Both tasks stay in `REVIEW`.

## QM5_36008 — nnfx-gold-kama-vortex-supertrend (XAUUSD/XTIUSD, D1)

- **Card fidelity**: KAMA/Vortex/TSI/WAE indicator math, entry conditions,
  1.0×ATR stop, and rollover-blackout logic (correctly uses `TimeGMT()`, not
  raw broker time) all match the approved card. **Material gap**: the card's
  §3.4/§5 trade-management lifecycle — 50% partial close at +1.0×ATR (TP1),
  then move SL to break-even, then trail the runner — is entirely
  unimplemented. `Strategy_ManageOpenPosition()` is an empty no-op and no
  `strategy_tp_atr_mult` input is even declared. This is a genuine omission,
  not a house convention: the same-author sibling **QM5_36001** (reviewed
  above in the 36001/36004 doc) ships exactly this lifecycle via
  `QM_TM_PartialClose` + `QM_TM_MoveSL`. Minor: the card's 2.0% daily-loss
  circuit breaker (§3.1.3) isn't visibly wired in the EA's own no-trade
  filter (may be intentionally delegated to the framework kill-switch —
  open question, not confirmed either way).
- **Unwired-input check**: all 18 `strategy_*` inputs have real use sites.
  No unwired-input defect (the problem here is the inverse — a lifecycle
  parameter the card implies is *missing* entirely, not an input that's
  declared-but-unused).
- **Host-slot/magic binding**: `req.symbol_slot` bound directly from
  `qm_magic_slot_offset`. `magic_numbers.csv` rows 17453-17454: 2 active
  rows, slots 0-1 (XAUUSD/XTIUSD), magics 360080000/360080001, no collision
  with neighboring EAs.
- **Risk mode**: both setfiles `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- **News guardrail**: `qm_news_stale_max_hours=336` — at the ceiling.
- **Build evidence**: `build_check_passed=true`, `compile_succeeded=true`,
  `smoke_result="deferred_p2_smoke"` — confirmed this is the standard
  sanctioned path (all 15 build_result JSONs on the box currently carry the
  same value), not an anomaly specific to this EA.
- **No ML/no invented values**: only `QM_Common.mqh` include, no ML library,
  single-position no grid/martingale, all thresholds trace to the card.
- **Look-ahead**: none — all indicator reads at shift≥1.

**QM5_36008 verdict: RECYCLE-leaning.** The single blocking finding is the
missing TP1-partial + break-even lifecycle the card mandates — everything
else (indicator math, magic/risk/news wiring, no look-ahead, build evidence)
is clean.

## QM5_37001 — ernest-chan-ornstein-uhlenbeck-statarb (AUDUSD/USDCAD/NZDUSD, H1)

- **Card fidelity**: the OU regression itself is correctly implemented —
  discrete `Δx_t = a + b·x_{t-1}` OLS, `theta=-ln(1+b)`, `half_life=ln2/theta`,
  `mean=-a/b`, z-score computed against shift-1 closed bars, entry/exit
  z-thresholds (±2.0 entry, -0.15/+0.15 TP, ±3.5 SL) all match the card.
  **Material bug**: the time-stop (line ~274) uses the fixed constant
  `strategy_max_half_life` (40 bars) instead of the freshly-computed
  per-trade `ou.half_life` (computed ~21 lines earlier and left unused), so
  the card's adaptive "force close after 2.5×τ bars" degrades to a fixed
  100-bar hold for every trade regardless of that trade's actual estimated
  half-life — a real behavioral divergence, and the presence of the unused
  correct variable right next to the bug is a strong signal this is an
  implementation slip, not a design choice. **Secondary finding**: the
  rollover blackout uses `TimeGMT()` rather than the framework's sanctioned
  `QM_BrokerToUTC(TimeCurrent())` — same class of issue as a note on 36008,
  bounded impact here (a 10-minute H1 no-trade window) but still a deviation
  from the framework convention. Minor: `Strategy_ManageOpenPosition` is a
  no-op, but the card's own §3 operative rules (as opposed to the §5
  lifecycle diagram) don't require BE/trailing, so this is low severity.
- **Unwired-input check**: all 11 `strategy_*` inputs drive real behavior.
  No unwired inputs.
- **Host-slot/magic binding**: bound directly from `qm_magic_slot_offset`.
  `magic_numbers.csv` rows 17450-17452: 3 active rows, slots 0-2
  (AUDUSD/USDCAD/NZDUSD), magics 370010000-2, no collision with neighbors.
- **Risk mode**: all 3 setfiles `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- **News guardrail**: `qm_news_stale_max_hours=336` — at the ceiling.
- **Build evidence**: same `deferred_p2_smoke` standard path as above,
  `build_check_passed=true`, `compile_succeeded=true`.
- **No ML/no invented values**: OU estimation is pure hand-rolled MQL5 OLS
  (`MathLog`/`MathSqrt`), no ML/statistical library despite the obvious
  temptation for this strategy class. No martingale/grid.
- **Look-ahead**: none — `CopyRates` starts at shift 1, regression window is
  entirely closed bars.

**QM5_37001 verdict: RECYCLE-leaning.** Single most important reason: the
time-stop uses the constant half-life bound instead of the computed
per-trade half-life, defeating the card's adaptive exit. Two required fixes
before pipeline: (1) time-stop → use `ou.half_life`; (2) rollover blackout →
`QM_BrokerToUTC(TimeCurrent())` instead of `TimeGMT()`. The OU core itself
(regression, entry/exit thresholds, bindings, risk mode, no ML/look-ahead)
is sound.

## Disposition

Both tasks move to `REVIEW`, not `APPROVED`/`RECYCLE` — Codex must
independently confirm before either RECYCLE disposition is executed, per the
standing hard rule for Gemini-authored code.
