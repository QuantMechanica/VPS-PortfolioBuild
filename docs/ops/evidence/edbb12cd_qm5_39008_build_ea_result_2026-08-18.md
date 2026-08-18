# QM5_39008 (forexfactory-symphonie-matrix-system) Build & Verification Evidence

- Task ID: edbb12cd-1198-421e-a029-738fe8b825be
- EA ID: QM5_39008
- Date: 2026-08-18
- Branch: agents/board-advisor
- Target symbols: EURUSD.DWX (slot 0), GBPUSD.DWX (slot 1), USDCHF.DWX (slot 2)
- Timeframe: H1
- Magic Numbers: 390080000 (slot 0), 390080001 (slot 1), 390080002 (slot 2)

## Summary of Implementation

Implemented Symphonie Matrix Trend Following system mechanically per approved strategy card `QM5_39008_forexfactory-symphonie-matrix-system.md`:
- Indicator Pipeline: Unanimous consensus across 4 sub-modules:
  1. Symphonie Trendline: Close vs EMA(20).
  2. Symphonie Extreme: RSI(14) vs 50.0 midline.
  3. Symphonie Emotion: MACD(12,26,9) Main vs Signal.
  4. Symphonie Sentiment: Stochastic(5,3,3) %K vs %D.
- Long Entry: evaluated on new closed H1 bar when all 4 indicators agree Bullish on bar [1] and were not all Bullish on bar [2] (`bull[1] && !bull[2]`).
- Short Entry: evaluated on new closed H1 bar when all 4 indicators agree Bearish on bar [1] and were not all Bearish on bar [2] (`bear[1] && !bear[2]`).
- Risk & Money Management: Stop Loss set to entry ± $1.5 \times \text{ATR}(14, \text{H1})[1]$ clamped between `[0.5 * ATR, 3.5 * ATR]`; Take Profit set to 1:2.0 Risk:Reward ($2.0 \times \text{SL\_Distance}$).
- Position Management: Move Stop Loss to Break-Even at $+1.0\text{R}$ profit ($+1.0 \times \text{SL\_Distance}$).
- Exit Signal: Position closed if unanimous consensus flips opposite position direction.
- No-Trade Filter: Spread filter (`> 1.8 * ATR(14, H1)[1]`) and rollover blackout (23:55-00:05).

## Verification Checklist

- **Magic Numbers Registry**: Registered 3 target DWX symbols in `framework/registry/magic_numbers.csv` (390080000, 390080001, 390080002).
- **Magic Resolver**: Regenerated `framework/include/QM/QM_MagicResolver.mqh` via `python framework/scripts/update_magic_resolver.py` (17,501 rows kept, 0 dropped).
- **SPEC Document**: Generated `framework/EAs/QM5_39008_forexfactory-symphonie-matrix-system/SPEC.md` and validated with `validate_spec_doc.py` -> PASS.
- **Compilation**: Compiled via `python tools/strategy_farm/compile_ea.py --ea-id 39008 --force --json` -> COMPILED (0 errors, 0 warnings; .ex5 size 396,520 bytes).
- **Setfile Generation**: Generated `EURUSD.DWX`, `GBPUSD.DWX`, and `USDCHF.DWX` H1 backtest setfiles in `sets/` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- **Build Guardrails**: Verified via `tools/strategy_farm/validate_build_guardrails.py` -> PASS (max_news_stale_hours: 336, verdict: PASS).

## State Disposition

Artifact ready for Codex review.
