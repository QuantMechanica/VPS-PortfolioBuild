# QM5_12958_nnfx-hma-wae-swing - Strategy Spec

**EA ID:** QM5_12958  
**Slug:** `nnfx-hma-wae-swing`  
**Source:** `CEO-SWING-SLATE-2026-07-02`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements the approved NNFX HMA + Waddah-Attar D1 swing card. A long
entry requires the last closed D1 close to cross above HMA(20) and the bullish
WAE trend value to exceed both the deadzone and explosion lines. Shorts mirror
the same logic below HMA(20). The initial stop is 1.5 x ATR(14). Management
closes 50% at +1.0 x ATR(14), moves the stop to breakeven, and exits the
remainder when the last closed D1 close crosses to the opposite side of HMA(20).

The WAE implementation is deterministic MACD momentum expansion compared
against Bollinger-band width and a point-based deadzone.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_hma_period` | 20 | NNFX baseline |
| `strategy_wae_fast_macd` | 12 | WAE MACD fast period |
| `strategy_wae_slow_macd` | 26 | WAE MACD slow period |
| `strategy_wae_signal_macd` | 9 | WAE MACD signal period |
| `strategy_wae_bb_period` | 20 | Explosion-line Bollinger period |
| `strategy_wae_bb_deviation` | 2.0 | Explosion-line Bollinger deviation |
| `strategy_wae_sensitivity` | 150.0 | WAE trend sensitivity |
| `strategy_wae_deadzone_points` | 15.0 | Deadzone in symbol points |
| `strategy_atr_period` | 14 | ATR period for stop and partial trigger |
| `strategy_sl_mult` | 1.5 | Initial ATR stop multiple |
| `strategy_partial_tp_mult` | 1.0 | Partial trigger in ATR units |
| `strategy_partial_fraction` | 0.50 | Fraction closed at partial |

## 3. Symbol Universe

- `XAUUSD.DWX`, magic slot 0.
- `GDAXI.DWX`, magic slot 1.
- `EURJPY.DWX`, magic slot 2.

## 4. Timeframe

- Base timeframe: D1.
- Entry gating: `QM_IsNewBar()`.
- Signal reads use closed D1 bars.

## 5. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. Friday close defaults to
disabled for this approved swing hold class.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-02 | Initial WS3 build from approved card |
