# QM5_11527_ciurea-engulfing-m30 - Strategy Spec

**EA ID:** QM5_11527
**Slug:** `ciurea-engulfing-m30`
**Source:** `0192e348-5570-531c-9110-7954a36caca2` (see `strategy-seeds/sources/0192e348-5570-531c-9110-7954a36caca2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades a two-bar engulfing pattern on M30. A long signal occurs when the last closed bar has a higher high and lower low than the prior bar, closes bullish, and the prior bar closes bearish. A short signal is the inverse: the last closed bar engulfs the prior bar, closes bearish, and the prior bar closes bullish. Entries are market orders at the next bar open, with a stop beyond the three-bar extreme plus a 3 pip buffer and a 2R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_M30` | M30 intended | Timeframe used for the engulfing pattern. |
| `strategy_structure_bars` | `3` | 3+ | Number of closed bars used for the structural stop extreme. |
| `strategy_stop_buffer_pips` | `3` | 1+ | Pip buffer beyond the three-bar high or low. |
| `strategy_reward_risk` | `2.0` | >0 | Take profit as a multiple of initial risk. |
| `strategy_max_stop_pips` | `30` | 1+ | Maximum allowed initial stop distance for P2. |
| `strategy_spread_cap_pips` | `12` | 1+ | Maximum live spread before entries are blocked. |
| `strategy_no_friday_entry` | `true` | true/false | Blocks new Friday entries while framework Friday close remains active. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Source-specified EUR/USD M30 result and DWX matrix availability.
- `GBPUSD.DWX` - Source-specified GBP/USD result and DWX matrix availability.

**Explicitly NOT for:**
- `USDCHF.DWX` - Mentioned by the source, but not included in the approved card's R3 portable DWX basket for this build.
- Non-FX index or commodity symbols - The source result and card mechanics target major FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `154` |
| Typical hold time | Not specified in card frontmatter |
| Expected drawdown profile | Not specified in card frontmatter |
| Regime preference | Candlestick reversal / price-action momentum reversal |
| Win rate target (qualitative) | Low to medium; source EUR/USD win rate was about 31% |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0192e348-5570-531c-9110-7954a36caca2`
**Source type:** self-published trading article/PDF
**Pointer:** Cristina Ciurea, "The Truth Behind Commonly Used Indicators", ScientificForex.com, about 2012.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11527_ciurea-engulfing-m30.md`.

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
| v1 | 2026-06-20 | Initial build from card | e4aa783a-3b88-43dc-b2c3-7496906bee80 |
