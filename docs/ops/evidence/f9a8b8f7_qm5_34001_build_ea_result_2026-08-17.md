# QM5_34001 (kalman-filter-state-estimation-scalper) Build & Verification Evidence

- Task ID: 9a8b8f7-3307-44d7-a1c4-2ad8c2a4cac9
- EA ID: QM5_34001
- Date: 2026-08-17
- Branch: gents/board-advisor
- Target symbols: EURUSD.DWX (slot 0), GBPUSD.DWX (slot 1), USDJPY.DWX (slot 2)
- Timeframe: M15
- Magic Numbers: 340010000 (slot 0), 340010001 (slot 1), 340010002 (slot 2)

## Summary of Implementation

Implemented Dmitry Fedoseev Kalman Filter Dynamic State Estimation Scalper mechanically per approved strategy card QM5_34001_kalman-filter-state-estimation-scalper.md:
- Discrete 1D Kalman Filter state estimation on closed M15 bar prices over 100-bar rolling history.
- State variable recursive prediction and measurement correction.
- Innovation Z-Score calculation: Z = y / sqrt(S).
- Long Entry: evaluated at bar close Shift=1 when Z[1] <= -2.00 AND Close[1] > Open[1].
- Short Entry: evaluated at bar close Shift=1 when Z[1] >= +2.00 AND Close[1] < Open[1].
- Risk & Money Management: initial Stop Loss set at 1.5 * ATR(14, M15)[1] distance; Take Profit placed at Kalman equilibrium state estimate.
- No-Trade Filter: spread filter (> 1.8 * ATR(14, M15)[1]) and 23:55-00:05 rollover blackout.

## Verification Checklist

- **Magic Numbers Registry**: Registered all 3 portable DWX basket symbols in ramework/registry/magic_numbers.csv (340010000, 340010001, 340010002).
- **Magic Resolver**: Regenerated ramework/include/QM/QM_MagicResolver.mqh via python framework/scripts/update_magic_resolver.py (17,349 rows kept, 0 dropped).
- **SPEC Document**: Created ramework/EAs/QM5_34001_kalman-filter-state-estimation-scalper/SPEC.md and validated with alidate_spec_doc.py -> PASS.
- **Compilation**: Compiled via python tools/strategy_farm/compile_ea.py --ea-id 34001 --force --json -> COMPILED (0 errors, 0 warnings; .ex5 size 386,674 bytes).
- **Setfile Generation**: Generated EURUSD.DWX, GBPUSD.DWX, and USDJPY.DWX M15 backtest setfiles in sets/ with RISK_FIXED=1000 and RISK_PERCENT=0.
- **Build Guardrails**: Verified via 	ools/strategy_farm/validate_build_guardrails.py -> PASS (max_news_stale_hours: 336, erdict: PASS).
- **Smoke Status**: deferred_p2_smoke recorded due to headless scheduled execution; Q02 will provide runtime backtest evidence.

## State Disposition

Artifact ready for Codex review.
