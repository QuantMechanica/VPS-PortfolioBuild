# QM5_1069_carver-assettrend - Strategy Spec

**EA ID:** QM5_1069
**Slug:** carver-assettrend
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a (see `sources/rob-carver-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades a daily asset-class trend forecast. For the current symbol's group, it computes each member's D1 percentage return divided by recent EWMA volatility, averages those normalised returns equally, and cumulates the result into an aggregate normalised price. It then applies an EWMAC forecast to that aggregate using fast 32 and slow 128 EMA spans, normalises by 25-day EWMA group volatility, and caps the forecast to +/-20. Long entries fire when the group forecast is above +2, short entries fire below -2, and open positions are flagged for close when the forecast crosses back through zero.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_period` | 32 | 2-127 | Fast EMA span for aggregate EWMAC. |
| `strategy_slow_period` | 128 | 33-512 | Slow EMA span for aggregate EWMAC. |
| `strategy_vol_span` | 25 | 2-100 | EWMA span for return and aggregate volatility normalisation. |
| `strategy_forecast_scalar` | 1.0 | >0 | Scalar applied to the raw EWMAC forecast. |
| `strategy_entry_forecast` | 2.0 | >0 | Absolute forecast threshold for new long or short entries. |
| `strategy_forecast_cap` | 20.0 | >0 | Maximum absolute forecast value after capping. |
| `strategy_atr_period` | 20 | 2-100 | D1 ATR period used for the emergency stop. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiple for the emergency stop. |
| `strategy_min_group_symbols` | 3 | 1-9 | Minimum available members required to compute a group forecast. |
| `strategy_spread_days` | 20 | 0-60 | D1 spread lookback for the card's 2x median spread entry guard. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX majors group member from the approved card.
- `GBPUSD.DWX` - FX majors group member from the approved card.
- `AUDUSD.DWX` - FX majors group member from the approved card.
- `NZDUSD.DWX` - FX majors group member from the approved card.
- `USDJPY.DWX` - FX majors group member from the approved card.
- `USDCAD.DWX` - FX majors group member from the approved card.
- `GDAXI.DWX` - DWX matrix canonical DAX index symbol used for the card's GER40 exposure.
- `NDX.DWX` - Equity index group member from the approved card.
- `WS30.DWX` - Equity index group member from the approved card.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SP500.DWX` - not required by the approved card.
- Commodity symbols - outside the two approved asset groups.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6 |
| Typical hold time | Multi-day to multi-week trend holds; card frontmatter does not specify a numeric hold-time field. |
| Expected drawdown profile | Trend-following profile with clustered losses during non-trending reversals. |
| Regime preference | Trend-following / asset-class momentum. |
| Win rate target (qualitative) | Medium; card frontmatter does not specify a numeric win-rate target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog
**Pointer:** Rob Carver qoppac posts cited in `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1069_carver-assettrend.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1069_carver-assettrend.md`

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
| v1 | 2026-06-18 | Initial build from card | 05449c97-8cd1-4545-8832-115450620271 |
