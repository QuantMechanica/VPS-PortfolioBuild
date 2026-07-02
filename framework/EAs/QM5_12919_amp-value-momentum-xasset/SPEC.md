# QM5_12919_amp-value-momentum-xasset - Strategy Spec

**EA ID:** QM5_12919
**Slug:** `amp-value-momentum-xasset`
**Source:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

Once per month, the EA scores eight DWX instruments using the Asness-Moskowitz-Pedersen value plus momentum rule. Momentum is the 12-month return ending 21 trading days ago; value is the negative 60-month return ending 21 trading days ago. Both signals are cross-sectionally z-scored across the eligible universe, combined 50/50, and the EA goes long only when its chart symbol ranks in the top three. Positions are rechecked on the first trading day of each new month and closed when the chart symbol falls out of the top three.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_top_n` | 3 | 1-8 | Number of highest combined-score symbols eligible for long exposure. |
| `strategy_min_eligible_symbols` | 6 | 3-8 | Minimum symbols with enough D1 history required before any rank is valid. |
| `strategy_skip_recent_days` | 21 | 1-63 | Recent D1 bars excluded from both signals to avoid one-month reversal contamination. |
| `strategy_momentum_lookback_days` | 252 | 126-378 | D1-bar lookback for medium-horizon momentum. |
| `strategy_value_lookback_days` | 1260 | 756-1512 | D1-bar lookback for long-horizon reversal value. |
| `strategy_momentum_weight` | 0.50 | 0.0-1.0 | Weight applied to the momentum z-score. |
| `strategy_value_weight` | 0.50 | 0.0-1.0 | Weight applied to the value z-score. |
| `strategy_atr_period` | 14 | 5-50 | D1 ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | 3.0 | 1.0-6.0 | ATR multiple for the initial stop loss. |
| `strategy_rebalance_start_hour` | 0 | 0-23 | Earliest broker hour allowed for monthly rebalance actions. |
| `strategy_rebalance_end_hour` | 23 | 0-23 | Latest broker hour allowed for monthly rebalance actions. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap; zero disables the cap and remains DWX-safe. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - European equity-index sleeve in the AMP cross-asset subset.
- `NDX.DWX` - US growth equity-index sleeve in the AMP cross-asset subset.
- `UK100.DWX` - UK equity-index sleeve in the AMP cross-asset subset.
- `WS30.DWX` - US large-cap equity-index sleeve in the AMP cross-asset subset.
- `EURUSD.DWX` - G10 USD-cross FX sleeve.
- `GBPUSD.DWX` - G10 USD-cross FX sleeve.
- `USDJPY.DWX` - G10 USD-cross FX sleeve.
- `AUDUSD.DWX` - G10 USD-cross FX sleeve.

**Explicitly NOT for:**
- `XTIUSD.DWX` - commodity legs were excluded from this card's DWX subset.
- `XAUUSD.DWX` - metal exposure is intentionally excluded to keep this build focused on equity plus FX.
- Bond or rates proxies - no approved DWX bond/rates feed is available for this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | D1 closes and D1 ATR for monthly rank and stop placement |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` on the M30 chart; monthly cadence via `QM_CalendarPeriodKey(PERIOD_MN1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 monthly decisions, fewer actual entries per symbol because only top-three symbols are held |
| Typical hold time | Weeks to months |
| Expected drawdown profile | Moderate portfolio-style drawdowns with diversification across equity-index and FX symbols |
| Regime preference | Cross-asset trend plus long-horizon mean reversion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `afab7a6f-c3c8-51ae-a609-f376744beb8e`
**Source type:** `paper`
**Pointer:** SSRN 1363476, Asness, Moskowitz, and Pedersen, "Value and Momentum Everywhere"
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12919_amp-value-momentum-xasset.md`

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
| v1 | 2026-07-02 | Initial build from card | farm task 84c638cb-3129-4083-9bc9-5d4645b5af8b |
