# QM5_11474_carter-t-mtf-candle-alignment-h1 — Strategy Spec

**EA ID:** QM5_11474
**Slug:** carter-t-mtf-candle-alignment-h1
**Source:** a7bd19cd-cae9-5c58-8b7c-a411bac7598a (see `sources/carter-t-20-forex-strategies-1h-collection`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA checks the last completed M5, M15, M30, and H1 candles once per H1 bar. If all four candles closed bullish, it places a buy-stop 3 pips above the prior H1 close; if all four closed bearish, it places a sell-stop 3 pips below the prior H1 close. The pending order expires after three hours. Open trades use fixed 50-pip stop loss and fixed 50-pip take profit, with no discretionary close beyond framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf_a` | `PERIOD_M5` | MT5 timeframe enum | First lower timeframe candle for alignment. |
| `strategy_tf_b` | `PERIOD_M15` | MT5 timeframe enum | Second lower timeframe candle for alignment. |
| `strategy_tf_c` | `PERIOD_M30` | MT5 timeframe enum | Third lower timeframe candle for alignment. |
| `strategy_trigger_pips` | `3` | `1`-`20` | Pending stop offset beyond the closed H1 candle close. |
| `strategy_sl_pips` | `50` | `10`-`200` | Fixed stop loss in pips. |
| `strategy_tp_pips` | `50` | `10`-`300` | Fixed take profit in pips. |
| `strategy_expire_hours` | `3` | `1`-`24` | Pending stop order lifetime in broker hours. |
| `strategy_spread_cap_pips` | `20` | `1`-`100` | Blocks only genuine positive modeled spread wider than this cap. |
| `strategy_no_friday_entry` | `true` | `true`/`false` | Blocks new entries on Friday broker time. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Carter's specified EUR/USD pair and present in the DWX forex matrix.
- `GBPUSD.DWX` — Carter's specified GBP/USD pair and present in the DWX forex matrix.

**Explicitly NOT for:**
- Non-FX index or commodity `.DWX` symbols — the source strategy is specified for major FX pairs with pip-based stops.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `M5`, `M15`, `M30`, `H1` closed candles |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (run on H1 setfiles) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Hours to days, bounded by fixed 50-pip SL/TP and Friday close |
| Expected drawdown profile | Frequent small losses possible because the rule is a simple 1:1 momentum continuation pattern |
| Regime preference | Momentum / volatility-expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** a7bd19cd-cae9-5c58-8b7c-a411bac7598a
**Source type:** self-published book/PDF
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (1 Hour Time Frame)`, Strategy #16; local PDF `376863900-20-Forex-Trading-Strategies-Collection.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11474_carter-t-mtf-candle-alignment-h1.md`

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
| v1 | 2026-06-25 | Initial build from card | d8c53903-b084-4e29-8ac6-764f5f2e7bf0 |
