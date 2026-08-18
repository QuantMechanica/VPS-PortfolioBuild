# QM5_36007 (nnfx-vidya-trix-fisher-momentum) Build & Verification Evidence

- Task ID: a7acf60d-9f28-4cfc-a080-061eb3aaedb9
- EA ID: QM5_36007
- Date: 2026-08-17
- Branch: agents/board-advisor
- Target symbols: EURUSD.DWX (slot 0), GBPJPY.DWX (slot 1), NZDCAD.DWX (slot 2)
- Timeframe: D1
- Magic Numbers: 360070000 (slot 0), 360070001 (slot 1), 360070002 (slot 2)

## Summary of Implementation

Implemented VP's No Nonsense Forex (NNFX) VIDYA & TRIX Momentum System mechanically per approved strategy card `QM5_36007_nnfx-vidya-trix-fisher-momentum.md`:
- Indicator Pipeline on D1: Variable Index Dynamic Average (VIDYA period 9 modulated by Chande Momentum Oscillator CMO 12) baseline, TRIX (triple EMA 14, signal 9) C1 trigger, Fisher Transform (period 10) C2 confirmation, Money Flow Index (MFI 14) volume gate, and ATR(14). Evaluated strictly at close of completed bar `[1]` (Shift = 1).
- Long Entry: `Close[1] > VIDYA[1]` AND `TRIX[1] > TRIX_Signal[1]` AND `Fisher[1] > 0.0` AND `MFI(14)[1] >= 50.0`.
- Short Entry: `Close[1] < VIDYA[1]` AND `TRIX[1] < TRIX_Signal[1]` AND `Fisher[1] < 0.0` AND `MFI(14)[1] <= 50.0`.
- Stop Loss: Placed at `1.0 * ATR(14, D1)[1]` distance from entry.
- Take Profit: Placed at `1.0 * ATR(14, D1)[1]` distance from entry.
- Break-Even: Move SL to Entry + 1.0 pip when open profit reaches +1.0R (1.0x ATR).
- Runner Exit: Close position when TRIX crosses opposing signal line (`TRIX < TRIX_Signal` for Long, `TRIX > TRIX_Signal` for Short).
- No-Trade Filter: Dynamic spread filter (`Spread > 1.8 * ATR(14, D1)[1]`) and rollover blackout 23:55–00:05 GMT.

## Verification Checklist

- **Magic Numbers Registry**: Registered portable DWX basket symbols in `framework/registry/magic_numbers.csv` (360070000 to 360070002).
- **Magic Resolver**: Regenerated `framework/include/QM/QM_MagicResolver.mqh` via `python framework/scripts/update_magic_resolver.py` (17,417 rows kept, 0 dropped).
- **SPEC Document**: Created `framework/EAs/QM5_36007_nnfx-vidya-trix-fisher-momentum/SPEC.md` and validated with `validate_spec_doc.py` -> PASS.
- **Compilation**: Compiled via `python tools/strategy_farm/compile_ea.py --ea-id 36007 --force --json` -> COMPILED (0 errors, 0 warnings; .ex5 size 394,006 bytes).
- **Setfile Generation**: Generated EURUSD.DWX, GBPJPY.DWX, NZDCAD.DWX D1 backtest setfiles in `sets/` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- **Build Guardrails**: Verified via `tools/strategy_farm/validate_build_guardrails.py` -> PASS (`max_news_stale_hours: 336`, `verdict: PASS`).

## State Disposition

Artifact ready for Codex review.
