# QM5_12824_cme-gasgold-ratio - Strategy Spec

**EA ID:** QM5_12824
**Slug:** `cme-gasgold-ratio`
**Source:** `CME-GAS-GOLD-RELVAL-2026` (see `strategy-seeds/sources/CME-GAS-GOLD-RELVAL-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA implements a low-frequency structural commodity relative-value sleeve as
a two-leg basket on `XNGUSD.DWX` and `XAUUSD.DWX`. It computes the D1 log spread
`ln(XNGUSD) - beta * ln(XAUUSD)`, converts it to a rolling z-score, opens a
short-ratio package above +2.0, opens a long-ratio package below -2.0, and exits
both legs when the spread reverts inside +/-0.5. Each leg carries an ATR(20) *
3.0 hard stop.

The strategy is intentionally not a duplicate of `QM5_12577_cme-xauxag-ratio`:
it is natural gas versus gold, not an intra-metals spread. It is also not
`QM5_12578_eia-oilgas-ratio`, because there is no WTI leg and the hedge leg is
gold rather than another energy product.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 120 | 90-252 | D1 bars used for spread mean and standard deviation |
| `strategy_beta` | 1.0 | 0.6-1.2 | Hedge coefficient in the log spread |
| `strategy_entry_z` | 2.0 | 1.5-2.5 | Absolute z-score threshold for entry |
| `strategy_exit_z` | 0.5 | 0.25-0.75 | Absolute z-score threshold for exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Per-leg stop multiplier |
| `strategy_xng_max_spread_pts` | 2500 | 1500-3500 | XNG entry spread cap |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | XAU entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |
| `strategy_entry_hour_broker` | 2 | 0-23 | Earliest broker hour to attempt the daily basket entry |
| `strategy_entry_minute_broker` | 0 | 0-59 | Earliest broker minute to attempt the daily basket entry |

---

## 3. Symbol Universe

**Designed for:**
- `XNGUSD.DWX` - host chart and natural-gas numerator, magic slot 0.
- `XAUUSD.DWX` - hedge leg and gold denominator, magic slot 1.
- `QM5_12824_XNG_XAU_RATIO_D1` - logical basket symbol for Q02 dispatch.

**Explicitly NOT for:**
- `XTIUSD.DWX` - covered by the separate XTI/XNG, oil/gold, and oil/silver baskets.
- `XAGUSD.DWX` - covered by the separate XAU/XAG metals ratio.
- Equity indices and FX pairs - different economic exposure from the CME natural-gas/gold ratio source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | D1 state refresh on `QM_IsNewBar`; entry can be delayed until the configured broker entry time and both legs are tradable |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `9` |
| Typical hold time | `Days to weeks` |
| Expected drawdown profile | `High; natural-gas shocks can gap while gold follows monetary and safe-haven flows` |
| Regime preference | `natural-gas/gold relative-value mean reversion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CME-GAS-GOLD-RELVAL-2026`
**Source type:** `exchange product source packet`
**Pointer:** `strategy-seeds/sources/CME-GAS-GOLD-RELVAL-2026/source.md`
**R1-R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/cme-gasgold-ratio_card.md`

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
| v1 | 2026-06-30 | Initial XNG/XAU relative-value basket build | pending Q02 enqueue |
