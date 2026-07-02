# QM5_12914_xau-weekly-donchian-swing - Strategy Spec

**EA ID:** QM5_12914  
**Slug:** `xau-weekly-donchian-swing`  
**Source:** `CEO-SWING-SLATE-2026-07-02`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements the approved XAUUSD D1 Turtle-class Donchian swing card. It
opens long when the last closed D1 close breaks above the prior 55-bar high and
opens short when the last closed D1 close breaks below the prior 55-bar low.
Open positions exit on the opposite 20-bar channel break or the ATR trail.

The OnTick path follows the WS3 canonical order: kill-switch, Friday close,
NoTradeFilter, management, strategy exit, entries-only news gate, new-bar gate,
entry.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_donchian_entry_period` | 55 | Prior D1 high/low breakout lookback |
| `strategy_donchian_exit_period` | 20 | Opposite-channel exit lookback |
| `strategy_atr_period` | 20 | ATR period for initial stop and trail |
| `strategy_atr_trail_mult` | 2.5 | ATR multiple for stop/trail |

## 3. Symbol Universe

- `XAUUSD.DWX`, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Entry gating: `QM_IsNewBar()`.
- Indicator reads use closed bars (`shift >= 1`).

## 5. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest | RISK_FIXED | 1000 |
| Live, if approved later | RISK_PERCENT | Allocated by portfolio process |

Friday close defaults to disabled for this multi-week swing card.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-02 | Initial WS3 build from approved card |
