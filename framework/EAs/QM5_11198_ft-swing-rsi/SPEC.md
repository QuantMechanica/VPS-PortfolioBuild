# QM5_11198_ft-swing-rsi - Strategy Spec

**EA ID:** QM5_11198
**Slug:** ft-swing-rsi
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only M15 oscillator reversals. On each closed M15 bar it enters when CCI(72) is below -175 and RSI(36) is below 90, then sends a market buy on the next bar with an ATR(14) x 2.0 stop. It exits when CCI(66) rises above -106 and RSI(45) rises above 88, or when the source ROI ladder is reached: 27.058% immediately, 8.53% after 33 minutes, 4.093% after 64 minutes, and 0% after 244 minutes. V5 Friday close and news blackout remain active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_buy_cci_time` | 72 | 36-80 | CCI lookback for long entry. |
| `strategy_buy_cci` | -175.0 | -200 to -125 | CCI entry threshold; long only below this value. |
| `strategy_buy_rsi_time` | 36 | 20-50 | RSI lookback for long entry. |
| `strategy_buy_rsi` | 90.0 | 60-90 | RSI entry ceiling. |
| `strategy_sell_cci_time` | 66 | 36-80 | CCI lookback for source exit. |
| `strategy_sell_cci` | -106.0 | fixed card default | CCI source-exit threshold. |
| `strategy_sell_rsi_time` | 45 | 20-60 | RSI lookback for source exit. |
| `strategy_sell_rsi` | 88.0 | fixed card default | RSI source-exit threshold. |
| `strategy_atr_stop_period` | 14 | fixed P2 baseline | ATR period for stop placement. |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | ATR multiplier for initial stop. |
| `strategy_max_spread_stop_frac` | 0.08 | fixed card default | Maximum spread as a fraction of planned stop distance. |
| `strategy_warmup_bars` | 80 | fixed card default | Minimum oscillator warmup depth. |
| `strategy_roi_0m_pct` | 27.058 | source default | Profit threshold from entry time. |
| `strategy_roi_33m_pct` | 8.53 | source default | Profit threshold after 33 minutes. |
| `strategy_roi_64m_pct` | 4.093 | source default | Profit threshold after 64 minutes. |
| `strategy_roi_244m_pct` | 0.0 | source default | Profit threshold after 244 minutes. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major in the card's portable oscillator basket.
- `GBPUSD.DWX` - liquid FX major in the card's portable oscillator basket.
- `USDJPY.DWX` - liquid FX major in the card's portable oscillator basket.
- `XAUUSD.DWX` - liquid metal in the card's portable oscillator basket.

**Explicitly NOT for:**
- `SPY.DWX` - not present in the DWX matrix and not part of this card's R3 basket.
- `SPX500.DWX` - not the canonical available S&P 500 custom symbol.
- `BTCUSD.DWX` - source crypto mechanics were explicitly ported to FX/metals for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | `minutes to about 4 hours under the ROI ladder` |
| Expected drawdown profile | `medium; ATR stop with frequent oscillator-reversal entries` |
| Regime preference | `mean-revert / oscillator reversal` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `GitHub strategy source`
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/SwingHighToSky.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11198_ft-swing-rsi.md`

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
| v1 | 2026-06-08 | Initial build from card | 2b625790-835f-417e-8a9b-4029fd5cf8f3 |
