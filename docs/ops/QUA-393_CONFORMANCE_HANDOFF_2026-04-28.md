# QUA-393 Conformance Handoff (SRC04_S03 P1)

## Implemented artifacts
- EA: `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.mq5`
- Default set: `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.set`
- Compile evidence: `framework/build/compile/20260428_104214/QM5_SRC04_S03_lien_fade_double_zeros.compile.log`
- Smoke evidence (default set): `artifacts/qua-393-smoke/QM5_40303/20260428_104540/summary.json`

## Card-to-code mapping
1. Card §4 entry logic (20MA counter-trend + stop orders around nearest round)
- Implemented in `OnStrategyBar()`.
- MA filter via `SMAAtShift(trend_ma_period, 1)`.
- Round anchor via `NearestRound()` with step `100 pips` or `1000 pips` when `triple_zero_only=true`.
- Pending entries:
  - Long: `entry = round + entry_offset_pips`.
  - Short: `entry = round - entry_offset_pips`.
- Stop anchor:
  - Long SL: `round - stop_offset_pips`.
  - Short SL: `round + stop_offset_pips`.

2. Card §5 exit logic
- Initial hard stop implemented at order placement.
- Trailing implemented in `ApplyTrailLogic()`:
  - Default: 2-bar low/high trail.
  - Variant: MA trail (`use_ma_trail_variant=true`).
- 1R BE step implemented (`one_r = entry_offset_pips + stop_offset_pips`) with SL move to entry.

3. Card §8 default parameters
- `trend_ma_period=20`
- `entry_offset_pips=12`
- `stop_offset_pips=20`
- `triple_zero_only=false`
- Timeframe for smoke execution: `M15`
- Additional implementation parameter: `stage_max_distance_pips=50` (matches card default) and `order_expiration_minutes=60`.

## Verification status
- Compile: PASS (`errors=0`).
- Smoke with default set: PASS, deterministic, non-zero trades.
  - Run 1 trades: 1249
  - Run 2 trades: 1249

## Review flags for CTO/Quality-Tech
- TP1 partial close is now explicit: at 1R, EA calls PositionClosePartial(50%) and moves SL to BE before continuing trail.
- `stage_max_distance_pips` guard exists (card allows this as default 50 with sweep variants); confirm default is acceptable for strict card interpretation.
- `NO_REAL_TICKS_MARKER` present in smoke summary (run accepted via `AllowMissingRealTicksLogMarker`).

