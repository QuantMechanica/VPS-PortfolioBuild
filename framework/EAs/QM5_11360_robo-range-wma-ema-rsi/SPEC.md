# QM5_11360_robo-range-wma-ema-rsi — Strategy Spec

**EA ID:** QM5_11360
**Slug:** `robo-range-wma-ema-rsi`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d` (RoboForex Strategy Collection, "Strategy The Range")
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A four-MA confluence system on M15. Two EMAs (16 and 30) form a "red range"
channel band; two weighted MAs (LWMA 5 and 12) act as the movers. A LONG fires
when the slower WMA(12) crosses above EMA(30) (the single trigger event) while
the faster WMA(5) is already above both EMAs and RSI(14) is above 50 (the two
confirming states). SHORT is the exact mirror: WMA(12) crosses below EMA(30),
WMA(5) below both EMAs, RSI below 50. To avoid the two-crosses-on-one-bar
zero-trade trap, only the WMA(12)×EMA(30) cross is treated as an event; the WMA(5)
position and the RSI level are evaluated as standing states. The stop is anchored
to the EMA(30) far edge of the channel (pushed 5 pips beyond it) but capped at a
maximum of 20 pips from entry. There is no fixed target — the position is closed
defensively when WMA(5) crosses back into the range (below EMA(16) for a long,
above for a short).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 16 | 8-40 | Fast EMA — near edge of the red range, exit anchor |
| `strategy_ema_slow_period` | 30 | 16-60 | Slow EMA — far edge of the range, stop-loss anchor |
| `strategy_wma_fast_period` | 5 | 3-12 | Leading WMA (LWMA), early-mover state |
| `strategy_wma_slow_period` | 12 | 6-30 | Trailing WMA (LWMA), cross-trigger event |
| `strategy_rsi_period` | 14 | 7-28 | RSI lookback period |
| `strategy_rsi_level` | 50.0 | 45.0-60.0 | RSI trend-confirmation threshold (state) |
| `strategy_sl_buffer_pips` | 5 | 0-15 | Push SL this many pips beyond EMA(30) |
| `strategy_sl_max_pips` | 20 | 10-40 | Hard cap on SL distance from entry |
| `strategy_spread_cap_pips` | 5.0 | 1.0-15.0 | Block entry only if spread exceeds this many pips |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major, M15 RoboForex reference pair, tight spreads suit the 20-pip max stop
- `GBPUSD.DWX` — liquid major with strong London/NY trending behaviour the channel exploits
- `USDJPY.DWX` — liquid major; pip-correct distances handled via QM_StopRules (3-digit JPY scaling)

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the 5/20-pip stop model is FX-calibrated; index point ranges differ by orders of magnitude

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~200` |
| Typical hold time | `hours (intraday to ~1 day on M15)` |
| Expected drawdown profile | `moderate; tight 20-pip max stop limits per-trade loss` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Source type:** `paper` (RoboForex strategy-collection PDF)
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\### Forex to read\362359657-Robo-forex-strategy.pdf` (pages 24-25)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11360_robo-range-wma-ema-rsi.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
