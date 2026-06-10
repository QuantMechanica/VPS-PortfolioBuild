# QM5_9249_mql5-bb-angle — Strategy Spec

**EA ID:** QM5_9249
**Slug:** `mql5-bb-angle`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA detects asymmetric Bollinger Band angle skew on H1 bars to anticipate breakout direction. For a long signal, the lower band must rise faster than the upper band across the last three closed bars (lower_move >= skew_factor * upper_move), and the latest close must break above the upper band. For a short signal, the upper band must fall faster than the lower band, with the latest close breaking below the lower band. Entry is placed at the market open of the next bar. The position is closed when price crosses back through the middle Bollinger Band or after 36 H1 bars (failsafe). An ATR(14)-based stop-loss (1.6×) and 2.0R take-profit are applied at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10–50 | Bollinger Band period |
| `strategy_bb_dev` | 2.0 | 1.0–3.0 | Bollinger Band standard-deviation multiplier |
| `strategy_skew_factor` | 1.0 | 0.5–2.0 | Min ratio of lower-band-move to upper-band-move for long skew (and vice versa for short) |
| `strategy_atr_period` | 14 | 7–21 | ATR period for stop-loss sizing |
| `strategy_atr_sl_mult` | 1.6 | 1.0–3.0 | SL = entry ± ATR × mult |
| `strategy_tp_r_mult` | 2.0 | 1.0–4.0 | TP = SL distance × R multiple |
| `strategy_width_sma_period` | 50 | 20–100 | SMA period for bandwidth volatility filter |
| `strategy_max_hold_bars` | 36 | 10–100 | Failsafe time exit in H1 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Highest-liquidity FX major; Bollinger band patterns well-studied on EUR/USD H1
- `GBPJPY.DWX` — Volatile cross with strong directional moves; band skew reliably precedes breakouts
- `NDX.DWX` — Trend-prone index; volatility-expansion breakouts fit the band-angle mechanism

**Explicitly NOT for:**
- Low-volatility symbols where ATR-based stops create outsized lot sizes (e.g. USDCHF in low-vol regimes)

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~60 |
| Typical hold time | 4–36 hours |
| Expected drawdown profile | Moderate; ATR-based SL limits per-trade risk; time stop caps runaway holds |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 39): Relative Strength Index", MQL5 Articles, 2024-09-18 — Bands Orientation and Angle Changes, pattern 7
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9249_mql5-bb-angle.md`

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
| v1 | 2026-06-10 | Initial build from card | 45472dc6-bc22-4d5b-96e2-4451aa4dce22 |
