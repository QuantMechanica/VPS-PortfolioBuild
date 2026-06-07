# QM5_11199_ft-fadxsma - Strategy Spec

**EA ID:** QM5_11199
**Slug:** ft-fadxsma
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades on closed H1 bars. It goes long when SMA(12) crosses above SMA(48) and ADX(14) is above 30, and it goes short when SMA(12) crosses below SMA(48) under the same ADX filter. Each position receives an ATR(14) x 2.0 stop at entry. Positions close when ADX falls below 30, when the normalized source ROI threshold is reached, when the source 5% stop condition is reached, or by the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 10-24 | ADX lookback period used for entry and exit threshold checks. |
| `strategy_entry_adx` | 30.0 | 20.0-35.0 | Minimum ADX value required for SMA-cross entries; exit triggers below this level. |
| `strategy_sma_short_period` | 12 | 8-20 | Fast SMA period for crossover direction. |
| `strategy_sma_long_period` | 48 | 32-96 | Slow SMA period for crossover direction. |
| `strategy_atr_stop_period` | 14 | fixed baseline | ATR period for the entry stop. |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | ATR multiplier for the entry stop. |
| `strategy_source_stoploss_pct` | 5.0 | source fixed | Percent loss threshold from the source stoploss. |
| `strategy_max_spread_stop_pct` | 8.0 | card fixed | Maximum spread as a percent of planned stop distance. |
| `strategy_roi_1_minutes` | 0 | source fixed | First source ROI ladder minute. |
| `strategy_roi_1_pct` | 5.0 | source fixed | First source ROI ladder threshold. |
| `strategy_roi_2_minutes` | 30 | source fixed | Second source ROI ladder minute. |
| `strategy_roi_2_pct` | 10.0 | source fixed | Second source ROI ladder threshold. |
| `strategy_roi_3_minutes` | 60 | source fixed | Third source ROI ladder minute. |
| `strategy_roi_3_pct` | 7.5 | source fixed | Third source ROI ladder threshold. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with full DWX matrix coverage for H1 SMA/ADX logic.
- `GBPUSD.DWX` - major FX pair from the card's R3 portable basket.
- `XAUUSD.DWX` - liquid metal CFD from the card's R3 portable basket.
- `GDAXI.DWX` - matrix-valid DAX CFD equivalent for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | H1 bars; intermittent trend-following holds from hours to multiple days until ADX/ROI/stop exit |
| Expected drawdown profile | medium risk class from card initial risk profile |
| Regime preference | trend-following / moving-average crossover with ADX confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/futures/FAdxSmaStrategy.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11199_ft-fadxsma.md`

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
| v1 | 2026-06-08 | Initial build from card | 379a6fc6-48f2-48fa-a67e-f83985e9c31f |
