# QM5_9352_pring-kst-trend-deviation-h4 - Strategy Spec

**EA ID:** QM5_9352
**Slug:** `pring-kst-trend-deviation-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

This EA trades Martin Pring's Know Sure Thing momentum structure on H4 bars. It builds KST from four smoothed rate-of-change components: ROC(60) smoothed 60 bars, ROC(90) smoothed 60 bars, ROC(120) smoothed 60 bars, and ROC(180) smoothed 90 bars, weighted 1, 2, 3, and 4.

The trend baseline is SMA(KST, 90). The signal is the KST deviation, defined as KST minus SMA(KST, 90). Long entry fires on the close of an H4 bar when the deviation crosses from non-positive to positive, KST is higher than its value three closed H4 bars earlier, and close is above SMA(close, 200). Short entry is the mirror image: deviation crosses from non-negative to negative, KST is lower than three bars earlier, and close is below SMA(close, 200).

Initial stop loss is 2.5 * ATR(14). There is no take-profit. Existing positions exit on the opposite KST deviation zero-cross or after 60 closed H4 bars. Entries are skipped when live spread is greater than 0.15 * ATR(14). Only one position per magic is allowed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_roc1_bars` | 60 | 1-500 | First ROC lookback in H4 bars. |
| `strategy_roc2_bars` | 90 | 1-500 | Second ROC lookback in H4 bars. |
| `strategy_roc3_bars` | 120 | 1-500 | Third ROC lookback in H4 bars. |
| `strategy_roc4_bars` | 180 | 1-500 | Fourth ROC lookback in H4 bars. |
| `strategy_roc1_sma` | 60 | 1-300 | Smoothing length for ROC1. |
| `strategy_roc2_sma` | 60 | 1-300 | Smoothing length for ROC2. |
| `strategy_roc3_sma` | 60 | 1-300 | Smoothing length for ROC3. |
| `strategy_roc4_sma` | 90 | 1-300 | Smoothing length for ROC4. |
| `strategy_kst_trend_sma` | 90 | 1-300 | SMA baseline used to form KST deviation. |
| `strategy_price_sma_period` | 200 | 1-500 | Price trend filter on H4 closes. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for stop and spread normalization. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-10.0 | Stop distance in ATR multiples. |
| `strategy_spread_atr_mult` | 0.15 | 0.0-1.0 | Maximum allowed spread as a fraction of ATR. |
| `strategy_max_hold_h4_bars` | 60 | 1-500 | Time stop in closed H4 bars. |
| `strategy_warmup_bars` | 270 | 270-1000 | Minimum closed H4 bars before evaluating signals. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major, directional H4 momentum suitable for KST trend-deviation logic.
- `GBPJPY.DWX` - liquid FX cross with strong medium-term swings and useful portfolio diversity.
- `XAUUSD.DWX` - metal trend instrument from the approved card universe.
- `NDX.DWX` - equity index trend instrument from the approved card universe.

**Explicitly NOT for:**
- Symbols without reliable H4 history or symbols absent from the Darwinex Zero matrix.
- Ultra-short-horizon symbols or setfiles below H4, because the card rescales daily KST to H4 bars.
- Synthetic basket/pair symbols, because this implementation is a single-symbol trend EA per run.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H4)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 25 |
| Typical hold time | hours to about 10 trading days |
| Expected drawdown profile | trend-following whipsaws around flat KST regimes, controlled by ATR stops and time stop |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum plus book method reference
**Pointer:** ForexFactory post 13850000 and Martin Pring, Technical Analysis Explained, KST chapter; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9352_pring-kst-trend-deviation-h4.md`
**R1-R4 verdict (Q00):** all PASS; see the approved card.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV to mode validation is enforced by `QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-02 | Initial build from approved card | build commit pending |
