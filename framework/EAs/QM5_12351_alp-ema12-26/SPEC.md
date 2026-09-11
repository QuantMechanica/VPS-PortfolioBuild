# QM5_12351_alp-ema12-26 — Strategy Spec

**EA ID:** QM5_12351
**Slug:** `alp-ema12-26`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Author of this spec:** Codex
**Last revised:** 2026-09-11

---

## 1. Strategy Logic

The EA evaluates completed M15 bars. It enters long while the 12-period EMA of
close is above the 26-period EMA, which is the source strategy's positive MACD
state, and exits when that EMA spread becomes negative. Each entry carries a
two-ATR hard stop; equality between the EMAs leaves the current state unchanged.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_fast_ema_period` | 12 | 2–25 | Fast close EMA period. |
| `strategy_slow_ema_period` | 26 | 3–100 | Slow close EMA period; must exceed the fast period. |
| `strategy_atr_period` | 14 | 2–100 | ATR lookback for the protective stop. |
| `strategy_atr_stop_mult` | 2.0 | >0 | ATR multiplier for the hard stop distance. |
| `strategy_warmup_bars` | 100 | >= slow EMA | Completed bars required before signals are admitted. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major-FX trend sleeve.
- `GBPUSD.DWX` — liquid major-FX trend sleeve.
- `USDJPY.DWX` — liquid major-FX trend sleeve with distinct rate exposure.
- `XAUUSD.DWX` — liquid metal trend sleeve.
- `GDAXI.DWX` — canonical DWX DAX mapping for the card's legacy GER40 label.
- `NDX.DWX` — Nasdaq-100 index trend sleeve.
- `WS30.DWX` — Dow-30 index trend sleeve.

**Explicitly NOT for:**

- `GER40.DWX` — absent from the canonical DWX matrix; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` once per host-symbol bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 90; card range 50–140 |
| Typical hold time | hours to several days, until the EMA spread reverses |
| Expected drawdown profile | trend whipsaw losses bounded by a 2×ATR initial stop |
| Regime preference | directional trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** public GitHub repository
**Pointer:** `alpacahq/pylivetrader`, `examples/MACD/macd_example.py`
**R1–R4 verdict (Q00):** R2–R4 PASS and OWNER-recovered G0 APPROVED per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12351_alp-ema12-26.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-11 | Initial build from card | `b63e991a-cf37-4a8d-a884-a3ef1bb5a90e` |
