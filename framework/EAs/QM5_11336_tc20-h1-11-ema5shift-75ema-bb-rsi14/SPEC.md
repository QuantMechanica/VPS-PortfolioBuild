# QM5_11336_tc20-h1-11-ema5shift-75ema-bb-rsi14 - Strategy Spec

**EA ID:** QM5_11336
**Slug:** `tc20-h1-11-ema5shift-75ema-bb-rsi14`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades the H1 close after a trend and momentum confirmation. A long signal requires the last closed candle to close above EMA(75) and the Bollinger(20,2) middle band, while RSI(14) crosses upward through 50. A short signal mirrors that rule below EMA(75), below the Bollinger middle band, and with RSI(14) crossing downward through 50. The stop is the P2 simplification from the card: EMA(75) offset by 2 pips, capped to ATR(14) x 1.5; the take-profit is an RR multiple of the initial stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Signal timeframe from the card. |
| `strategy_slow_ema_period` | `75` | `2+` | EMA trend baseline. |
| `strategy_bb_period` | `20` | `2+` | Bollinger middle-band period. |
| `strategy_bb_deviation` | `2.0` | `>0` | Bollinger deviation parameter. |
| `strategy_rsi_period` | `14` | `2+` | RSI period for momentum confirmation. |
| `strategy_rsi_midline` | `50.0` | `0-100` | RSI crossing threshold. |
| `strategy_sl_offset_pips` | `2` | `1+` | EMA75 stop offset in pips. |
| `strategy_atr_period` | `14` | `2+` | ATR period for stop-distance cap. |
| `strategy_atr_cap_mult` | `1.5` | `>0` | Maximum stop distance as ATR multiple. |
| `strategy_tp_rr` | `2.0` | `>0` | Take-profit in initial-risk multiples. |
| `strategy_spread_cap_pips` | `20` | `1+` | Maximum allowed modeled spread in pips. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary FX symbol named by the approved card.
- `GBPUSD.DWX` - P2 portable FX symbol named by the approved card.
- `USDJPY.DWX` - P2 portable FX symbol named by the approved card.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX` - the card is an H1 FX strategy and does not authorize equity-index expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | not specified in card frontmatter |
| Regime preference | trend-following momentum continuation |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** book / local PDF
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (1 Hour Time Frame), Forex Trading Strategy #11, local PDF: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\376863900-20-Forex-Trading-Strategies-Collection.pdf`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11336_tc20-h1-11-ema5shift-75ema-bb-rsi14.md`

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
| v1 | 2026-06-23 | Initial build from card | 5b6a8990-3506-415c-8b09-390d1de346d1 |
