# QM5_35007 (inside-bar-momentum-breakout-system) Build & Verification Evidence

- Task ID: c0f9d1e3-582f-4842-86d4-9b37950b32c0
- EA ID: QM5_35007
- Date: 2026-08-17
- Branch: agents/board-advisor
- Target symbols: EURUSD.DWX (slot 0), GBPUSD.DWX (slot 1), USDJPY.DWX (slot 2)
- Timeframe: H4
- Magic Numbers: 350070000 (slot 0), 350070001 (slot 1), 350070002 (slot 2)

## Summary of Implementation

Implemented Robopip's Inside Bar Momentum Breakout System mechanically per approved strategy card `QM5_35007_inside-bar-momentum-breakout-system.md`:
- Inside Bar Condition: Evaluated on completed bars (Shift=1 and Shift=2). `High[1] < High[2]` AND `Low[1] > Low[2]`. `Mother_Range = High[2] - Low[2]`.
- Long Entry: Place BUY_STOP order at Mother High (`High[2] + 2.0 pips`) or BUY market order if already broken out on open.
- Short Entry: Place SELL_STOP order at Mother Low (`Low[2] - 2.0 pips`) or SELL market order if already broken out on open.
- Stop Loss: Placed at `0.20 * Mother_Range` from entry price (clamped to at least 5 pips).
- Take Profit: Placed at `2.0 * Mother_Range` from entry price (1:2.0 Risk:Reward ratio).
- Cancellation / Expiry: Cancel unfulfilled pending stop orders after 3 H4 bars (`strategy_pending_expiry_bars = 3`).
- Break-Even / Trailing: Move SL to Entry + 1.0 pip when open profit reaches +1.0R.
- No-Trade Filter: Dynamic spread filter (`Spread > 1.8 * ATR(14, H4)[1]`) and rollover blackout 23:55–00:05 GMT.

## Verification Checklist

- **Magic Numbers Registry**: Registered portable DWX basket symbols in `framework/registry/magic_numbers.csv` (350070000, 350070001, 350070002).
- **Magic Resolver**: Regenerated `framework/include/QM/QM_MagicResolver.mqh` via `python framework/scripts/update_magic_resolver.py` (17,391 rows kept, 0 dropped).
- **SPEC Document**: Created `framework/EAs/QM5_35007_inside-bar-momentum-breakout-system/SPEC.md` and validated with `validate_spec_doc.py` -> PASS.
- **Compilation**: Compiled via `python tools/strategy_farm/compile_ea.py --ea-id 35007 --force --json` -> COMPILED (0 errors, 0 warnings; .ex5 size 390,456 bytes).
- **Setfile Generation**: Generated EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX H4 backtest setfiles in `sets/` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- **Build Guardrails**: Verified via `tools/strategy_farm/validate_build_guardrails.py` -> PASS (`max_news_stale_hours: 336`, `verdict: PASS`).

## State Disposition

Artifact ready for Codex review.
