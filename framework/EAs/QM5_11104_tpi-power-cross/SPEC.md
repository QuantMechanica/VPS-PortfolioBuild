# QM5_11104_tpi-power-cross - Strategy Spec

**EA ID:** QM5_11104
**Slug:** `tpi-power-cross`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H4 bars. It computes Bulls as the percentage of the last 45 bars where Bulls Power(10), defined as high minus EMA(10) of close, is positive, and Bears as the percentage of the last 45 bars where Bears Power(10), defined as low minus EMA(10) of close, is negative. It opens long when Bulls crosses above Bears and opens short when Bulls crosses below Bears. Existing opposite positions are closed on the opposite cross, and any position is also closed after 20 H4 bars if no opposite cross has occurred.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 fixed by card | Timeframe used for Total Power signal and ATR stop. |
| `strategy_lookback_period` | 45 | 10-200 | Number of completed bars used for Bulls/Bears percentage. |
| `strategy_power_period` | 10 | 2-100 | EMA period used in Bulls Power and Bears Power. |
| `strategy_atr_period` | 14 | 5-100 | ATR lookback for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.5-6.0 | Hard stop distance in ATR multiples. |
| `strategy_time_stop_bars` | 20 | 1-200 | Maximum holding period measured in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary P2 basket; liquid DWX forex major with OHLC data for Bulls/Bears Power.
- `GBPUSD.DWX` - Card R3 primary P2 basket; liquid DWX forex major with OHLC data for Bulls/Bears Power.
- `USDJPY.DWX` - Card R3 primary P2 basket; liquid DWX forex major with OHLC data for Bulls/Bears Power.
- `XAUUSD.DWX` - Card R3 primary P2 basket; liquid DWX gold symbol with OHLC data for Bulls/Bears Power.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no DWX test data is available for build or pipeline use.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 48 |
| Typical hold time | Opposite H4 power cross, capped at 20 H4 bars |
| Expected drawdown profile | Trend-cross system with fixed 2.0 ATR catastrophic stop |
| Regime preference | Bull/bear power trend-strength crossover |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** GitHub source repository and indicator implementation
**Pointer:** EarnForex Total-Power-Indicator repository, `TotalPowerIndicator.mq5`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11104_tpi-power-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | 7c09bfb5-926f-484e-a88e-8b8a899697c8 |
