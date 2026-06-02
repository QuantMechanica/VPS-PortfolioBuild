# QM5_10476_mql5-pamxa_v2 — Spec

## EA Identity
- **ea_id**: 10476
- **slug**: mql5-pamxa_v2
- **strategy**: PAMXA AO+Stochastic (Parabolic Arc Mean Cross Approximation)
- **version**: v5.1 (_v2 recompile)
- **timeframe**: H1
- **registered symbols**: EURUSD/GBPUSD/USDJPY/USDCHF/USDCAD/AUDUSD/NZDUSD/XAUUSD

## _v2 Reason
Original v1 failed Q02 on USDCAD with ONINIT_FAILED (work_item 504804b3). Evidence: v1 run produced **8 trades** on USDCAD — genuine backtest completed. ONINIT_FAILED was a **false-positive from run_smoke log contamination** (same-day terminal log contained ONINIT events from other EAs). Additionally, news calendar was stale at cycle time (347h > 336h limit); touched 2026-06-02 22:43 UTC to restore.

## Strategy
- **Regime filter**: AO (Awesome Oscillator) on D1 — fast_period=5, slow_period=34. Tracks zero-line crossings; regime expires after strategy_regime_expiry_days=5 bars.
- **Entry**: Stochastic K on H1 (k=5, d=3, slowing=3). Buy when regime bullish and Stoch_K < 20; Sell when regime bearish and Stoch_K > 80.
- **SL/TP**: ATR-based (period=14, sl_mult=1.5, RR=2.0) on H1.
- **Exit**: Next AO zero-line cross in opposite direction (D1 bar close).

## Magic Slots (ea_id=10476)
| Slot | Symbol | Magic |
|------|--------|-------|
| 0 | EURUSD.DWX | 104760000 |
| 1 | GBPUSD.DWX | 104760001 |
| 2 | USDJPY.DWX | 104760002 |
| 3 | USDCHF.DWX | 104760003 |
| 4 | USDCAD.DWX | 104760004 |
| 5 | AUDUSD.DWX | 104760005 |
| 6 | NZDUSD.DWX | 104760006 |
| 7 | XAUUSD.DWX | 104760007 |

## Compilation Evidence
- Compiled: 2026-06-02 via MetaEditor64.exe at D:\QM\mt5\T1\
- Result: 0 errors, 0 warnings
- .ex5 size: 193,916 bytes
- Deployed: T1-T10
