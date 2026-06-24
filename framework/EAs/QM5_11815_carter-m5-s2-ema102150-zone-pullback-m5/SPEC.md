# QM5_11815_carter-m5-s2-ema102150-zone-pullback-m5 - Strategy Spec

**EA ID:** QM5_11815
**Slug:** `carter-m5-s2-ema102150-zone-pullback-m5`
**Source:** `f4430cee-7efb-592e-bf0f-e469ef156b2d`
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades Thomas Carter's M5 Strategy 2 EMA zone pullback on EURUSD.DWX. A long setup requires EMA10 > EMA21 > EMA50, the last closed bar's low to touch or pass through EMA21, and that same closed bar to close back above EMA10. A short setup mirrors the rule with EMA10 < EMA21 < EMA50, the last closed bar's high touching or passing through EMA21, and the bar closing back below EMA10. Exits use the card's fixed 5 pip stop, 10 pip target, framework Friday close, or a discretionary close when the last closed bar breaks back through EMA10 against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 10 | 2-200 | Fast EMA and inner edge of the Carter zone. |
| `strategy_ema_mid_period` | 21 | 2-300 | Middle EMA and far edge of the Carter pullback zone. |
| `strategy_ema_slow_period` | 50 | 2-500 | Slow EMA used to confirm trend direction. |
| `strategy_sl_pips` | 5 | 1-100 | Fixed stop loss in pips from the card. |
| `strategy_tp_pips` | 10 | 1-200 | Fixed take profit in pips from the card. |
| `strategy_spread_pct_of_stop` | 25.0 | 0-100 | Blocks only genuinely wide positive spread relative to stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the card's stated target symbol and a verified forex symbol in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Non-EURUSD forex pairs - not listed by the approved card for this single-symbol build.
- Equity index `.DWX` symbols - the source strategy is an M5 forex EMA scalp and the card did not approve index portability.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | Intraday M5 scalp, usually minutes to under one session |
| Expected drawdown profile | Tight fixed stops with frequent small losses during choppy EMA stacks |
| Regime preference | trend-following pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f4430cee-7efb-592e-bf0f-e469ef156b2d`
**Source type:** book/PDF
**Pointer:** `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", Strategy 2.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11815_carter-m5-s2-ema102150-zone-pullback-m5.md`.

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
| v1 | 2026-06-25 | Initial build from card | 43dd3292-ca63-4c97-9973-4e1e2c68cc9c |
