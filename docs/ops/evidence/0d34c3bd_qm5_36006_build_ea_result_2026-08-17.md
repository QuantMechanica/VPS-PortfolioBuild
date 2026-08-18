# QM5_36006 (nnfx-halftrend-jurik-coppock-engine) Build & Verification Evidence

- Task ID: 0d34c3bd-8853-499b-b357-aa59d82fb534
- EA ID: QM5_36006
- Date: 2026-08-17
- Branch: agents/board-advisor
- Target symbols: EURUSD.DWX (slot 0), GBPUSD.DWX (slot 1), USDJPY.DWX (slot 2)
- Timeframe: D1
- Magic Numbers: 360060000 (slot 0), 360060001 (slot 1), 360060002 (slot 2)

## Summary of Implementation

Implemented VP's No Nonsense Forex (NNFX) HalfTrend & Jurik Velocity Engine mechanically per approved strategy card `QM5_36006_nnfx-halftrend-jurik-coppock-engine.md`:
- Indicator Pipeline on D1: HalfTrend (amplitude 2, ATR 100) non-repainting step baseline, Jurik Velocity (14-period JMA derivative) C1 trigger, Coppock Curve (ROC 14, ROC 11, WMA 10) C2 confirmation, Chaikin Money Flow (CMF 20) volume gate, and ATR(14). Evaluated strictly at close of completed bar `[1]` (Shift = 1).
- Long Entry: `Close[1] > HalfTrend[1]` AND `JurikVel[1] > 0.0` AND `Coppock[1] > 0.0` AND `CMF(20)[1] > 0.05`.
- Short Entry: `Close[1] < HalfTrend[1]` AND `JurikVel[1] < 0.0` AND `Coppock[1] < 0.0` AND `CMF(20)[1] < -0.05`.
- Stop Loss: Placed at `1.0 * ATR(14, D1)[1]` distance from entry.
- Take Profit: Placed at `1.0 * ATR(14, D1)[1]` distance from entry.
- Break-Even: Move SL to Entry + 1.0 pip when open profit reaches +1.0R (1.0x ATR).
- Runner Exit: Close position when HalfTrend direction flips (HalfTrend flips to downtrend for Long, HalfTrend flips to uptrend for Short).
- No-Trade Filter: Dynamic spread filter (`Spread > 1.8 * ATR(14, D1)[1]`) and rollover blackout 23:55–00:05 GMT.

## Verification Checklist

- **Magic Numbers Registry**: Registered portable DWX basket symbols in `framework/registry/magic_numbers.csv` (360060000 to 360060002).
- **Magic Resolver**: Regenerated `framework/include/QM/QM_MagicResolver.mqh` via `python framework/scripts/update_magic_resolver.py` (17,417 rows kept, 0 dropped).
- **SPEC Document**: Created `framework/EAs/QM5_36006_nnfx-halftrend-jurik-coppock-engine/SPEC.md` and validated with `validate_spec_doc.py` -> PASS.
- **Compilation**: Compiled via `python tools/strategy_farm/compile_ea.py --ea-id 36006 --force --json` -> COMPILED (0 errors, 0 warnings; .ex5 size 394,464 bytes).
- **Setfile Generation**: Generated EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX D1 backtest setfiles in `sets/` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- **Build Guardrails**: Verified via `tools/strategy_farm/validate_build_guardrails.py` -> PASS (`max_news_stale_hours: 336`, `verdict: PASS`).

## State Disposition

Artifact ready for Codex review.
