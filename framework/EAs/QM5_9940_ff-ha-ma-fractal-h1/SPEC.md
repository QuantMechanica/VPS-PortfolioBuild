# QM5_9940_ff-ha-ma-fractal-h1 - Strategy Spec

**EA ID:** QM5_9940
**Slug:** ff-ha-ma-fractal-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades H1 trend-continuation setups from the ForexFactory Heiken-Ashi System + Moving Average + Fractals card. A long setup requires the last three completed smoothed Heiken-Ashi bars to be bearish, bullish, bullish, the previous H1 close above LWMA(24) on HL/2, and a confirmed upper 5-bar fractal above current price; it places a buy stop at that fractal. A short setup mirrors the rule with bullish, bearish, bearish, the previous close below LWMA(24), and a confirmed lower fractal below current price. Pending orders are removed if Heiken-Ashi color flips before trigger; open trades exit early after two consecutive opposite smoothed Heiken-Ashi bars, otherwise exits are by SL, TP, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ha_first_period` | 6 | 1-50 | First smoothing period for Heiken-Ashi Smoothed; method fixed to SMMA per card method code 2. |
| `strategy_ha_second_period` | 2 | 1-20 | Second smoothing period for Heiken-Ashi Smoothed; method fixed to LWMA per card method code 3. |
| `strategy_lwma_period` | 24 | 2-200 | LWMA period on HL/2 used for trend gate and stop anchor. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for the maximum stop-distance cap and non-JPY port. |
| `strategy_fractal_lookback` | 60 | 5-300 | Search window for the latest confirmed 5-bar fractal. |
| `strategy_jpy_price_offset` | 0.20 | 0.01-5.00 | Fixed JPY-pair price offset for TP and SL from the card. |
| `strategy_nonjpy_tp_atr` | 1.50 | 0.10-10.00 | Non-JPY TP distance from entry in ATR units. |
| `strategy_nonjpy_sl_atr` | 0.80 | 0.10-10.00 | Non-JPY SL offset from LWMA in ATR units. |
| `strategy_max_sl_atr` | 2.20 | 0.50-10.00 | Skip entries whose entry-to-SL distance exceeds this ATR multiple. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - Card primary JPY-cross market for the original H1 setup.
- `EURJPY.DWX` - Card-approved JPY cross with the same HA, LWMA, and fractal mechanics.
- `GBPUSD.DWX` - Card-approved GBP FX pair; deterministic non-JPY ATR port is used for TP/SL offsets.
- `USDJPY.DWX` - Card-approved JPY pair with the same fixed 0.20 price-offset convention.

**Explicitly NOT for:**
- `SP500.DWX` - The card is FX/JPY-pair specific, not an equity-index strategy.
- `XAUUSD.DWX` - Metals are outside the card's R3 DWX FX basket.

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
| Typical hold time | Card does not state a numeric hold time; expected to be H1 swing holds controlled by fractal TP/SL and two-bar HA flip exit. |
| Expected drawdown profile | One active position per magic-symbol with fixed $1,000 backtest risk and ATR-capped stop distance. |
| Regime preference | H1 Heiken-Ashi trend-continuation and fractal breakout. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/374526-heiken-ashi-system-moving-average-fractals
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9940_ff-ha-ma-fractal-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 077cca4e-860d-4603-89ab-de46d9a9cc2b |
