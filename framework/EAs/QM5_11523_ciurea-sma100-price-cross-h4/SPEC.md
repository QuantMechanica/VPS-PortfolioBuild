# QM5_11523_ciurea-sma100-price-cross-h4 - Strategy Spec

**EA ID:** QM5_11523
**Slug:** `ciurea-sma100-price-cross-h4`
**Source:** `0192e348-5570-531c-9110-7954a36caca2` (see `strategy-seeds/sources/0192e348-5570-531c-9110-7954a36caca2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades H4 closes crossing SMA(100). It buys when the last closed H4 candle closes above SMA(100) after the prior candle closed at or below SMA(100), and sells on the mirror cross below. The initial stop is 3 pips beyond the lowest low or highest high of the last 3 closed H4 bars, capped at 80 pips, and the take-profit is 2R. No discretionary exit is used; trades close through SL, TP, or the framework Friday-close rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | `100` | `2+` | SMA period used for the H4 close cross. |
| `strategy_extreme_bars` | `3` | `3` | Number of closed H4 bars used for the structural stop extreme. |
| `strategy_sl_buffer_pips` | `3` | `1+` | Pip buffer beyond the 3-bar high or low. |
| `strategy_max_sl_pips` | `80` | `1+` | Maximum allowed initial stop distance in pips for P2. |
| `strategy_take_profit_rr` | `2.0` | `>0` | Take-profit multiple of initial risk. |
| `strategy_spread_cap_pips` | `15` | `1+` | Maximum modeled spread in pips; zero spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source-specified H4 EUR/USD test market and present in the DWX matrix.
- `GBPUSD.DWX` - source-specified H4 GBP/USD test market and present in the DWX matrix.

**Explicitly NOT for:**
- Non-`.DWX` symbols - the V5 factory uses DWX backtest symbols only.
- Indices, commodities, and unrelated FX crosses - the card evidence is limited to EUR/USD and GBP/USD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `54` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `Trend-following losses during SMA whipsaw regimes; fixed-risk capped per trade.` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium-low` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0192e348-5570-531c-9110-7954a36caca2`
**Source type:** `self-published strategy article`
**Pointer:** `Cristina Ciurea, "The Truth Behind Commonly Used Indicators", ScientificForex.com, ~2012`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11523_ciurea-sma100-price-cross-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | 74dc95e7-29dc-4335-8c22-f25dbb306ed2 |
