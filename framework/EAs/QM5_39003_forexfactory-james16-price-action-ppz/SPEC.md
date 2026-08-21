# QM5_39003_forexfactory-james16-price-action-ppz — Strategy Spec

**EA ID:** QM5_39003
**Slug:** `forexfactory-james16-price-action-ppz`
**Source:** `forexfactory-james16-price-action-ppz-official-source`
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy mechanizes the James16 Price Action methodology on the Daily (D1) timeframe. It identifies multi-week Price Pivot Zones (PPZ) across a 20-bar lookback window and trades candlestick rejections (bullish/bearish Pinbars) that occur at confirmed PPZ levels aligned with the 21-period baseline Exponential Moving Average (EMA).

Long entry executes when a Bullish Pinbar forms with low approaching a PPZ support level and close above the 21 EMA. Short entry executes when a Bearish Pinbar forms with high approaching a PPZ resistance level and close below the 21 EMA. Stop loss is anchored beyond the pinbar extreme tail with a 2 pip buffer, and profit target is fixed at a 1:2.5 risk-to-reward ratio.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpPPZLookback` | 20 | 10-50 | Pivot zone detection lookback bars on D1 |
| `InpTrendEMA` | 21 | 14-34 | Dynamic baseline trend EMA period |
| `strategy_atr_period` | 14 | 7-28 | ATR period on D1 |
| `strategy_zone_atr_mult` | 0.50 | 0.20-1.00 | PPZ zone tolerance in ATR |
| `strategy_min_pin_atr_mult` | 0.50 | 0.25-1.00 | Minimum candle range as ATR multiple |
| `strategy_max_pin_atr_mult` | 3.50 | 2.00-5.00 | Maximum candle range as ATR multiple |
| `strategy_wick_frac` | 0.65 | 0.50-0.80 | Dominant rejection wick fraction of candle range |
| `strategy_body_frac` | 0.25 | 0.10-0.40 | Maximum body fraction of candle range |
| `strategy_sl_buffer_pips` | 2.0 | 1.0-5.0 | Stop loss buffer beyond pin extreme in pips |
| `strategy_tp_rr` | 2.5 | 1.5-4.0 | Take profit risk-to-reward multiple |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Liquid major FX pair with persistent price action respect for daily PPZ levels.
- `GBPUSD.DWX` — Major FX pair with high daily range and clean pinbar rejections.
- `XAUUSD.DWX` — Precious metal with strong institutional level rejections.

**Explicitly NOT for:**
- Non-DWX symbols absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | 2-5 days |
| Expected drawdown profile | < 3.8% maximum drawdown |
| Regime preference | Swing trend continuation and key level mean-reversion |
| Win rate target (qualitative) | High (60-70% win rate) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `forexfactory-james16-price-action-ppz-official-source`
**Source type:** `forum`
**Pointer:** `James16 (2005-2024). All Things Price Action. Forex Factory (>30M Views).`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_39003_forexfactory-james16-price-action-ppz.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Gemini build pass |
