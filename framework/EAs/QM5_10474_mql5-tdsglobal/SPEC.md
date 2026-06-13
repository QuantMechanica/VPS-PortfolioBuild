# QM5_10474_mql5-tdsglobal - Strategy Spec

**EA ID:** QM5_10474
**Slug:** mql5-tdsglobal
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades the TDSGlobal pending-limit reversal pattern from the approved card. On each closed Work TimeFrame bar, it compares the latest MACD main value with the prior bar, derives OsMA as MACD main minus signal, and reads Force Index. A Sell Limit is placed above the prior bar high when MACD is non-falling, OsMA rises, and Force is negative; a Buy Limit is placed below the prior bar low when MACD is non-rising, OsMA falls, and Force is positive. Stop loss is 1.5 ATR(14), take profit is 2R, stale pending orders expire, and open positions close on an opposite setup.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_work_timeframe` | `PERIOD_H1` | M15-D1 practical sweep | Timeframe used for MACD, OsMA, Force, prior high/low, ATR, and pending expiry. |
| `strategy_macd_fast` | 12 | 1+ | Fast EMA period for MACD. |
| `strategy_macd_slow` | 26 | greater than fast | Slow EMA period for MACD. |
| `strategy_macd_signal` | 9 | 1+ | Signal period for MACD and OsMA derivation. |
| `strategy_force_period` | 24 | 1+ | EMA period for Force Index. |
| `strategy_entry_offset_points` | 1 | 1+ | Offset beyond the prior high/low for pending-limit placement. |
| `strategy_min_pending_points` | 16 | 1+ | Minimum pending-order distance from current Bid/Ask. |
| `strategy_pending_expiry_bars` | 24 | 0+ | Bars after which unfilled pending-limit orders expire; 0 disables explicit expiry. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for stop distance. |
| `strategy_atr_sl_mult` | 1.5 | greater than 0 | ATR multiplier for stop loss. |
| `strategy_reward_risk` | 2.0 | greater than 0 | Take-profit distance as an R multiple. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid DWX FX major.
- `GBPUSD.DWX` - card-listed liquid DWX FX major.
- `USDJPY.DWX` - card-listed liquid DWX FX major.
- `XAUUSD.DWX` - card-listed gold/commodity DWX symbol.
- `GDAXI.DWX` - matrix-verified DAX custom symbol used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | hours to a few days |
| Expected drawdown profile | bounded single-position pending-limit reversal risk with ATR stop. |
| Regime preference | momentum-confirmed pullback/reversal after local extension |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/23255 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10474_mql5-tdsglobal.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10474_mql5-tdsglobal.md`

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
| v1 | 2026-06-13 | Initial build from card | 2d548dc8-a4fd-4797-835a-521e97e883ce |
