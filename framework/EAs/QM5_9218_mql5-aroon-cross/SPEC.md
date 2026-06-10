# QM5_9218_mql5-aroon-cross — Strategy Spec

**EA ID:** QM5_9218
**Slug:** `mql5-aroon-cross`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each newly closed H1 bar, compute Aroon Up(25) and Aroon Down(25). Enter long when Aroon Up crosses above Aroon Down (i.e., Up > Down on the last closed bar and Up <= Down on the bar before) AND the Aroon spread (Up minus Down) is at least 5 points. Enter short on the mirror condition. Stop loss is placed at ATR(14) × 1.8 from entry; take profit is set at 2.3× the stop distance. A position is closed when the reverse Aroon cross occurs or after a maximum of 60 H1 bars have elapsed since entry, whichever comes first. One position per symbol at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_aroon_period` | 25 | 5–100 | Aroon Up/Down lookback period |
| `strategy_atr_period` | 14 | 5–50 | ATR period used for stop loss sizing |
| `strategy_sl_atr_mult` | 1.8 | 0.5–5.0 | Stop loss = ATR × this multiplier |
| `strategy_tp_rr` | 2.3 | 0.5–10.0 | Take profit = stop distance × this R:R ratio |
| `strategy_min_aroon_spread` | 5.0 | 0.0–50.0 | Minimum Aroon spread (Up minus Down) at entry to filter equal-line churn |
| `strategy_max_hold_bars` | 60 | 1–500 | Failsafe time exit in H1 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major forex pair; H1 Aroon signals statistically meaningful on this depth
- `XAUUSD.DWX` — trending commodity with sustained Aroon divergences; card explicitly targets gold
- `GDAXI.DWX` — European equity index with pronounced trend runs suitable for Aroon momentum logic

**Explicitly NOT for:**
- SP500.DWX — not in card target list; use NDX.DWX or WS30.DWX for US equity index exposure if needed in future

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~65 |
| Typical hold time | hours to days (avg ~15–40 H1 bars) |
| Expected drawdown profile | moderate; ATR-sized stops limit per-trade loss to ~1× RISK_FIXED |
| Regime preference | trend-following / breakout-momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** paper / article
**Pointer:** Mohamed Abdelmaaboud, "Building and testing Aroon Trading Systems", MQL5 Articles, 2024-01-19, https://www.mql5.com/en/articles/14006
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9218_mql5-aroon-cross.md`

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
| v1 | 2026-06-10 | Initial build from card | 1bc4cf7e-2882-4f2d-ba3a-45549c49148e |
