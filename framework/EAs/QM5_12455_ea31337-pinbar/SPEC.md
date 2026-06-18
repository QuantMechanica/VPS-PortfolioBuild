# QM5_12455_ea31337-pinbar - Strategy Spec

**EA ID:** QM5_12455
**Slug:** ea31337-pinbar
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades an EA31337 Pinbar spinning-top reversal pattern on the last closed H1 bar. A long entry requires the closed candle to classify as a spinning top, RSI(20) below 32, and CCI(18) below 28.8 because the source default `SignalOpenMethod=2` enables the CCI filter. A short entry uses the inverse RSI threshold above 68 and CCI above 28.8. Stops are placed beyond the signal candle extreme and widened to at least 2.0 ATR(14), take profit is 1R, and positions close after 30 bars or on the opposite spinning-top reversal signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pattern_shift` | 1 | 1+ | Closed-bar shift used for the spinning-top candle. |
| `strategy_atr_period` | 14 | 1+ | ATR period for minimum stop distance. |
| `strategy_cci_period` | 18 | 1+ | CCI period on typical price. |
| `strategy_rsi_period` | 20 | 1+ | RSI period on close. |
| `strategy_signal_open_method` | 2 | 0+ | EA31337 source method bit mask; default enables CCI filter. |
| `strategy_signal_open_level` | 1.6 | >0 | Multiplier for RSI and CCI thresholds. |
| `strategy_max_spread_pips` | 4.0 | >0 | Maximum live spread; zero modeled DWX spread is allowed. |
| `strategy_spinning_body_max` | 0.35 | 0-1 | Maximum candle body as a fraction of full range. |
| `strategy_spinning_wick_min` | 0.50 | 0+ | Minimum upper/lower wick as a multiple of candle body. |
| `strategy_stop_atr_mult` | 2.0 | >0 | Minimum ATR multiple used to widen structure stop. |
| `strategy_stop_buffer_pips` | 1 | 0+ | Extra buffer beyond the signal candle extreme. |
| `strategy_take_rr` | 1.0 | >0 | Take-profit multiple of initial risk. |
| `strategy_close_bars` | 30 | 1+ | Maximum holding period in chart bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair suitable for OHLC candle and oscillator reversal logic.
- `GBPUSD.DWX` - liquid major FX pair in the card's suggested first universe.
- `USDJPY.DWX` - liquid major FX pair in the card's suggested first universe.
- `XAUUSD.DWX` - metal CFD with sufficient volatility for candle reversal signals.
- `GDAXI.DWX` - canonical available DWX DAX symbol; used as the matrix-valid port for card-stated `DAX.DWX`.

**Explicitly NOT for:**
- `DAX.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX` - not a canonical available DWX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 30 H1 bars |
| Expected drawdown profile | Mean-reversion losses during persistent one-way trends |
| Regime preference | Mean-reversion after short-term overextension |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** GitHub repository
**Pointer:** https://github.com/EA31337/Strategy-Pinbar/blob/master/Stg_Pinbar.mqh
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12455_ea31337-pinbar.md`

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
| v1 | 2026-06-18 | Initial build from card | c0237cc9-4275-49c7-9b91-a1b69b3e2c4f |
