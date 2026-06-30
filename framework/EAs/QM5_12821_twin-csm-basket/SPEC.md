# QM5_12821_twin-csm-basket - Strategy Spec

**EA ID:** QM5_12821
**Slug:** twin-csm-basket
**Source:** youtube-unconventionalforextrading-twin-2026
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA computes an eight-currency strength meter across the 28 major FX pairs. For each pair it measures percent change and adds the result to the base currency while subtracting it from the quote currency, producing a zero-sum strength table for USD, EUR, GBP, JPY, CHF, AUD, NZD, and CAD. A basket cycle can open only when the strongest and weakest currencies match on the closed H1 strength table and the closed D1 confirmation table, and the H1 max-minus-min strength gap is at least the configured threshold.

At an entry window, the EA focuses on the weakest currency and opens a cluster of up to six crosses against the strongest available counterpart currencies. If the weak currency is the quote side the leg is bought; if it is the base side the leg is sold. The whole basket is flattened when the aggregate floating P/L reaches the fixed basket take-profit, reaches the hard -1% basket equity stop, the session flat time arrives, framework Friday close fires, or the next closed-bar strength state shifts away from the active strong/weak pair.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_gap_threshold_pct` | 0.20 | 0.05-2.00 | Minimum H1 strength spread between strongest and weakest currencies. |
| `strategy_cluster_size` | 6 | 1-7 | Maximum number of weak-currency crosses opened in one basket cycle. |
| `strategy_atr_period` | 14 | 5-50 | H1 ATR period for per-leg protective stop distance and framework lot sizing. |
| `strategy_atr_sl_mult` | 1.5 | 0.5-5.0 | ATR multiple used for each leg's protective stop. |
| `strategy_basket_tp_pct` | 1.25 | 0.10-5.00 | Aggregate floating P/L percent of account equity that closes the basket in profit. |
| `strategy_basket_stop_pct` | 1.00 | fixed at 1.00 | DL-081 hard basket equity stop. |
| `strategy_london_start_hhmm` | 630 | 0-2359 | Broker-time start of London-open entry window. |
| `strategy_london_end_hhmm` | 830 | 0-2359 | Broker-time end of London-open entry window. |
| `strategy_overlap_start_hhmm` | 930 | 0-2359 | Broker-time start of London/New-York overlap entry window. |
| `strategy_overlap_end_hhmm` | 1000 | 0-2359 | Broker-time end of London/New-York overlap entry window. |
| `strategy_flat_hhmm` | 2100 | 0-2359 | Broker-time hard intraday flat time. |
| `strategy_deviation_points` | 20 | 0-100 | Maximum market-order deviation for basket leg sends. |
| `strategy_warmup_bars` | 320 | 80-1000 | H1 basket warmup bars requested during OnInit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `GBPUSD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `AUDUSD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `NZDUSD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `USDJPY.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `USDCHF.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `USDCAD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `EURGBP.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `EURJPY.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `EURCHF.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `EURAUD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `EURNZD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `EURCAD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `GBPJPY.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `GBPCHF.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `GBPAUD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `GBPNZD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `GBPCAD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `AUDJPY.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `AUDCHF.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `AUDNZD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `AUDCAD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `NZDJPY.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `NZDCHF.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `NZDCAD.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `CADJPY.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `CADCHF.DWX` - one of the 28 major FX crosses required by the CSM basket.
- `CHFJPY.DWX` - one of the 28 major FX crosses required by the CSM basket.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the strategy is an eight-currency relative-strength basket.
- Non-major FX crosses outside the 28 registered pairs - the CSM formula needs a complete major-currency graph.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H1 strength plus D1 strength confirmation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Intraday; flat before the broker-time US close window |
| Expected drawdown profile | Around 10% strategy drawdown with each basket cycle capped at 1% account equity ex-gap |
| Regime preference | Relative currency-strength divergence with intraday continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** youtube-unconventionalforextrading-twin-2026
**Source type:** video reconstruction
**Pointer:** `docs/research/unconventional_forex/T-WIN_STRATEGY_RECONSTRUCTION_2026-06-30.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12821_twin-csm-basket.md`

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
| v1 | 2026-06-30 | Initial build from card | af6dea49-cd31-4e5e-9b1b-bd61430cec0d |
