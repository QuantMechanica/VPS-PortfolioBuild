# QM5_11520_carter-t-ema18-adx12-pullback - Strategy Spec

**EA ID:** QM5_11520
**Slug:** carter-t-ema18-adx12-pullback
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades the H1 Carter System #17 pullback pattern in both directions. A long setup requires the last closed bar to close above EMA(18), ADX(12) to be above 25, and that same bar's low to touch or cross the EMA; it then places a BuyStop one pip above that bar's high. A short setup mirrors this with price below EMA(18), the bar high touching the EMA, and a SellStop one pip below the bar's low. The stop is fixed at 25 pips, and the take profit uses the prior 20-bar swing extreme when it is beyond the entry, otherwise a 50-pip fallback target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_period | 18 | 2-200 | EMA period used as the trend and pullback reference. |
| strategy_adx_period | 12 | 2-100 | ADX period used for trend-strength filtering. |
| strategy_adx_threshold | 25.0 | 0-100 | Minimum ADX value required before placing a stop entry. |
| strategy_swing_lookback | 20 | 1-200 | Closed H1 bars scanned for the swing-high or swing-low take-profit proxy. |
| strategy_sl_pips | 25 | 1-30 | Fixed stop distance in pips, within the card's 30-pip P2 cap. |
| strategy_tp_fallback_pips | 50 | 1-300 | Fixed take-profit fallback if the swing extreme is not beyond the entry. |
| strategy_entry_offset_pips | 1 | 1-20 | Stop-order offset beyond the signal bar high or low. |
| strategy_expiry_bars | 3 | 1-24 | Pending stop-order expiry measured in current-chart bars. |
| strategy_spread_cap_pips | 15.0 | 0-100 | Blocks entries only when modeled spread is wider than this cap. |
| strategy_no_friday_entry | true | true/false | Suppresses new entries on Friday, per the card filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed live-tradable DWX FX instrument with H1 history.
- GBPUSD.DWX - Card-listed live-tradable DWX FX instrument with H1 history.
- USDJPY.DWX - Card-listed live-tradable DWX FX instrument with H1 history.

**Explicitly NOT for:**
- Non-DWX symbols - The V5 backtest registry and setfiles require canonical `.DWX` symbols.
- Index, metals, commodities, and sector symbols - The card's R3 scope is the three listed FX instruments only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Hours to a few H1 bars, bounded by SL/TP once the pending order fills. |
| Expected drawdown profile | Trend-pullback false breaks should cluster during ranging markets filtered imperfectly by ADX. |
| Regime preference | Trend-following pullback with ADX-confirmed trend strength. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #17, self-published 2014; all R1-R4 PASS per `artifacts/cards_approved/QM5_11520_carter-t-ema18-adx12-pullback.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11520_carter-t-ema18-adx12-pullback.md`

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
| v1 | 2026-06-25 | Initial build from card | c7b92332-8488-4707-812a-1fb6d3fdda47 |
