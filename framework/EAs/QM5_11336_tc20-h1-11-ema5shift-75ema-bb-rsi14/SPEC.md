# QM5_11336_tc20-h1-11-ema5shift-75ema-bb-rsi14 — Strategy Spec

**EA ID:** QM5_11336
**Slug:** `tc20-h1-11-ema5shift-75ema-bb-rsi14`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

On the close of each H1 bar the EA checks whether the candle closed above
EMA(75) and above the Bollinger(20,2) middle band for a long setup, or below
both levels for a short setup. The entry trigger is RSI(14) breaking above 50
for a long or below 50 for a short on that same closed signal bar.

Stop-loss is placed 2 pips beyond EMA(75) on the signal bar using the card's P2
simplification, capped so the stop distance never exceeds 1.5x ATR(14). Take
profit is a fixed multiple of the initial stop distance, defaulting to 2x because
the card allows 1x or 2x. Positions exit only on stop or target; the EA has no
discretionary exit rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_slow_period` | 75 | 30-200 | Slow EMA period — trend level |
| `strategy_bb_period` | 20 | 10-30 | Bollinger period (middle band = SMA) |
| `strategy_bb_deviation` | 2.0 | 1.0-3.0 | Bollinger deviation (state filter) |
| `strategy_rsi_period` | 14 | 7-28 | RSI period |
| `strategy_rsi_level` | 50.0 | 40-60 | RSI momentum threshold |
| `strategy_sl_buffer_pips` | 2.0 | 0-20 | SL distance beyond EMA75, in pips |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the SL cap |
| `strategy_atr_sl_cap_mult` | 1.5 | 0.5-4.0 | SL distance capped at this × ATR |
| `strategy_tp_rr` | 2.0 | 0.5-4.0 | TP = this × SL distance (1× or 2× per card) |
| `strategy_spread_cap_pips` | 20 | 1-100 | Skip if modeled spread exceeds this many pips |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card primary; deep liquidity, tight spreads, clean H1 trends.
- `GBPUSD.DWX` — card P2 basket; trending major with comparable EMA/RSI behaviour.
- `USDJPY.DWX` — card P2 basket; trending major, pip-scale handled via pip_factor.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card is a 1-hour forex strategy; EMA75/BB/RSI
  levels were calibrated on FX majors, not gapless index CFDs.

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
| Trades / year / symbol | `~80` |
| Typical hold time | `not specified in frontmatter; H1 SL/TP strategy implies hours to days` |
| Expected drawdown profile | `not specified in frontmatter; fixed ATR-capped stop per trade` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", Strategy #11 (local PDF: `376863900-20-Forex-Trading-Strategies-Collection.pdf`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11336_tc20-h1-11-ema5shift-75ema-bb-rsi14.md`

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
| v1 | 2026-06-23 | Initial build from card | 5b6a8990-3506-415c-8b09-390d1de346d1 |
