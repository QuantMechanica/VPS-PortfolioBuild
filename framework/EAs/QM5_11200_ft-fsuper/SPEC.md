# QM5_11200_ft-fsuper - Strategy Spec

**EA ID:** QM5_11200
**Slug:** `ft-fsuper`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades on H1 closed bars using the futures Freqtrade triple Supertrend rule. It opens long when all three buy Supertrend states are up, and opens short when all three sell Supertrend states are down, with nonzero tick volume on the last closed bar. Long positions exit when the second sell Supertrend state is down; short positions exit when the second buy Supertrend state is up. It also applies the source stoploss, a normalized source ROI ladder, source-style percent trailing, V5 Friday close, and an ATR stop at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `buy_m1` | 4 | 2-6 | Multiplier for first buy Supertrend state. |
| `buy_m2` | 7 | 3-7 | Multiplier for second buy Supertrend state. |
| `buy_m3` | 1 | 1-5 | Multiplier for third buy Supertrend state. |
| `buy_p1` | 8 | 8-14 | Period for first buy Supertrend state. |
| `buy_p2` | 9 | 9-18 | Period for second buy Supertrend state. |
| `buy_p3` | 8 | 8-18 | Period for third buy Supertrend state. |
| `sell_m1` | 1 | fixed | Multiplier for first sell Supertrend state from source sell params. |
| `sell_m2` | 3 | fixed | Multiplier for second sell Supertrend state from source sell params. |
| `sell_m3` | 6 | fixed | Multiplier for third sell Supertrend state from source sell params. |
| `sell_p1` | 16 | fixed | Period for first sell Supertrend state from source sell params. |
| `sell_p2` | 18 | fixed | Period for second sell Supertrend state from source sell params. |
| `sell_p3` | 18 | fixed | Period for third sell Supertrend state from source sell params. |
| `atr_stop_period` | 14 | fixed | ATR period for the V5 entry stop. |
| `atr_stop_mult` | 2.5 | 2.0-3.0 | ATR multiplier for the V5 entry stop. |
| `strategy_warmup_bars` | 180 | fixed | Closed-bar Supertrend warmup depth. |
| `strategy_max_spread_stop_pct` | 8.0 | fixed | Maximum spread as percent of planned ATR stop distance. |
| `strategy_source_stoploss_pct` | 26.5 | fixed | Source stoploss threshold in percent from entry. |
| `strategy_trailing_positive_pct` | 5.0 | fixed | Source trailing distance after activation. |
| `strategy_trailing_offset_pct` | 10.0 | fixed | Source positive offset threshold if offset-only mode is enabled. |
| `strategy_trailing_only_offset_is_reached` | false | fixed | Source offset-only flag; false means offset does not gate trailing. |
| `strategy_roi_1_minutes` | 0 | fixed | Start minute for first ROI rung. |
| `strategy_roi_1_pct` | 10.0 | fixed | First ROI threshold. |
| `strategy_roi_2_minutes` | 30 | fixed | Start minute for second ROI rung. |
| `strategy_roi_2_pct` | 75.0 | fixed | Source second ROI threshold, normalized by monotonic floor logic. |
| `strategy_roi_3_minutes` | 60 | fixed | Start minute for third ROI rung. |
| `strategy_roi_3_pct` | 5.0 | fixed | Third ROI threshold. |
| `strategy_roi_4_minutes` | 120 | fixed | Start minute for fourth ROI rung. |
| `strategy_roi_4_pct` | 2.5 | fixed | Fourth ROI threshold. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with H1 ATR trend-state data.
- `GBPUSD.DWX` - liquid FX major suitable for the same H1 volatility-band logic.
- `XAUUSD.DWX` - liquid metals CFD where ATR-normalized Supertrend mechanics remain portable.
- `GDAXI.DWX` - DAX custom symbol available in the matrix; used as the DWX port for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated symbol is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX equivalent.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable for DWX backtesting.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | `hours to several days, governed by opposite Supertrend state, ROI, trailing, stop, and Friday close` |
| Expected drawdown profile | `high risk because the source stoploss is wide and the system can trade both directions through trend reversals` |
| Regime preference | `trend-following volatility-band regimes` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `GitHub strategy source`
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/futures/FSupertrendStrategy.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11200_ft-fsuper.md`

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
| v1 | 2026-06-08 | Initial build from card | aed66665-1c27-48ae-90b2-926eb93e056c |
