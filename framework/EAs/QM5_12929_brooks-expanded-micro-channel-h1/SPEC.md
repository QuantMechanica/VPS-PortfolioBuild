# QM5_12929 Build Specification

- Strategy card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12929_brooks-expanded-micro-channel-h1.md`
- G0 status: `APPROVED`
- EA ID / slug: `12929` / `brooks-expanded-micro-channel-h1`
- Timeframe: `H1`
- Build scope: compile and non-live pipeline preparation only

## Framework alignment

| Card rule | Implementation |
|---|---|
| 8–20-bar HH/HL or LL/LH stair-step | `Strategy_DetectExpandedChannel` |
| 1.5 ATR no-thrust body gate | `Strategy_DetectExpandedChannel` |
| Best-fit slope ≥ 0.15 ATR/bar | `Strategy_RegressionSlope` |
| Per-bar compactness ≤ 0.50 ATR | `Strategy_DetectExpandedChannel` |
| SMA50/SMA200 macro bias | `Strategy_EntrySignal` via `QM_SMA` |
| Stop entry ±0.50 ATR, valid 3 bars | `Strategy_EntrySignal` with `QM_BUY_STOP` / `QM_SELL_STOP` |
| Structural SL buffer and 3 ATR cap | `Strategy_EntrySignal` |
| Fixed 2 ATR TP | `Strategy_EntrySignal` |
| Three-bar trail ±0.10 ATR | `Strategy_ManageOpenPosition` |
| 36-bar time stop | `Strategy_ExitSignal` |
| 12-bar reuse guard | `Strategy_ReuseGuardActive` |
| London/NY 07:00–21:00 broker session | `Strategy_SessionAllowsEntry` |
| Current spread ≤ 1.5 × 20-bar average | `Strategy_SpreadAllowsEntry` |
| Central news and Friday-close controls | V5 framework two-axis news gate and Friday-close handler |

## Registered P2 surface

`GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX`, `XAUUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`.

Backtest sets use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The EA contains no ML, grid, martingale, live enablement, or terminal-launch logic.
