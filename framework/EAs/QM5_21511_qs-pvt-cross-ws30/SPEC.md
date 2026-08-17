# QM5_21511_qs-pvt-cross-ws30 - Strategy Spec

**EA ID:** QM5_21511
**Slug:** `qs-pvt-cross-ws30`
**Source:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Author of this spec:** Claude
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

This EA trades a Price and Volume Trend (PVT) vs its own moving-average cross
on WS30 D1. PVT is a cumulative index seeded at 0 that updates EVERY bar,
adding the day's percentage price change multiplied by that day's tick
volume to a running total — magnitude-weighted, unlike sign-only indicators
such as OBV. The EA computes PVT and a rolling SMA of the PVT series fully
from history once per new closed D1 bar (a bounded, cheap recompute —
`pvt_ma_period + warmup_buffer` iterations, gated so it never repeats within
a bar).

A long entry opens when PVT crosses from at/below its SMA to above it; a
short entry opens when PVT crosses from at/above its SMA to below it. Both
directions share a single one-position-per-magic cap. Positions carry a fixed
ATR hard stop and exit on the opposite PVT/SMA cross (signal reversal, may
flip same-bar), a bar-count time stop, or framework Friday close. No
take-profit, trailing stop, or partial close in v1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pvt_ma_period` | 20 | 14-45 | SMA period applied to the PVT series itself |
| `strategy_warmup_buffer` | 10 | 5-20 | Extra bars beyond the SMA period before trading is allowed |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the protective stop |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | Protective stop distance in ATR units |
| `strategy_max_hold_bars` | 45 | 30-70 | Maximum holding period in D1 bars |
| `strategy_max_spread_points` | 500 | 300-800 | Spread cap (points) above which entries are skipped |

---

## 3. Symbol Universe

**Designed for:**
- `WS30.DWX` - liquid, live-tradable Dow 30 index CFD; the source's own
  volume-and-price-magnitude construct applies cleanly to a broad index.

**Explicitly NOT for:**
- Any other symbol - the card is single-symbol-only by design; batch
  siblings from the same source use distinct instruments (XAU, EUR, NDX,
  SP500).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | up to 45 D1 bars (time-stop bound) |
| Expected drawdown profile | Moderate-frequency crosses; whipsaw risk in choppy, low-magnitude-move regimes |
| Regime preference | Medium-horizon trend following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Source type:** web (QuantifiedStrategies.com)
**Pointer:** "Price and Volume Trend (PVT) - Backtest Strategy, Trading
Rules, Settings, Returns (82% Win Rate)",
https://www.quantifiedstrategies.com/price-and-volume-trend/
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_21511_qs-pvt-cross-ws30.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved G0 card | router task f5b400ae |
