# QM5_9299_mql5-bears-ema — Strategy Spec

**EA ID:** QM5_9299
**Slug:** `mql5-bears-ema`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades Bear's Power (period 13) combined with EMA(13) as a trend-following signal on H1 bars. A long position is entered when Bear's Power is positive and the last closed bar's close is above EMA(13); a short position is entered when Bear's Power is negative and the close is below EMA(13). One position per magic is permitted. Exit fires when the entry condition reverses: close the long when Bear's Power turns negative or close drops below EMA(13); close the short when Bear's Power turns positive or close rises above EMA(13). Initial stop loss is ATR(14) × 2.0, tightened to the 5-bar swing low/high if that level is closer to entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bearspower_period` | 13 | 5–50 | Bear's Power oscillator lookback period |
| `strategy_ema_period` | 13 | 5–50 | EMA period for price-side trend filter |
| `strategy_atr_period` | 14 | 5–30 | ATR period for initial stop distance |
| `strategy_atr_sl_mult` | 2.0 | 1.0–4.0 | ATR multiplier for initial stop |
| `strategy_swing_bars` | 5 | 3–20 | Lookback bars for swing low/high stop tightening |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major Forex pair; H1 Bear's Power + EMA signal well-behaved on trending sessions
- `GBPUSD.DWX` — liquid major Forex pair; similar trending character to EURUSD
- `XAUUSD.DWX` — gold CFD; strong trending asset; card explicitly names it
- `GDAXI.DWX` — DAX 40 index CFD; card named GER40.DWX which maps to GDAXI.DWX in the DWX symbol matrix

**Explicitly NOT for:**
- `GER40.DWX` — name not present in dwx_symbol_matrix.csv; GDAXI.DWX is the canonical DAX symbol

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
| Trades / year / symbol | ~80 |
| Typical hold time | hours to a few days |
| Expected drawdown profile | moderate; trend-following with signal-reversal exit |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** paper / article
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by Bear's Power", MQL5 Articles, 2022-08-10, https://www.mql5.com/en/articles/11297
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9299_mql5-bears-ema.md`

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
| v1 | 2026-06-10 | Initial build from card | aeea02f0-6e0a-46e1-bfbd-4672b6c37a28 |
