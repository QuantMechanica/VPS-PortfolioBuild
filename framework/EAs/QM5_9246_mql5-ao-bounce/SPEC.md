# QM5_9246_mql5-ao-bounce — Strategy Spec

**EA ID:** QM5_9246
**Slug:** `mql5-ao-bounce`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades Awesome Oscillator (AO) zero-line bounce continuations on H4 bars. AO is computed as SMA(5) minus SMA(34) of bar median price ((High+Low)/2). A long signal fires when AO declined toward zero for one bar (AO[2] > AO[1]) without crossing it (AO[1] >= 0), then reversed upward (AO[1] < AO[0]) — a "bounce off zero from above." A short signal is the mirror: AO rose toward zero (AO[2] < AO[1]), stayed below zero (AO[1] <= 0), then resumed its decline (AO[1] > AO[0]). An additional SMA(50) trend filter requires that the last closed bar's close is above SMA(50) for longs, below for shorts. Entry is at market on the next bar open; stop is 1.7 × ATR(14) from entry; take profit is 2.0R. The position closes early if AO crosses zero, if AO declines (for longs) or rises (for shorts) for two consecutive bars, or after 28 H4 bars (failsafe).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ao_sma_fast` | 5 | 3–10 | Fast SMA period for Awesome Oscillator |
| `strategy_ao_sma_slow` | 34 | 20–55 | Slow SMA period for Awesome Oscillator |
| `strategy_sma_trend` | 50 | 20–200 | SMA period for close-based trend filter |
| `strategy_atr_period` | 14 | 7–21 | ATR lookback for stop distance |
| `strategy_sl_atr_mult` | 1.7 | 1.0–3.0 | Stop = entry ± ATR × multiplier |
| `strategy_tp_rr_mult` | 2.0 | 1.0–4.0 | Take profit = stop_distance × R:R ratio |
| `strategy_max_bars_held` | 28 | 10–50 | Failsafe time exit in H4 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — High-liquidity major forex pair; H4 AO bounce tested in the source article on similar major pairs
- `GBPJPY.DWX` — Trending cross pair with sufficient H4 volatility for ATR-based stops
- `NDX.DWX` — US large-cap index; trending regime suits AO bounce continuation logic

**Explicitly NOT for:**
- Monthly (MN1) symbols — MT5 tester cannot generate MN1 bars for DWX custom symbols
- M1/M5 symbols — bounce logic requires H4 closed-bar cadence; lower TF too noisy

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | 1–28 H4 bars (4 h – 4.7 days) |
| Expected drawdown profile | Moderate; fixed 1.7× ATR stop limits per-trade loss |
| Regime preference | trend-continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** https://www.mql5.com/en/articles/16502 — Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 50): Awesome Oscillator", 2024-11-29; pattern 6 (Zero Line Bounce)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9246_mql5-ao-bounce.md`

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
| v1 | 2026-06-10 | Initial build from card | abb4b268-a970-4d17-b656-75e3401985a5 |
