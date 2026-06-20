# QM5_11528_ciurea-inv-hammer-shooting-star-m30 - Strategy Spec

**EA ID:** QM5_11528
**Slug:** ciurea-inv-hammer-shooting-star-m30
**Source:** 0192e348-5570-531c-9110-7954a36caca2 (see `strategy-seeds/sources/0192e348-5570-531c-9110-7954a36caca2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a single completed M30 candle with a small body, long upper shadow, and short lower shadow. The trigger candle must have body greater than 3 pips, upper shadow at least 2.0 times the body, and lower shadow no more than 0.5 times the body. A bullish-body trigger opens a buy at the next bar, and a bearish-body trigger opens a sell at the next bar. The stop is placed beyond the 3-bar structural extreme with a 3-pip buffer, capped at 30 pips, and the take profit is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_body_pips` | 3.0 | > 0 | Minimum candle body size in pips. |
| `strategy_upper_shadow_ratio` | 2.0 | > 0 | Required upper-shadow/body ratio. |
| `strategy_lower_shadow_ratio` | 0.5 | >= 0 | Maximum lower-shadow/body ratio. |
| `strategy_sl_struct_bars` | 3 | 1+ | Number of closed bars used for the structural stop. |
| `strategy_sl_buffer_pips` | 3.0 | >= 0 | Buffer beyond the 3-bar low/high. |
| `strategy_sl_cap_pips` | 30.0 | > 0 | Maximum allowed SL distance in pips. |
| `strategy_rr_multiple` | 2.0 | > 0 | Take profit multiple of realized stop distance. |
| `strategy_spread_cap_pips` | 12.0 | >= 0 | Maximum modeled spread allowed for new entries. |
| `strategy_no_friday_entry` | true | true/false | Blocks new Friday entries while allowing exits. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source-specified M30 FX symbol with the highest cited result.
- `GBPUSD.DWX` - card-approved portable DWX FX symbol from the same source family.

**Explicitly NOT for:**
- non-DWX symbols - build, backtest, and registry artifacts must use `.DWX` research symbols.
- index and commodity symbols - the card cites FX tests only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Not specified in card; bracket exits can hold intraday to multi-day. |
| Expected drawdown profile | Low win-rate reversal profile with 2R winners and capped 30-pip initial risk. |
| Regime preference | Candlestick reversal after rejected upward price spikes. |
| Win rate target (qualitative) | Low to medium; source cites about 36 percent. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0192e348-5570-531c-9110-7954a36caca2
**Source type:** self-published forex article/PDF
**Pointer:** Cristina Ciurea, "The Truth Behind Commonly Used Indicators", ScientificForex.com, about 2012.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11528_ciurea-inv-hammer-shooting-star-m30.md`.

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
| v1 | 2026-06-20 | Initial build from card | adbce0a0-6db3-4ce6-ad1a-33f9c1183cf1 |
