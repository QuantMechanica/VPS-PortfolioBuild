# QM5_10513_mql5-ichimoku - Strategy Spec

**EA ID:** QM5_10513
**Slug:** `mql5-ichimoku`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It opens long when Tenkan-sen crosses up through Kijun-sen and the completed close is above Senkou Span B. It opens short when Tenkan-sen crosses down through Kijun-sen and the completed close is below Senkou Span B. It closes an open position when the opposite signal appears, otherwise exits through the ATR stop, fixed 1.5R take profit, or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | MT5 timeframe enum | Timeframe used for Ichimoku signal reads. |
| `strategy_tenkan_period` | `9` | `1+` | Lookback for Tenkan midpoint. |
| `strategy_kijun_period` | `26` | `1+` | Lookback for Kijun midpoint. |
| `strategy_senkou_b_period` | `52` | `1+` | Lookback for Senkou Span B midpoint. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | `1.5` | `>0` | ATR multiple for stop distance. |
| `strategy_tp_rr` | `1.5` | `>0` | Take-profit distance in R multiples. |
| `strategy_max_spread_points` | `0` | `0+` | Optional spread block; zero disables it. |
| `strategy_session_enabled` | `false` | `true/false` | Optional time filter; disabled for baseline. |
| `strategy_session_start_hhmm` | `0` | `0-2359` | Session start if the optional time filter is enabled. |
| `strategy_session_end_hhmm` | `2359` | `0-2359` | Session end if the optional time filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary liquid FX pair listed in the card's R3 basket.
- `GBPUSD.DWX` - liquid FX pair listed in the card's R3 basket.
- `USDJPY.DWX` - liquid FX pair listed in the card's R3 basket.
- `XAUUSD.DWX` - liquid metals symbol listed in the card's R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build only registers verified DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `25` |
| Typical hold time | `days` |
| Expected drawdown profile | ATR-normalized trend-following losses, capped by fixed stop. |
| Regime preference | trend-confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/20148`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10513_mql5-ichimoku.md`

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
| v1 | 2026-05-28 | Initial build from card | 3233f292-8df5-4146-b7db-093a7d57f998 |
