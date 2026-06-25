# QM5_11337_tc20-h1-13-ema5-10-rsi10-hl2 - Strategy Spec

**EA ID:** QM5_11337
**Slug:** `tc20-h1-13-ema5-10-rsi10-hl2`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

On the close of each H1 bar the EA looks for a fresh EMA(5)/EMA(10) crossover
and a simultaneous RSI(10) median-price cross through the 50 midline. A bullish
EMA cross plus RSI crossing up through 50 opens a long; a bearish EMA cross plus
RSI crossing down through 50 opens a short. Each trade carries a fixed 30-pip
stop loss and a fixed 50-pip take profit attached at entry; there is no
discretionary, break-even, partial, or trailing exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | PERIOD_H1 | H1 | Signal timeframe (card base TF) |
| `strategy_fast_ema_period` | 5 | 2-20 | Fast EMA (yellow) period |
| `strategy_slow_ema_period` | 10 | 5-50 | Slow EMA (red) period |
| `strategy_rsi_period` | 10 | 2-30 | RSI period (on median price) |
| `strategy_rsi_midline` | 50.0 | 30-70 | RSI cross threshold |
| `strategy_sl_pips` | 30 | 5-200 | Fixed stop loss in pips |
| `strategy_tp_pips` | 50 | 5-300 | Fixed take profit in pips |
| `strategy_max_spread_pips` | 20.0 | 0-100 | Spread cap (pips); fail-OPEN on 0 spread |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary major; deep liquidity, clean H1 EMA-cross behaviour.
- `GBPUSD.DWX` — primary major; trends well on H1, card R3 PASS symbol.
- `USDJPY.DWX` — P2 expansion major; card R3 PASS; JPY pip-scaling handled by framework stop helpers.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card is a forex-major H1 system; pip and session
  characteristics differ.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~110` |
| Expected trade frequency | `not specified in frontmatter; approximately two trades per week implied by 110/year` |
| Typical hold time | `not specified in frontmatter; H1 entries with fixed 30/50-pip exits imply hours to days` |
| Regime preference | `not specified in frontmatter; trend / momentum-continuation inferred from EMA cross + RSI midline` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Strategy #13 (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11337_tc20-h1-13-ema5-10-rsi10-hl2.md`

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
| v1 | 2026-06-25 | Initial build from card | ec9e20dd-cbef-4c34-a631-defe5c0b7668 |
