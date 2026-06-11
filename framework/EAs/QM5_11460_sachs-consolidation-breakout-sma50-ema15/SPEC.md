# QM5_11460_sachs-consolidation-breakout-sma50-ema15 - Strategy Spec

**EA ID:** QM5_11460
**Slug:** `sachs-consolidation-breakout-sma50-ema15`
**Source:** `f9a2d9c8-2f26-5aee-ab31-38716a4558c2` (see `sources/sachs-12-setups`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H4 continuation breakouts after a volatility contraction box. A long setup requires SMA50 to slope upward, EMA15 to sit above SMA50, and the last closed bar to close above the consolidation box built from the prior closed bars. A short setup mirrors this with SMA50 sloping down, EMA15 below SMA50 and below the box, and the last closed bar closing below the box. Initial stop is outside the box plus 5 pips, take profit is 2.0 * ATR(14), and discretionary exit fires when the last closed close crosses back through EMA15.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for all card signals. |
| `strategy_sma_period` | `50` | `2+` | SMA trend period. |
| `strategy_ema_period` | `15` | `2+` | EMA trend and exit period. |
| `strategy_atr_period` | `14` | `1+` | ATR period for box validation and take profit. |
| `strategy_consol_min_bars` | `3` | `3-10` | Minimum prior bars in the consolidation box. |
| `strategy_consol_max_bars` | `10` | `3-10` | Maximum prior bars scanned for a valid box. |
| `strategy_box_atr_mult` | `1.5` | `>0` | Box width must be below this multiple of ATR. |
| `strategy_min_box_pips` | `10.0` | `>=0` | Minimum box width in pips. |
| `strategy_max_box_pips` | `60.0` | `>0` | Maximum box width in pips. |
| `strategy_sl_buffer_pips` | `5.0` | `>0` | Stop buffer outside the consolidation box. |
| `strategy_tp_atr_mult` | `2.0` | `>0` | Take-profit distance as ATR multiple. |
| `strategy_max_spread_pips` | `20.0` | `>=0` | Maximum allowed spread in pips; zero disables this filter. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed major FX pair with DWX H4 data.
- `GBPUSD.DWX` - Card-listed major FX pair with DWX H4 data.
- `USDJPY.DWX` - Card-listed major FX pair with DWX H4 data.
- `AUDUSD.DWX` - Card-listed major FX pair with DWX H4 data.
- `USDCAD.DWX` - Card-listed major FX pair with DWX H4 data.

**Explicitly NOT for:**
- Non-FX index and commodity symbols - The approved card specifies a five-symbol major-FX basket only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Not specified in frontmatter; expected to last multiple H4 bars until ATR target, SL, EMA15 cross, or Friday close. |
| Expected drawdown profile | Not specified in frontmatter; fixed-risk breakout losses should be bounded by the box stop. |
| Regime preference | Trend-following volatility-expansion breakout. |
| Win rate target (qualitative) | Not specified in frontmatter; medium expectation for trend-continuation breakout. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f9a2d9c8-2f26-5aee-ab31-38716a4558c2`
**Source type:** online/self-published book
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11460_sachs-consolidation-breakout-sma50-ema15.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11460_sachs-consolidation-breakout-sma50-ema15.md`

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
| v1 | 2026-06-11 | Initial build from card | 2d956881-5845-4439-8ed1-14791fc827e3 |
