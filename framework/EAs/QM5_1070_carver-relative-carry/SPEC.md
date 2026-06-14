# QM5_1070_carver-relative-carry - Strategy Spec

**EA ID:** QM5_1070
**Slug:** carver-relative-carry
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades relative carry inside a fixed FX basket. On each closed D1 rebalance, it computes each pair's annualised broker-swap carry divided by annualised D1 volatility, scales the result by 30, caps it to +/-20, and subtracts the valid-basket mean forecast. It opens long when the current symbol's relative forecast is above +2 and short when it is below -2. It closes a long when the relative forecast falls to zero or below, and closes a short when the relative forecast rises to zero or above.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_entry_forecast | 2.0 | > 0 | Relative forecast threshold for new long/short entries. |
| strategy_vol_span_days | 25 | >= 2 | D1 EWMA volatility span used to normalise carry. |
| strategy_atr_period | 20 | >= 1 | ATR period for the emergency stop. |
| strategy_atr_stop_mult | 2.5 | > 0 | ATR multiple for the emergency stop. |
| strategy_min_valid_symbols | 6 | 1-9 | Minimum basket symbols with valid carry and volatility data. |
| strategy_max_positions | 4 | >= 1 | Maximum concurrent positions across this EA's registered basket slots. |
| strategy_spread_median_days | 20 | >= 1 | D1 spread lookback used for the median spread cap. |
| strategy_spread_cap_mult | 2.0 | > 0 | Skip entry when current spread is above this multiple of median spread. |
| strategy_forecast_scalar | 30.0 | > 0 | Scalar applied to raw carry divided by volatility. |
| strategy_forecast_cap | 20.0 | > 0 | Absolute cap applied to each symbol's carry forecast before de-meaning. |
| strategy_swap_days_per_year | 256.0 | > 0 | Annualisation factor for swap carry and D1 volatility. |
| strategy_rebalance_hour | 1 | 0-23 | Earliest broker hour to evaluate the daily rebalance after rollover. |

---

## 3. Symbol Universe

**Designed for:**
- AUDJPY.DWX - FX carry pair in the card's suggested DWX P2 universe.
- NZDJPY.DWX - FX carry pair in the card's suggested DWX P2 universe.
- AUDUSD.DWX - FX carry pair in the card's suggested DWX P2 universe.
- NZDUSD.DWX - FX carry pair in the card's suggested DWX P2 universe.
- USDJPY.DWX - FX carry pair in the card's suggested DWX P2 universe.
- GBPJPY.DWX - FX carry pair in the card's suggested DWX P2 universe.
- EURUSD.DWX - FX carry pair in the card's suggested DWX P2 universe.
- GBPUSD.DWX - FX carry pair in the card's suggested DWX P2 universe.
- USDCAD.DWX - FX carry pair in the card's suggested DWX P2 universe.

**Explicitly NOT for:**
- Index, commodity, and crypto symbols - the card defines a broker-routable FX relative-carry basket only.
- FX pairs outside the registered basket - they are not part of the card's de-meaned P2 universe for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 2 |
| Typical hold time | Slow relative-carry holds, typically weeks to months until the relative forecast crosses zero. |
| Expected drawdown profile | Carry drawdowns can cluster during FX regime shifts; emergency stop is 2.5 ATR(20) and thesis exit is forecast zero-cross. |
| Regime preference | Cross-sectional FX carry / relative-value regime. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog
**Pointer:** https://qoppac.blogspot.com/2017/06/some-more-trading-rules.html and https://qoppac.blogspot.com/2021/12/my-trading-system.html
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1070_carver-relative-carry.md`

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
| v1 | 2026-06-14 | Initial build from card | ed852436-f592-4971-95e1-55b73508615b |
