# QM5_12604_cme-oilgold-ratio - Strategy Spec

**EA ID:** QM5_12604
**Slug:** `cme-oilgold-ratio`
**Source:** `CME-OIL-GOLD-RATIO-2024` (see `strategy-seeds/sources/CME-OIL-GOLD-RATIO-2024/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

This EA implements a low-frequency structural commodity relative-value sleeve as
a two-leg basket on `XTIUSD.DWX` and `XAUUSD.DWX`. It computes the D1 log spread
`ln(XTIUSD) - beta * ln(XAUUSD)`, converts it to a rolling z-score, opens a
short-ratio package above +2.0, opens a long-ratio package below -2.0, and exits
both legs when the spread reverts inside +/-0.5. Each leg carries an ATR(20) *
3.0 hard stop.

The strategy is intentionally not a duplicate of `QM5_12577_cme-xauxag-ratio`:
it is energy versus gold, not an intra-metals spread. It is also not
`QM5_12578_eia-oilgas-ratio`, because this hedge leg is gold rather than natural
gas, and it uses CME oil-through-gold lineage rather than EIA oil/gas linkage.

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
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | XAU entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |
| `strategy_entry_hour_broker` | 2 | 0-23 | Earliest broker hour to attempt the daily basket entry |
| `strategy_entry_minute_broker` | 0 | 0-59 | Earliest broker minute to attempt the daily basket entry |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - host chart and oil numerator, magic slot 0.
- `XAUUSD.DWX` - hedge leg and gold denominator, magic slot 1.
- `QM5_12604_XTI_XAU_RATIO_D1` - logical basket symbol for Q02 dispatch.

**Explicitly NOT for:**
- `XNGUSD.DWX` - covered by the separate XTI/XNG energy ratio and XNG seasonal/news sleeves.
- `XAGUSD.DWX` - covered by the separate XAU/XAG metals ratio.
- Equity indices and FX pairs - different economic exposure from the CME oil/gold ratio source.

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
| Expected drawdown profile | `Moderate; relative-value baskets can gap when oil shocks and gold shocks diverge` |
| Regime preference | `oil/gold relative-value mean reversion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CME-OIL-GOLD-RATIO-2024`
**Source type:** `exchange article`
**Pointer:** `https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12604_cme-oilgold-ratio_card.md`

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
| v2 | 2026-06-28 | Delay basket entry until XAU trade session is open | avoids one-leg XTI packages at the D1 bar open |
| v1 | 2026-06-27 | Initial build from card | pending commit |
