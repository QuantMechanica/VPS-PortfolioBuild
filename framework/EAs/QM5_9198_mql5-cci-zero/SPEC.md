# QM5_9198_mql5-cci-zero — Strategy Spec

**EA ID:** QM5_9198
**Slug:** `mql5-cci-zero`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades CCI(14) zero-line crossovers on H1 bars. A long position is opened when the previous bar's CCI was at or below zero and the current closed bar's CCI rises above zero; a short position is opened on the mirror condition. The protective stop is placed at 1.5× ATR(14) from entry price. Positions are closed when CCI reaches ±100 (take-profit signal) or when CCI crosses back through zero in the opposite direction. An optional EMA(100) trend filter can be enabled for P3 parameter sweeps: longs are only taken above EMA, shorts only below.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 14 | 5–50 | CCI lookback period for zero-cross signal |
| `strategy_atr_period` | 14 | 5–30 | ATR lookback for stop distance computation |
| `strategy_atr_sl_mult` | 1.5 | 0.5–4.0 | ATR multiplier applied to set the SL distance |
| `strategy_ema_filter` | false | true/false | Enable EMA(100) trend filter for P3 sweep |
| `strategy_ema_period` | 100 | 50–300 | EMA period for optional trend filter |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; CCI momentum patterns well-documented on H1
- `GBPUSD.DWX` — liquid major FX pair; similar volatility regime to EURUSD
- `GDAXI.DWX` — DAX 40 index; card listed GER40.DWX (ported to canonical DWX name GDAXI.DWX; same instrument)

**Explicitly NOT for:**
- `GER40.DWX` — not a valid DWX symbol; GDAXI.DWX is the canonical equivalent

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
| Trades / year / symbol | ~90 |
| Typical hold time | Hours to days (CCI oscillation dependent) |
| Expected drawdown profile | Moderate; ATR SL limits per-trade risk |
| Regime preference | momentum / oscillator-cross |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** https://www.mql5.com/en/articles/10592 — Mohamed Abdelmaaboud, "Learn how to design a trading system by CCI", MQL5 Articles, 2022-04-06
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9198_mql5-cci-zero.md`

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
| v1 | 2026-06-10 | Initial build from card | ecec49a0-7783-43a6-8074-0edb62fc0cc3 |
