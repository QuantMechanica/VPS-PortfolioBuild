# QM5_34008 (multicurrency-basket-dispersion-hedger) Build & Verification Evidence

- Task ID: fa7ca587-77f8-4cea-b71b-7bb1b746b33d
- EA ID: QM5_34008
- Date: 2026-08-17
- Branch: agents/board-advisor
- Target symbols: EURUSD.DWX (slot 0), GBPUSD.DWX (slot 1), AUDUSD.DWX (slot 2), NZDUSD.DWX (slot 3), USDCAD.DWX (slot 4), USDCHF.DWX (slot 5), USDJPY.DWX (slot 6)
- Timeframe: H1
- Magic Numbers: 340080000 to 340080006

## Summary of Implementation

Implemented Andrey Khatimlianskii's Multi-Currency Basket Correlation Dispersion Hedger mechanically per approved strategy card `QM5_34008_multicurrency-basket-dispersion-hedger.md`:
- Universe: 7 USD pairs (EURUSD, GBPUSD, AUDUSD, NZDUSD, USDCAD, USDCHF, USDJPY).
- Dispersion Measure: 24-hour rate of change computed across all 7 basket pairs on H1 bar-close (Shift 1). Returns are USD-normalized to compute basket mean USD return, cross-sectional dispersion, and standard deviation ($\sigma$).
- Signal Generation: Z-score divergence evaluated per host symbol at Shift=1 against threshold (1.20 $\sigma$). Mean-reverting long/short entries triggered when the host pair deviates significantly from the USD basket mean.
- Exits: Stop Loss placed at 1.5x ATR(14, H1), Take Profit placed at 2.0x SL distance (1:2.0 Risk:Reward ratio).
- No-Trade Filter: Spread filter (`1.8 * ATR(14, H1)[1]`) and 23:55-00:05 rollover blackout.
- Symbol Scope Discipline: Bound via `basket_manifest.json`, `QM_SymbolGuardInit`, and `QM_BasketWarmupHistory`.

## Verification Checklist

- **Magic Numbers Registry**: Registered all 7 portable DWX basket symbols in `framework/registry/magic_numbers.csv` (340080000 - 340080006).
- **Magic Resolver**: Regenerated `framework/include/QM/QM_MagicResolver.mqh` via `python framework/scripts/update_magic_resolver.py` (17,367 rows kept, 0 dropped).
- **Basket Manifest**: Created `framework/EAs/QM5_34008_multicurrency-basket-dispersion-hedger/basket_manifest.json` -> validated as `BASKET_OK`.
- **SPEC Document**: Created `framework/EAs/QM5_34008_multicurrency-basket-dispersion-hedger/SPEC.md` and validated with `validate_spec_doc.py` -> PASS.
- **Compilation**: Compiled via `python tools/strategy_farm/compile_ea.py --ea-id 34008 --force --json` -> COMPILED (0 errors, 0 warnings; .ex5 size 388,442 bytes).
- **Setfile Generation**: Generated all 7 H1 backtest setfiles in `sets/` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- **Build Guardrails**: Verified via `tools/strategy_farm/validate_build_guardrails.py` -> PASS (`max_news_stale_hours: 336`, `verdict: PASS`).
- **Build Check**: `build_check.ps1` -> PASS (0 failures, 0 warnings).

## State Disposition

Artifact ready for Codex review.
