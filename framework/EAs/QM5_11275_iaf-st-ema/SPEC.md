# QM5_11275_iaf-st-ema - Strategy Spec

**EA ID:** QM5_11275
**Slug:** iaf-st-ema
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades long only on closed H2 bars. It opens a position when SuperTrend(ATR 10, factor 3.0) has flipped bullish within the last 10 bars, EMA(20) has crossed above EMA(100) within the same confirmation window, RSI(14) is below 70, and the close is below the upper Bollinger Band(20, 2.0). It closes manually when SuperTrend flips bearish and EMA(20) crosses below EMA(100) within the confirmation window, unless RSI is at or below 30 and the close is at or below the lower Bollinger band. The position also has the card's fixed 5% stop loss and 10% take-profit translated into V5 fixed-risk sizing through the framework.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_st_atr_period | 10 | 2-100 | ATR length used by the SuperTrend calculation. |
| strategy_st_factor | 3.0 | 0.5-10.0 | ATR multiplier used by the SuperTrend bands. |
| strategy_ema_short_period | 20 | 2-200 | Fast EMA confirmation period. |
| strategy_ema_long_period | 100 | 5-500 | Slow EMA confirmation period. |
| strategy_confirm_lookback | 10 | 1-50 | Number of closed bars allowed for the SuperTrend flip and EMA cross confirmation. |
| strategy_rsi_period | 14 | 2-100 | RSI period for entry and exit suppression filters. |
| strategy_rsi_upper | 70.0 | 50.0-95.0 | Long entries are blocked when RSI is at or above this level. |
| strategy_rsi_lower | 30.0 | 5.0-50.0 | Manual exits are suppressed when RSI is at or below this level and price is below the lower Bollinger band. |
| strategy_bb_period | 20 | 5-100 | Bollinger band period. |
| strategy_bb_deviation | 2.0 | 0.5-5.0 | Bollinger band standard deviation multiplier. |
| strategy_stop_loss_pct | 5.0 | 0.1-20.0 | Long stop-loss distance as percent below entry. |
| strategy_take_profit_pct | 10.0 | 0.1-50.0 | Long take-profit distance as percent above entry. |
| strategy_spread_pct_of_stop | 15.0 | 0.0-100.0 | Blocks only genuinely wide spread when spread exceeds this percent of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-stated DWX forex target and present in the symbol matrix.
- XAUUSD.DWX - card-stated DWX metals target and present in the symbol matrix.
- GDAXI.DWX - canonical matrix DAX symbol used in place of card-stated GER40.DWX, which is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- GER40.DWX - not a canonical available DWX symbol in the matrix for this build.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not eligible for registration or P2 setfiles.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H2 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Expected trade frequency | not specified in card frontmatter; implied about 45 closed-position opportunities per year per symbol |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | not specified in card frontmatter; fixed 5% stop and V5 fixed-risk sizing bound per-trade loss |
| Regime preference | trend-following / SuperTrend and EMA confirmation |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository strategy example
**Pointer:** `coding-kitties/investing-algorithm-framework`, `examples/tutorial/strategies/supertrend_ema_confirmation/strategy.py`, https://github.com/coding-kitties/investing-algorithm-framework/blob/main/examples/tutorial/strategies/supertrend_ema_confirmation/strategy.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11275_iaf-st-ema.md`

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
| v1 | 2026-06-20 | Initial build from card | fe3ab3ca-38b5-4234-a17e-96ef3e910aa2 |
