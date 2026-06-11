# QM5_9989_ff-channel-ma-m15 - Strategy Spec

**EA ID:** QM5_9989
**Slug:** `ff-channel-ma-m15`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades an M15 EMA channel breakout. It builds an upper channel from EMA(55) on High, a lower channel from EMA(55) on Low, and a signal line from EMA(33) on Close. A long entry is signalled when the signal line crosses above the upper channel on the last closed bar; a short entry is signalled when it crosses below the lower channel. If price is within 40 pips of the opposite channel boundary, the EA enters at market on the next bar; otherwise it places a 16-bar limit order at the signal EMA. Exits use a 40-pip target, breakeven after +22 pips, opposite-signal close, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_channel_ema_period` | 55 | 1-500 | EMA period for the High/Low channel. |
| `strategy_signal_ema_period` | 33 | 1-500 | EMA period for the Close signal line. |
| `strategy_distance_threshold_pips` | 40 | 1-500 | Maximum distance from entry price to the opposite channel boundary for immediate market entry. |
| `strategy_stop_pips` | 45 | 1-500 | Fixed hard stop distance before channel protection is applied. |
| `strategy_take_profit_pips` | 40 | 1-500 | Fixed take-profit distance. |
| `strategy_breakeven_trigger_pips` | 22 | 1-500 | Profit threshold for moving stop to breakeven. |
| `strategy_pending_expiry_bars` | 16 | 1-200 | Number of M15 bars before delayed limit orders expire. |
| `strategy_max_spread_pips` | 2.5 | 0.1-20.0 | Maximum allowed spread in pips. |
| `strategy_max_spread_stop_ratio` | 0.08 | 0.01-1.00 | Maximum allowed spread as a fraction of final stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with M15 DWX data.
- `GBPUSD.DWX` - card-listed FX major with M15 DWX data.
- `USDJPY.DWX` - card-listed FX major with M15 DWX data.

**Explicitly NOT for:**
- Index, commodity, and non-card FX symbols - the approved card restricts the P2 universe to the three FX majors above to reduce cross-basket correlation risk.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | Intraday M15 holds until 40-pip TP, 45-pip SL, breakeven stop, or opposite signal. |
| Expected drawdown profile | Moderate trend-continuation drawdown from false channel breaks and spread sensitivity. |
| Regime preference | Trend-continuation / volatility-expansion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** MickeyMar, "Channel MA Short-Term System", ForexFactory, 2017-10-16, https://www.forexfactory.com/thread/707474-channel-ma-short-term-system
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9989_ff-channel-ma-m15.md`

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
| v1 | 2026-06-11 | Initial build from card | 24380917-acc0-47be-a611-a943c29033dc |
