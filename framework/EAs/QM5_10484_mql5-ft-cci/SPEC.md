# QM5_10484_mql5-ft-cci - Strategy Spec

**EA ID:** QM5_10484
**Slug:** `mql5-ft-cci`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates closed H1 bars. It treats the moving average as rising when MA[1] is greater than MA[2], and falling when MA[1] is less than MA[2]. In a rising MA regime it buys when CCI crosses upward through -100 and sells when CCI crosses downward through +200. In a falling MA regime it buys when CCI crosses upward through +100 and sells when CCI crosses downward through -200. Open positions close on an opposite signal, a fixed 2R target, ATR stop, or after 80 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_work_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for MA, CCI, ATR, and time-stop bars. |
| `strategy_cci_period` | `14` | `1+` | CCI lookback period. |
| `strategy_ma_period` | `14` | `1+` | SMA lookback used to determine MA rising or falling regime. |
| `strategy_atr_period` | `14` | `1+` | ATR lookback for protective stop distance. |
| `strategy_atr_sl_mult` | `1.5` | `>0` | ATR multiplier for fixed protective stop. |
| `strategy_target_rr` | `2.0` | `>0` | Take-profit distance as a multiple of initial risk. |
| `strategy_time_stop_bars` | `80` | `0+` | Maximum holding time in `strategy_work_tf` bars; 0 disables. |

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
| Trades / year / symbol | `50` |
| Typical hold time | Up to 80 H1 bars |
| Expected drawdown profile | Fixed ATR stop with 2R target; losses bounded per trade by framework risk sizing. |
| Regime preference | MA-slope trend-filtered CCI reversal / continuation capture |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/23061`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10484_mql5-ft-cci.md`

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
| v1 | 2026-05-28 | Initial build from card | 3c6334fe-ff15-4559-85a6-159bd459a94b |
