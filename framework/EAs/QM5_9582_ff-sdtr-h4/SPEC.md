# QM5_9582_ff-sdtr-h4 — Strategy Spec

**EA ID:** QM5_9582
**Slug:** `ff-sdtr-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed H4 bar, compute daily Fibonacci pivot support (S61/S78/S100) and resistance (R61/R78/R100) zones from the prior D1 bar's high, low, and close. Scan the last 8 H4 bars for a confirmed ZigZag swing low (bullish) or swing high (bearish), where "confirmed" means the local extreme has 3 subsequent bars moving away from it. Enter long when a confirmed bullish ZigZag swing exists, price closed within the entry zone of a support level (max(25 pips, 0.25×ATR14)), Stochastic K was below 30 and is now rising, and the H4 close is above EMA(10). Enter short on the mirror conditions using resistance zones. Stop loss is placed below the confirmed swing low (or above swing high) plus an ATR buffer; a 2.0×ATR fallback applies when the swing distance is unavailable. Take profit is max(75 pips, 1.8×ATR14). Exit is triggered by a confirmed opposite ZigZag signal, a 12-bar time stop (48 hours), or the framework SL/TP. Only one position per magic-symbol at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 10 | 5–50 | EMA period for H4 trend filter |
| `strategy_atr_period` | 14 | 7–28 | ATR period for zone/stop/TP sizing |
| `strategy_stoch_k` | 5 | 3–14 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 2–7 | Stochastic %D smoothing |
| `strategy_stoch_slow` | 3 | 2–7 | Stochastic slow smoothing |
| `strategy_stoch_oversold` | 30.0 | 10–40 | Oversold level triggering bullish turn |
| `strategy_stoch_overbought` | 70.0 | 60–90 | Overbought level triggering bearish turn |
| `strategy_zz_confirm_bars` | 3 | 2–5 | Bars needed to confirm ZigZag swing |
| `strategy_zz_lookback_bars` | 8 | 4–15 | ZigZag lookback window (H4 bars) |
| `strategy_zone_pips` | 25.0 | 10–50 | Pip floor for pivot-zone entry threshold |
| `strategy_zone_atr_mult` | 0.25 | 0.1–0.5 | ATR multiplier for entry zone threshold |
| `strategy_filter_atr_mult` | 0.8 | 0.3–1.5 | Max pivot-zone distance filter (ATR) |
| `strategy_sl_atr_mult` | 2.0 | 1.0–3.0 | Fallback SL distance in ATR units |
| `strategy_sl_buffer_atr_mult` | 0.3 | 0.1–0.5 | SL buffer beyond swing low/high (ATR) |
| `strategy_tp_pips` | 75.0 | 30–200 | TP pip floor |
| `strategy_tp_atr_mult` | 1.8 | 1.0–4.0 | TP ATR multiplier |
| `strategy_time_stop_bars` | 12 | 6–24 | Max H4 bars before time stop |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair; high liquidity, tight spreads, H4 pivot zones well-respected
- `GBPUSD.DWX` — major FX pair; volatile reversals at daily pivot zones common
- `USDJPY.DWX` — major FX pair; pivot-zone behavior consistent; source card explicitly mentions
- `XAUUSD.DWX` — gold; daily range wide enough for ATR-based zone threshold to dominate

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/GDAXI) — card targets FX/metals; pivot-zone reversal logic calibrated for FX volatility

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `PERIOD_D1` (daily Fibonacci pivot zones from prior D1 bar) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~35 (medium-low frequency) |
| Typical hold time | 1–3 days (H4 bars; time stop at 12 bars = 48h) |
| Expected drawdown profile | Moderate; confluence filtering limits overtrading |
| Regime preference | Mean-revert / reversal at daily pivot zones |
| Win rate target (qualitative) | Medium (reversal + confluence = higher precision, lower frequency) |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/713593-simple-daily-trend-reversal-trading-system` (mrdfx, first post 2017-11-09)
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9582_ff-sdtr-h4.md`

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
| v1 | 2026-06-11 | Initial build from card | 2eb7379b-2db1-4d2f-a7e3-d6c70974e571 |
