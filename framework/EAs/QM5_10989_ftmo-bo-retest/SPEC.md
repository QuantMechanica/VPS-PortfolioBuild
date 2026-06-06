# QM5_10989_ftmo-bo-retest - Strategy Spec

**EA ID:** QM5_10989
**Slug:** `ftmo-bo-retest`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA defines a tight M30 range as the highest high and lowest low of the prior 24 closed M30 bars. It waits for a candle to close beyond that range by at least 0.15 ATR(14), then requires a retest of the old boundary within the next six bars and an acceptance close back outside the range before entering at market. Long trades use the old range high as the retest boundary; short trades use the old range low. Exits are the 2.0R target, the framework stop loss, a full M30 close back inside the original range, or a 24-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_donchian_bars` | 24 | 2-200 | Closed bars used to define the range high and range low. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for range sizing, breakout buffer, and stop offset. |
| `strategy_min_range_atr` | 0.8 | 0.1-10.0 | Minimum range height as a multiple of ATR(14). |
| `strategy_max_range_atr` | 2.5 | 0.1-10.0 | Maximum range height as a multiple of ATR(14). |
| `strategy_breakout_buffer_atr` | 0.15 | 0.0-5.0 | Required close beyond the range as a multiple of ATR(14). |
| `strategy_max_retest_bars` | 6 | 1-50 | Maximum number of bars after breakout allowed for retest confirmation. |
| `strategy_max_breakout_bar_atr` | 2.0 | 0.1-10.0 | Maximum breakout candle range as a multiple of ATR(14). |
| `strategy_failed_breakout_lookback` | 12 | 0-100 | Bars checked for an opposite failed breakout before accepting a new setup. |
| `strategy_stop_atr_mult` | 0.75 | 0.1-10.0 | ATR offset used with the retest swing for the stop loss. |
| `strategy_reward_r` | 2.0 | 0.1-10.0 | Target reward multiple of initial stop distance. |
| `strategy_max_hold_bars` | 24 | 1-200 | Time exit after this many M30 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid FX major with DWX data.
- `GBPUSD.DWX` - Card-listed liquid FX major with DWX data.
- `GDAXI.DWX` - Matrix-verified DAX proxy for the card's `GER40.DWX` target.
- `NDX.DWX` - Card-listed liquid index with DWX data.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.
- `SPX500.DWX` - Not a canonical DWX custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Retest entries can hold up to 24 M30 bars, about 12 hours. |
| Expected drawdown profile | False breakout losses are capped at the initial 1R stop; losses can cluster in choppy ranges. |
| Regime preference | Breakout / volatility expansion with accepted retest. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** `https://academy.ftmo.com/lesson/how-to-spot-breakouts-and-fakeouts/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10989_ftmo-bo-retest.md`

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
| v1 | 2026-06-07 | Initial build from card | 2a218da2-7209-4c87-9fc1-60384aa433c5 |
