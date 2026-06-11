# QM5_9954_ff-weekly-hilo-breakout-d1 — Strategy Spec

**EA ID:** QM5_9954
**Slug:** `ff-weekly-hilo-breakout-d1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

At each D1 bar open, the EA computes previous-week high (PWH) and previous-week low (PWL) from completed D1 bar data. Trend bias is determined by whether the last D1 close is above or below SMA(20,D1) and whether the SMA slope over 5 bars is positive or negative. A long entry fires when bias is bullish and the last D1 close exceeds PWH by at least 0.10 × ATR(14,D1); a short entry fires when bias is bearish and the last D1 close is below PWL by the same buffer. Stop loss is placed below (long) or above (short) the nearest confirmed D1 swing point (2-bar pivot); fallback is 1×ATR(14) from entry. Initial TP is 1R; if price reaches 0.8R and the last D1 bar closed in the trade direction, TP is extended to the ATR(14)-projected daily range target capped at 2R. All positions are closed by the framework at Friday 20:00 broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 20 | 10-50 | SMA period for trend bias filter |
| `strategy_atr_period` | 14 | 7-30 | ATR period used as ADR proxy |
| `strategy_breakout_atr_mult` | 0.10 | 0.05-0.30 | Breakout confirmation buffer as fraction of ATR |
| `strategy_swing_lookback` | 20 | 5-50 | D1 bars to scan for swing high/low SL anchor |
| `strategy_tp_extension_r` | 0.80 | 0.50-1.00 | Profit threshold (in R) to trigger TP extension |
| `strategy_tp_cap_r` | 2.00 | 1.50-3.00 | Maximum TP extension expressed in R multiples |
| `strategy_adr_excess_pct` | 1.10 | 0.80-2.00 | Skip entry if current week range exceeds ADR × this |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; weekly range breakout logic applies to trending FX regimes
- `GBPUSD.DWX` — high-volatility major; weekly structural levels well-defined
- `USDJPY.DWX` — major FX pair with strong directional trends aligned with weekly bias filter
- `XAUUSD.DWX` — gold; strong weekly trend structures; ADR-based target well-suited to volatile swings
- `NDX.DWX` — Nasdaq 100 index; weekly trend bias and range breakout work for trending equity index

**Explicitly NOT for:**
- Pairs not in the DWX matrix — no tick data available

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (all indicators read on PERIOD_D1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~30 |
| Typical hold time | 1-5 days (closed Friday 20:00 if still open) |
| Expected drawdown profile | Low frequency; moderate per-trade risk; weekly-structure SL gives wide stops |
| Regime preference | trending / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** Erebus, "Never Lose Again", ForexFactory 2025, https://www.forexfactory.com/thread/1371892-never-lose-again
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9954_ff-weekly-hilo-breakout-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 7214f707-1ac5-4222-930a-2703ec7d41e6 |
