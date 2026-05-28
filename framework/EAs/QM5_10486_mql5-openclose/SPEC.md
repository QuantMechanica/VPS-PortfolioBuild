# QM5_10486_mql5-openclose - Strategy Spec

**EA ID:** QM5_10486
**Slug:** `mql5-openclose`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates the last two completed H1 candles. It buys when candle #1 opened above candle #2's open and closed below candle #2's close, and it sells when candle #1 opened below candle #2's open and closed above candle #2's close. A long position closes when the latest completed candle has both a lower open and lower close than candle #2, while a short closes when the latest completed candle has both a higher open and higher close than candle #2. Each entry has a 1.25 x ATR(14) protective stop, a 1.5R target, and a 48 H1 bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_work_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for candle comparisons, ATR, and time-stop bars. |
| `strategy_atr_period` | `14` | `1+` | ATR lookback for the protective stop. |
| `strategy_atr_sl_mult` | `1.25` | `>0` | ATR multiplier for the initial stop distance. |
| `strategy_target_rr` | `1.5` | `>0` | Take-profit distance as a multiple of initial risk. |
| `strategy_time_stop_bars` | `48` | `0+` | Maximum holding time in `strategy_work_tf` bars; 0 disables. |
| `strategy_min_atr_points` | `0.0` | `0+` | Optional ATR floor in points; 0 leaves the unspecified P3 floor disabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary P2 basket forex symbol with DWX OHLC data.
- `GBPUSD.DWX` - Card R3 primary P2 basket forex symbol with DWX OHLC data.
- `USDJPY.DWX` - Card R3 primary P2 basket forex symbol with DWX OHLC data.
- `XAUUSD.DWX` - Card R3 primary P2 basket metal symbol with DWX OHLC data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not registered for DWX backtesting.

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
| Trades / year / symbol | `100` |
| Typical hold time | Up to 48 H1 bars |
| Expected drawdown profile | Fixed ATR stop with 1.5R target; losses bounded per trade by framework risk sizing. |
| Regime preference | Two-candle open/close reversal on H1 bars |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/23090`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10486_mql5-openclose.md`

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
| v1 | 2026-05-28 | Initial build from card | cdeac04d-ec05-4995-878b-cce90dec9dd7 |
