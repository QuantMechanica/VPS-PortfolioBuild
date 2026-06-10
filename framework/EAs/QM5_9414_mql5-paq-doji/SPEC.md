# QM5_9414_mql5-paq-doji — Strategy Spec

**EA ID:** QM5_9414
**Slug:** `mql5-paq-doji`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA detects a Doji candlestick exhaustion reversal on H1 bars. A qualifying Doji at bar[2] must have a body no larger than 10% of its total range, with both upper and lower wicks exceeding the body, and a total range at least 0.5× ATR(14) to exclude noise. A buy is triggered when the Doji appears after three consecutive lower closes (bars[3–5]) and bar[1] closes above the Doji high. A sell is triggered when the Doji appears after three consecutive higher closes and bar[1] closes below the Doji low. Entry fires at market on the open of bar[0].

Stop is placed below the Doji low (buy) or above the Doji high (sell), offset by 0.25×ATR(14). Take-profit is set at 1.5× the initial risk distance. Discretionary exits: opposite confirmed Doji signal, price trading back through the Doji midpoint intrabar, or a 18-H1-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_doji_body_ratio` | 0.10 | 0.03–0.20 | Max body/totalRange ratio for Doji classification |
| `strategy_atr_period` | 14 | 7–21 | ATR lookback period for range filter and stop sizing |
| `strategy_atr_range_min_mult` | 0.50 | 0.20–1.00 | Minimum totalRange = mult × ATR to exclude micro-Doji |
| `strategy_atr_sl_mult` | 0.25 | 0.10–1.00 | Stop distance offset = mult × ATR from Doji extreme |
| `strategy_tp_r_mult` | 1.50 | 1.00–3.00 | Take-profit distance in multiples of initial risk |
| `strategy_max_hold_bars` | 18 | 6–48 | Time exit after N H1 bars (server-time approximation) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major pair; H1 Doji patterns well-defined due to high tick density
- `GBPUSD.DWX` — liquid major pair with distinct candlestick structure on H1
- `USDJPY.DWX` — major pair; sufficient ATR range for non-degenerate Doji signals
- `XAUUSD.DWX` — gold exhibits clear exhaustion Doji patterns in trending regimes

**Explicitly NOT for:**
- Indices (NDX/WS30/GDAXI) — card targets FX + gold only; index tick structure differs

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~70 |
| Typical hold time | 1–18 hours |
| Expected drawdown profile | Moderate mean-reversion; TP at 1.5R limits adverse excursions |
| Regime preference | mean-reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 24): Price Action Quantification Analysis Tool", MQL5 Articles, 2025-05-22
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9414_mql5-paq-doji.md`

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
| v1 | 2026-06-10 | Initial build from card | 2520c036-1730-4e7c-b057-278ef1d59b74 |
