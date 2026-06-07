# QM5_11179_ft001-ema-ha - Strategy Spec

**EA ID:** QM5_11179
**Slug:** `ft001-ema-ha`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades long only on M5 bars. It enters when EMA(20) crosses above EMA(50) on the last closed bar, the Heikin-Ashi close is above EMA(20), and the Heikin-Ashi candle is bullish. Open positions use the source ROI ladder, a source -10% stop mapped to a broker SL for V5 risk sizing, and a discretionary close when EMA(50) crosses above EMA(100) with bearish Heikin-Ashi confirmation.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast` | 20 | 12-30 | Fast EMA used for long entry cross and Heikin-Ashi close confirmation. |
| `strategy_ema_mid` | 50 | 35-75 | Middle EMA used for entry cross and exit cross. |
| `strategy_ema_slow` | 100 | 75-150 | Slow EMA used for warmup and exit cross. |
| `strategy_stoploss_pct` | 10.0 | 3-10 | Source stoploss percent mapped to the initial long SL. |
| `strategy_roi_0_pct` | 5.0 | 1-5 | Source minimum ROI at entry and initial TP. |
| `strategy_roi_20_pct` | 4.0 | 1-5 | Source minimum ROI after 20 minutes. |
| `strategy_roi_30_pct` | 3.0 | 1-5 | Source minimum ROI after 30 minutes. |
| `strategy_roi_60_pct` | 1.0 | 1-5 | Source minimum ROI after 60 minutes. |
| `strategy_max_spread_atr_pct` | 10.0 | 0-25 | M5 spread guard as a maximum percent of EMA-slow-period ATR. |
| `strategy_ha_warmup_bars` | 120 | 102-250 | Closed-bar OHLC depth used to seed the Heikin-Ashi open calculation. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair from the card's primary P2 basket.
- `GBPUSD.DWX` - liquid major FX pair from the card's primary P2 basket.
- `USDJPY.DWX` - liquid major FX pair from the card's primary P2 basket.
- `XAUUSD.DWX` - liquid metals CFD from the card's primary P2 basket.

**Explicitly NOT for:**
- `SPY.DWX` - not present in the DWX symbol matrix.
- `SPX500.DWX` - not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | `about 476 minutes from source README sample` |
| Expected drawdown profile | `medium; source fixed stop is -10% but V5 lot sizing limits account risk` |
| Regime preference | `short-timeframe trend continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `GitHub strategy repository`
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Strategy001.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11179_ft001-ema-ha.md`

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
| v1 | 2026-06-07 | Initial build from card | 175c7d29-fcb2-44d8-a78c-0a86bce346ce |
