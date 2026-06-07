# QM5_11191_ft-supertrend - Strategy Spec

**EA ID:** QM5_11191
**Slug:** `ft-supertrend`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades long on H1 closed bars when all three buy Supertrend direction states are up and the last closed bar has nonzero tick volume. The buy states use multiplier/period pairs 4/8, 7/9, and 1/8. It exits an open long when all three sell Supertrend states are down using 1/16, 3/18, and 6/18, or when the source ROI ladder or source stoploss threshold is reached. Entry protection is an ATR fail-safe stop using ATR(14) at 3.0 times ATR.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_buy_st_1_period` | 8 | 8-10 | Period for first buy Supertrend state. |
| `strategy_buy_st_1_mult` | 4.0 | 3.0-5.0 | Multiplier for first buy Supertrend state. |
| `strategy_buy_st_2_period` | 9 | 9-12 | Period for second buy Supertrend state. |
| `strategy_buy_st_2_mult` | 7.0 | 6.0-7.0 | Multiplier for second buy Supertrend state. |
| `strategy_buy_st_3_period` | 8 | 8-10 | Period for third buy Supertrend state. |
| `strategy_buy_st_3_mult` | 1.0 | 1.0-2.0 | Multiplier for third buy Supertrend state. |
| `strategy_sell_st_1_period` | 16 | fixed | Period for first sell Supertrend state. |
| `strategy_sell_st_1_mult` | 1.0 | fixed | Multiplier for first sell Supertrend state. |
| `strategy_sell_st_2_period` | 18 | fixed | Period for second sell Supertrend state. |
| `strategy_sell_st_2_mult` | 3.0 | fixed | Multiplier for second sell Supertrend state. |
| `strategy_sell_st_3_period` | 18 | fixed | Period for third sell Supertrend state. |
| `strategy_sell_st_3_mult` | 6.0 | fixed | Multiplier for third sell Supertrend state. |
| `strategy_atr_failsafe_period` | 14 | fixed | ATR period for the MT5 fail-safe stop. |
| `strategy_atr_failsafe_mult` | 3.0 | 2.5-3.5 | ATR multiplier for the MT5 fail-safe stop. |
| `strategy_warmup_bars` | 199 | fixed | Minimum closed bars before trading. |
| `strategy_max_spread_stop_pct` | 8.0 | fixed | Maximum spread as a percent of planned stop distance. |
| `strategy_source_stoploss_pct` | 26.5 | fixed | Source stoploss threshold in percent from entry. |
| `strategy_roi_1_minutes` | 0 | fixed | Start minute for first ROI rung. |
| `strategy_roi_1_pct` | 8.7 | fixed | ROI exit threshold before 372 minutes. |
| `strategy_roi_2_minutes` | 372 | fixed | Start minute for second ROI rung. |
| `strategy_roi_2_pct` | 5.8 | fixed | ROI exit threshold before 861 minutes. |
| `strategy_roi_3_minutes` | 861 | fixed | Start minute for third ROI rung. |
| `strategy_roi_3_pct` | 2.9 | fixed | ROI exit threshold before 2221 minutes. |
| `strategy_roi_4_minutes` | 2221 | fixed | Start minute for flat ROI rung. |
| `strategy_roi_4_pct` | 0.0 | fixed | ROI exit threshold after 2221 minutes. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with enough H1 bars for ATR trend-state logic.
- `GBPUSD.DWX` - liquid FX major suitable for the same portable H1 ATR trend-state rules.
- `XAUUSD.DWX` - liquid metal CFD where ATR-normalized Supertrend mechanics remain portable.
- `NDX.DWX` - liquid index CFD for the card's index-portable basket.

**Explicitly NOT for:**
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
| Trades / year / symbol | `55` |
| Typical hold time | `hours to about two trading days, governed by Supertrend exit and the 0/372/861/2221 minute ROI ladder` |
| Expected drawdown profile | `medium risk from a long-only ATR trend system with a fail-safe stop` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `GitHub strategy source`
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Supertrend.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11191_ft-supertrend.md`

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
| v1 | 2026-06-07 | Initial build from card | 9ec2d1ff-a4c6-42f2-a773-3416513b4a0b |
