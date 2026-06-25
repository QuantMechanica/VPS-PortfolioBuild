# QM5_11545_carter-t-h1-ema18-28-wma5-12-rsi21 — Strategy Spec

**EA ID:** QM5_11545
**Slug:** carter-t-h1-ema18-28-wma5-12-rsi21
**Source:** 3001a121-97a0-5db0-b6ff-69b89a0fc07d (see `strategy-seeds/sources/3001a121-97a0-5db0-b6ff-69b89a0fc07d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades EURUSD.DWX on H1 when EMA(18) and EMA(28) form a narrow tunnel. A long signal occurs when WMA(5) and WMA(12) transition from not both above the tunnel to both above it on the latest closed bar, while RSI(21) is above 50. A short signal is the mirror below the tunnel with RSI(21) below 50. Each trade uses a fixed 50-pip stop loss and 50-pip take profit, with an early strategy exit when both WMAs cross back to the opposite side of the tunnel.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 18 | 2-200 | Fast EMA period for the red tunnel. |
| `strategy_ema_slow_period` | 28 | 2-200 | Slow EMA period for the red tunnel. |
| `strategy_wma_fast_period` | 5 | 2-100 | Fast WMA period used for tunnel cross. |
| `strategy_wma_slow_period` | 12 | 2-100 | Slow WMA period used for tunnel cross. |
| `strategy_rsi_period` | 21 | 2-100 | RSI confirmation period. |
| `strategy_rsi_mid` | 50.0 | 0-100 | RSI bullish/bearish split level. |
| `strategy_tunnel_narrow_pips` | 5 | 1-55 | Maximum EMA18/EMA28 gap in pips. |
| `strategy_sl_pips` | 50 | 1-55 | Fixed stop-loss distance in pips. |
| `strategy_tp_pips` | 50 | 1-200 | Fixed take-profit distance in pips. |
| `strategy_spread_cap_pips` | 15.0 | 0-100 | Maximum genuine spread in pips; zero modeled spread passes. |
| `strategy_no_friday_entry` | true | true/false | Suppress new entries on broker Fridays. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX — card R3 states EURUSD.DWX H1 is available and this is a forex H1 system.

**Explicitly NOT for:**
- Non-EURUSD symbols — the approved card names EURUSD.DWX only and does not define a portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Expected trade frequency | Approximately 40 trades/year/symbol, inferred from card frontmatter. |
| Typical hold time | Intraday to multi-hour, bounded by fixed 50-pip TP/SL or WMA cross-back exit. |
| Expected drawdown profile | Fixed-risk, symmetric 50-pip SL/TP trend-momentum profile. |
| Regime preference | Narrow-tunnel momentum expansion on H1. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3001a121-97a0-5db0-b6ff-69b89a0fc07d
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", System #20, self-published 2014; see `artifacts/cards_approved/QM5_11545_carter-t-h1-ema18-28-wma5-12-rsi21.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11545_carter-t-h1-ema18-28-wma5-12-rsi21.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-25 | Initial build from card | 89e4dd55-3193-404b-9010-2ed5b9860adf |
