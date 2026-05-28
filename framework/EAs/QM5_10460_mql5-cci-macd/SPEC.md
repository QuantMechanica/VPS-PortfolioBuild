# QM5_10460_mql5-cci-macd - Strategy Spec

**EA ID:** QM5_10460
**Slug:** `mql5-cci-macd`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `sources/mql5-codebase-mt5-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades EURUSD.DWX on closed M15 bars. A long entry requires the closed candle above EMA(34), CCI(50) crossing upward through zero, and MACD(12,26,9) crossing above its signal line while the MACD main line is still below zero. A short entry mirrors the rule: the candle closes below EMA(34), CCI(50) crosses downward through zero, and MACD crosses below its signal line while the MACD main line is above zero. Initial stop distance is 1.5 x ATR(14), optionally tightened to the recent swing if that swing stop is closer; take profit is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | M1-MN1 | Timeframe used for EMA, CCI, MACD, ATR, and swing reads. |
| `strategy_ema_period` | `34` | 2-500 | EMA trend filter period. |
| `strategy_cci_period` | `50` | 2-500 | CCI zero-cross period. |
| `strategy_macd_fast` | `12` | 2-200 | MACD fast EMA period. |
| `strategy_macd_slow` | `26` | 3-400 | MACD slow EMA period. |
| `strategy_macd_signal` | `9` | 2-200 | MACD signal period. |
| `strategy_atr_period` | `14` | 2-200 | ATR period for baseline stop distance. |
| `strategy_atr_sl_mult` | `1.5` | 0.1-10.0 | ATR multiplier for initial stop. |
| `strategy_tp_rr` | `2.0` | 0.1-10.0 | Take-profit multiple of the final stop distance. |
| `strategy_swing_lookback` | `10` | 2-100 | Recent-bar lookback for optional swing stop tightening. |
| `strategy_structure_cap_r` | `2.5` | 0.5-10.0 | Maximum allowed structure-stop distance measured against the ATR stop. |
| `strategy_rollover_skip_minutes` | `15` | 0-120 | Blocks new entries during the first minutes after broker-day rollover. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-stated source and baseline symbol; available in the DWX symbol matrix.

**Explicitly NOT for:**
- Indices and commodities - the card describes a EURUSD M15 FX scalper and R3 only validates EURUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `85` |
| Typical hold time | intraday, minutes to hours |
| Expected drawdown profile | moderate scalper drawdown controlled by fixed 1.5 ATR stop and 2R target |
| Regime preference | momentum / trend-filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase, "CCI + MACD Scalper - expert for MetaTrader 5", author Dorde Milovancevic, published 2023-01-16, updated 2023-01-16, https://www.mql5.com/en/code/42283
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10460_mql5-cci-macd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | 03019dd7-2a87-4f8a-94a8-7294f393d964 |
