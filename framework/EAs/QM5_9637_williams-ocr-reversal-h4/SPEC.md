# QM5_9637_williams-ocr-reversal-h4 — Strategy Spec

**EA ID:** QM5_9637
**Slug:** `williams-ocr-reversal-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA identifies H4 bars with a large body relative to their ATR14 (open-close range >= 0.85 × ATR14) — called an OCR setup bar. A bull OCR setup signals a strong up-move; if within the next two H4 bars price briefly trades above the setup bar's high by 0.05 × ATR (false continuation pierce) but then closes back below the setup bar's open, the continuation has failed. The EA enters short at market on the next bar open, with stop-loss above the highest high seen since setup plus 0.20 × ATR, and take-profit at 1.6R. A time stop closes the trade after 10 H4 bars; an immediate close triggers if price closes back beyond the original OCR extreme. The mirror logic applies for bear OCR setups triggering long entries.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 5–30 | ATR lookback period used for OCR ratio and stop sizing |
| `strategy_ocr_min_ratio` | 0.85 | 0.5–1.5 | Minimum body/ATR ratio to qualify a bar as an OCR setup |
| `strategy_pierce_atr_mult` | 0.05 | 0.01–0.20 | ATR multiplier above/below setup extreme required for a pierce |
| `strategy_range_filter_mult` | 3.0 | 1.5–5.0 | Setup bars with total range > N × ATR are rejected |
| `strategy_sl_atr_mult` | 0.20 | 0.10–0.50 | ATR buffer beyond running extreme for stop-loss placement |
| `strategy_tp_rr` | 1.6 | 1.0–3.0 | Take-profit as multiple of initial risk (R) |
| `strategy_time_stop_bars` | 10 | 5–20 | Maximum H4 bars held before forced close |
| `strategy_atr_median_period` | 100 | 50–200 | Lookback for ATR median volatility filter |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major; H4 OCR patterns well-documented in Williams' work
- `GBPUSD.DWX` — liquid FX major with sufficient volatility for OCR bodies
- `USDJPY.DWX` — liquid FX major; trend/momentum dynamics suit false-continuation reversals
- `XAUUSD.DWX` — gold spot; high ATR and sharp reversal moves align with OCR false-continuation

**Explicitly NOT for:**
- Index CFDs — not in card's target basket for this EA; index-specific versions may be separate

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H4)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~45 |
| Typical hold time | 8–40 hours (2–10 H4 bars) |
| Expected drawdown profile | Moderate; mean-reversion profile with tight SL |
| Regime preference | Mean-reversion after false breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/1255877-conversation-with-market-master-larry-williams
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9637_williams-ocr-reversal-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | a5980fd7-f8b8-4c22-8e64-2962ddf0068e |
