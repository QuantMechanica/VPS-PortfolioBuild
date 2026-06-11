# QM5_9939_ff-atr-breakout-h1 - Strategy Spec

**EA ID:** QM5_9939
**Slug:** `ff-atr-breakout-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each new H1 bar, the EA reads ATR(50) from completed H1 bars and skips trading when current ATR is below the 20th percentile of the prior 100 ATR values. If MACD(12,26,9) histogram is positive and RSI(14) is above 50, it places a buy stop at the prior close plus 0.35 ATR; if MACD histogram is negative and RSI is below 50, it places a sell stop at the prior close minus 0.35 ATR. Initial SL is 1.0 ATR and TP is 1.5 ATR from entry. Unfilled stop orders are removed on the next H1 bar, ATR trailing begins after a 1R move, and any open trade is closed after 18 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 50 | 1-200 | ATR period for entry distance, SL, TP, trailing, and volatility percentile. |
| `strategy_entry_atr_mult` | 0.35 | 0.01-5.0 | ATR multiple added to or subtracted from the prior close for stop entry. |
| `strategy_sl_atr_mult` | 1.0 | 0.1-10.0 | ATR multiple used for initial stop loss and 1R trailing activation. |
| `strategy_tp_atr_mult` | 1.5 | 0.1-20.0 | ATR multiple used for take profit. |
| `strategy_trail_atr_mult` | 1.0 | 0.1-10.0 | ATR multiple used by the framework ATR trailing helper after +1R. |
| `strategy_time_stop_bars` | 18 | 1-240 | Maximum H1 bars to hold a position. |
| `strategy_atr_percentile_lookback` | 100 | 20-100 | Number of ATR values used for the low-volatility percentile gate. |
| `strategy_atr_percentile_rank` | 20.0 | 0-100 | Percentile threshold below which entries are skipped. |
| `strategy_macd_fast` | 12 | 1-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 2-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1-100 | MACD signal period. |
| `strategy_rsi_period` | 14 | 1-100 | RSI period. |
| `strategy_rsi_midline` | 50.0 | 0-100 | RSI directional threshold. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with DWX H1 data.
- `GBPUSD.DWX` - card-listed major FX pair with DWX H1 data.
- `USDJPY.DWX` - card-listed major FX pair with DWX H1 data.
- `XAUUSD.DWX` - card-listed liquid metal symbol with DWX H1 data.

**Explicitly NOT for:**
- Symbols outside the approved card basket - not part of the R3 portable universe for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | Up to 18 H1 bars by card time stop. |
| Expected drawdown profile | Breakout system with ATR-defined loss per trade and one active position per magic-symbol. |
| Regime preference | Volatility-expansion breakout. |
| Win rate target (qualitative) | medium |

Expected trade frequency: New-bar ATR breakout stop entry on H1; estimate 120-220 trades/year/symbol after same-bar pending-order cancellation and filters.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/562470-atr-break-out`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9939_ff-atr-breakout-h1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 50030153-744d-49dc-9044-a643adfa26e7 |
