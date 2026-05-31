# QM5_10578_mql5-zldem - Strategy Spec

**EA ID:** QM5_10578
**Slug:** `mql5-zldem`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA trades the ColorZerolagDeMarker cloud cross on closed H3 bars. It builds a fast line from five weighted DeMarker calculations, then builds the slow line by smoothing that fast line. A long opens when the latest closed bar crosses from fast <= slow to fast > slow; a short opens when it crosses from fast >= slow to fast < slow. Open long positions close on the next bearish cross, and open short positions close on the next bullish cross, with the framework also enforcing the ATR stop, fixed target, news, Friday close, and kill-switch exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H3` | M1-MN1 | Timeframe used for the closed-bar ColorZerolagDeMarker signal. |
| `strategy_signal_bar` | `1` | >=1 | Closed bar shift used for signal evaluation. |
| `strategy_smoothing` | `15` | >1 | Slow-line smoothing denominator from the source indicator. |
| `strategy_factor1` | `0.05` | >=0 | Weight for the first DeMarker component. |
| `strategy_demarker_period1` | `8` | >1 | Lookback for the first DeMarker component. |
| `strategy_factor2` | `0.10` | >=0 | Weight for the second DeMarker component. |
| `strategy_demarker_period2` | `21` | >1 | Lookback for the second DeMarker component. |
| `strategy_factor3` | `0.16` | >=0 | Weight for the third DeMarker component. |
| `strategy_demarker_period3` | `34` | >1 | Lookback for the third DeMarker component. |
| `strategy_factor4` | `0.26` | >=0 | Weight for the fourth DeMarker component. |
| `strategy_demarker_period4` | `55` | >1 | Lookback for the fourth DeMarker component. |
| `strategy_factor5` | `0.43` | >=0 | Weight for the fifth DeMarker component. |
| `strategy_demarker_period5` | `89` | >1 | Lookback for the fifth DeMarker component. |
| `strategy_atr_period` | `14` | >0 | ATR lookback for the P2 hard stop. |
| `strategy_atr_sl_mult` | `2.0` | >0 | ATR multiplier for the hard stop. |
| `strategy_take_profit_rr` | `1.5` | >0 | Fixed target in R multiples from the stop distance. |
| `strategy_max_spread_points` | `0` | >=0 | Optional maximum spread filter; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - Source test used GBPJPY H3 and the oscillator logic is portable to DWX FX.
- `EURUSD.DWX` - Liquid DWX major FX pair in the approved R3 basket.
- `USDJPY.DWX` - Liquid DWX major FX pair in the approved R3 basket.
- `XAUUSD.DWX` - Liquid DWX metal in the approved R3 basket.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 pipeline requires registered `.DWX` instruments for research and backtest.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H3` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | H3 closed-bar oscillator crosses should usually hold from hours to days. |
| Expected drawdown profile | Moderate oscillator reversal/trend-following drawdowns, bounded by ATR(14) 2.0 hard stops. |
| Regime preference | Oscillator cloud-color cross regimes with directional follow-through. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/14065
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10578_mql5-zldem.md`

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
| v1 | 2026-05-29 | Initial build from card | c6b9e52b-0454-4cb5-9629-d89032017c35 |
