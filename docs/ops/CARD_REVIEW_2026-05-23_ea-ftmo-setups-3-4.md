---
reviewer: claude
reviewed_at: 2026-05-23T18:20Z
tasks:
  - 6672fa16-701b-451b-b96d-1aacc77b04a9
  - 9abf0338-f1f0-49ad-a5e9-600d930b5c34
source: EA Trading Academy – The Complete FTMO Challenge (Set Ups Overview)
---

# G0 Card Review — FTMO Setups 3 & 4

## Review Scope

Cards produced by Gemini from video-extraction of EA Trading Academy FTMO Challenge course.
Prior cycle already RECYCLE'd Setups 1 (currency-strength-meter = not MT5 single-instrument
implementable; M1 infra gap) and 2 (impulse-end undefined; M1 infra gap; Fib retracement
persistence argument weak). Setups 3 and 4 use M5+ timeframes and avoid multi-pair signal
dependencies — key distinction.

---

## Setup 3 — 20 MA Trend Follower (ea-ftmo-set-up-3-20-ma_card.md)

**R-check:**
- r1_track_record: research (Tier 1 course, acceptable)
- r2_mechanical: true — SMA(20) + ADX(14) + candlestick pattern, all iCustom/iMA native in MT5
- r3_data_available: true — M5/M15 major pairs, no infra gap
- r4_ml_forbidden: true — no ML component

**Edge Lab compliance:**
- DD: ≤5% daily / ≤10% total — stated ✓
- News blackout: mandatory — stated ✓
- Horizon: scalping/swing — ✓
- No HFT, no martingale/grid — ✓
- Mechanical only — ✓

**Positive signals:**
- M5/M15 timeframes: avoids M1 infra gap entirely
- ADX(14) > 25 filter: well-defined, native MT5
- SMA(20) bounce: single-pair, single-instrument, no cross-asset data
- SL on close beyond MA: mechanical stop definition
- Expected 200 trades/year at M5/M15: plausible for major pairs

**Build-stage flags (not G0 blockers):**
1. "Clearly sloping" MA must be operationalized: e.g., MA[0] > MA[lookback] where lookback is
   a tunable parameter. Add to strategy_params before build_ea.
2. "Rejection candle (pin bar or engulfing)" needs precise mechanical definition: e.g.,
   pin bar = wick ≥ 2× body, engulfing = body[0] > body[1]. Codex to specify at build.
3. Swing high/low TP target requires N-bar lookback parameter. Add to strategy_params.
4. Overlap check with singh-trend-bouncer_card required at build (fingerprint validation).
5. strategy_params block missing from card — must be injected before build_ea.

**Falsification:** PF > 1.2 in ADX>25 trending markets over 200 trades — acceptable standard.

**Verdict: G0 APPROVED.** Concept is mechanically sound, MT5-implementable in single-instrument
mode, Edge Lab compliant. Build-stage will require parameter concretization.

---

## Setup 4 — Fibs Break Out (ea-ftmo-set-up-4-fibs-break-out_card.md)

**R-check:**
- r1_track_record: research (Tier 1 course, acceptable)
- r2_mechanical: true — range detection + breakout close + Fib extension targets
- r3_data_available: true — M15/H1, no infra gap
- r4_ml_forbidden: true — no ML component

**Edge Lab compliance:**
- DD: ≤5% daily / ≤10% total — stated ✓
- News blackout: mandatory — stated ✓
- Horizon: day trading (intraday swing at M15/H1) — ✓ (within Edge Lab scope)
- No HFT, no martingale/grid — ✓
- Mechanical only — ✓

**Positive signals:**
- M15/H1 timeframes: no infra gap
- Range consolidation breakout: defensible momentum continuation thesis (range tension release)
- Fib extensions (161.8%/261.8%) as TP scaling: used as R-multipliers from range height,
  not as "golden ratio" entry levels — distinction from Setup 2's retracement entry
- Tick-volume filter: MT5 FX tick volume, acknowledged limitation, still useful as relative
  activity proxy
- Expected 120 trades/year: plausible for M15/H1 range breaks

**Build-stage flags (not G0 blockers):**
1. Range detection "min 4 touches" needs a precise touch-detection spec: e.g., price within
   X pips of boundary on N-minute candle. Donchian or fractal approach both acceptable.
   Add touch_tolerance_pips and min_consolidation_bars to strategy_params.
2. Volume filter uses MT5 tick volume only — document this limitation in build_ea notes;
   do NOT claim real volume equivalence.
3. strategy_params block missing — must be injected before build_ea.
4. Fib extension caveat: 161.8%/261.8% are conventional TP targets; backtesting must
   validate which extension level performs better per-symbol (parametrize as fib_tp_level).

**Falsification:** >50% of breakouts reach 161.8% extension — specific and testable.

**Verdict: G0 APPROVED.** Range breakout with Fib extension TPs is mechanically implementable,
avoids the retracement "self-fulfilling" critique, uses M15/H1 (no infra gap), and is Edge Lab
compliant. Build-stage requires range-detection algorithm spec and strategy_params injection.

---

## Summary

| Task | Card | Verdict |
|------|------|---------|
| 6672fa16 | ea-ftmo-set-up-3-20-ma_card.md | APPROVED — M5/M15, ADX filter, single-pair, no infra gap |
| 9abf0338 | ea-ftmo-set-up-4-fibs-break-out_card.md | APPROVED — M15/H1, range-break momentum, Fib TP scaling |

Both cards require strategy_params blocks before build_ea routing.
