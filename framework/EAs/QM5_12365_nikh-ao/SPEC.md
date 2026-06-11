# QM5_12365_nikh-ao — Strategy Spec

**EA ID:** QM5_12365
**Slug:** `nikh-ao`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA computes the Awesome Oscillator (AO) on D1 bars as the difference between a fast SMA(5) and a slow SMA(34), both applied to the median price ((High+Low)/2). A long position is entered at market on the close of the first D1 bar where AO crosses from below zero to above zero (AO[1] > 0 and AO[2] <= 0). The position is closed on the close of the first D1 bar where AO crosses from above zero to below zero (AO[1] < 0 and AO[2] >= 0). A hard stop of 2.0 × ATR(14) below the entry price is placed at entry. The strategy is long-only; no short positions are taken.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ao_fast` | 5 | 3–20 | AO fast SMA period (median price) |
| `strategy_ao_slow` | 34 | 20–100 | AO slow SMA period (median price) |
| `strategy_atr_period` | 14 | 7–28 | ATR period used to size the hard stop |
| `strategy_atr_sl_mult` | 2.0 | 1.0–4.0 | ATR multiplier for hard stop distance |
| `strategy_warmup_bars` | 120 | 50–200 | Minimum D1 bars required before first entry |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; D1 AO zero-crosses capture multi-week momentum regimes
- `GBPUSD.DWX` — liquid major FX pair; similar momentum profile to EURUSD
- `USDJPY.DWX` — liquid major FX pair; risk-on/off D1 trends visible in AO cycles
- `XAUUSD.DWX` — gold; D1 momentum cycles align with AO zero-cross regime
- `GDAXI.DWX` — DAX 40 index; replaces card's GER40.DWX (not in DWX matrix); equivalent DAX exposure
- `NDX.DWX` — Nasdaq 100 index; strong D1 momentum regime; live-tradable
- `WS30.DWX` — Dow 30 index; broad US equity momentum; live-tradable

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only per DWX matrix; card's R3 lists as optional; excluded to keep basket live-promotable

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~10 (8–18 per card estimate) |
| Typical hold time | 1–8 weeks (multi-bar D1 momentum swing) |
| Expected drawdown profile | Moderate; whipsaw risk on ranging D1 market |
| Regime preference | trend / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** forum (GitHub repository)
**Pointer:** `https://github.com/Nikhil-Adithyan/Algorithmic-Trading-with-Python/blob/main/Momentum/Awesome_Oscillator.py`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12365_nikh-ao.md`

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
| v1 | 2026-06-11 | Initial build from card | 7a34cfbd-3110-44e0-a2b1-39c74542387d |
