# QM5_12581_eia-rbob-crack - Strategy Spec

**EA ID:** QM5_12581
**Slug:** `eia-rbob-crack`
**Source:** `EIA-RBOB-CRACK-SEASON-2025`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It trades D1 breakouts only inside EIA-documented gasoline crack-spread
seasonal windows: long breakouts from March through August, short breakdowns
from September through October, and flat otherwise. Positions exit on opposite
channel breaks, when their seasonal window ends, or after a fixed maximum hold.

The strategy is intentionally not a duplicate of `QM5_12576_eia-wti-season`:
that EA uses monthly SMA/ROC confirmation and includes winter petroleum-support
long months. This EA uses channel breakouts during gasoline crack-spread
windows only. It also differs from `QM5_12579_eia-wti-aftershock` and
`QM5_12567_cum-rsi2-commodity`.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_channel` | 20 | 15-40 | Previous-bar channel for entry breakout |
| `strategy_exit_channel` | 10 | 7-20 | Previous-bar channel for exit breakout |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-5.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 70 | 45-95 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Typical hold: days to several weeks.
- Regime preference: WTI upside breakouts during gasoline crack-spread support and downside breakdowns during autumn crack-spread decline.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Gasoline crack spreads rise ahead of
the summer driving season", This Week in Petroleum, March 12, 2025, URL
https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
