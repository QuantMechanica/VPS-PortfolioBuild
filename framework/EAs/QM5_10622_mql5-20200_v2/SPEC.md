# QM5_10622_mql5-20200_v2 — Spec

## EA Identity
- **ea_id**: 10622
- **slug**: mql5-20200_v2
- **strategy**: 2020 Price Difference Hour Filter
- **version**: v5.1 (_v2 recompile)
- **timeframe**: H1
- **registered symbols**: EURUSD/GBPUSD/USDJPY/XAUUSD

## _v2 Reason
Original v1 failed Q02 on USDJPY with ONINIT_FAILED (work_item 89a8ba19, 0 trades). Root cause: v1 .ex5 was compiled on 2026-05-31 before `update_magic_resolver.py` was run for ea_id=10622. The compiled registry lacked slot 2 (USDJPY), so `QM_MagicChecked(10622, 2)` returned -1 → INIT_FAILED. Additionally, news calendar staleness (347h > 336h) was also a contributing factor; touched 2026-06-02 22:43 UTC to restore.

_v2 compiled against current QM_MagicResolver.mqh (slot 2 = USDJPY registered as magic 106220002).

## Strategy
- **Signal**: At each H1 bar opening, check if broker UTC hour equals `strategy_trade_hour_gmt` (default 18:00 UTC).
- **Entry direction**: Compare `iOpen(t1_shift)` vs `iOpen(t2_shift)`. If diff_points >= delta → BUY; if <= -delta → SELL.
- **SL/TP**: Fixed points (stop_loss=2000pts, take_profit=200pts).
- **Exit**: Fixed SL/TP only + Friday close.

## Magic Slots (ea_id=10622)
| Slot | Symbol | Magic |
|------|--------|-------|
| 0 | EURUSD.DWX | 106220000 |
| 1 | GBPUSD.DWX | 106220001 |
| 2 | USDJPY.DWX | 106220002 |
| 3 | XAUUSD.DWX | 106220003 |

## Compilation Evidence
- Compiled: 2026-06-02 via MetaEditor64.exe at D:\QM\mt5\T1\
- Result: 0 errors, 0 warnings
- .ex5 size: 185,916 bytes
- Deployed: T1-T10
