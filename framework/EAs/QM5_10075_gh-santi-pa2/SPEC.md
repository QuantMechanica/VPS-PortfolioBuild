# QM5_10075_gh-santi-pa2 - Strategy Spec

**EA ID:** QM5_10075
**Slug:** gh-santi-pa2
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175 (see `sources/github-mql5-stars-20`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each new D1 bar, the EA inspects the last closed candle and the candle before it. If the last candle is bearish and closes below the prior candle low, it places a buy stop at that bearish candle's high for the next bar. If the last candle is bullish and closes above the prior candle high, it places a sell stop at that bullish candle's low for the next bar. Open trades close when the last closed bar is profitable versus entry, or after 10 bars in the market; an ATR protective stop is attached for V5 baseline safety.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR lookback used only for the protective stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.5-10.0 | ATR multiple for the protective stop distance. |
| `strategy_max_hold_bars` | 10 | 1-50 | Maximum D1 bars to hold if no profitable bar-close exit occurs. |
| `strategy_pending_expiration_bars` | 1 | 1-5 | Number of current-chart bars before an unfilled trigger order expires. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with full OHLC data in the DWX matrix.
- `GBPUSD.DWX` - card-listed FX major with full OHLC data in the DWX matrix.
- `XAUUSD.DWX` - card-listed gold symbol with full OHLC data in the DWX matrix.
- `GDAXI.DWX` - available DWX DAX equivalent for the card-listed `GER40.DWX`, which is not present in the matrix.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX` for DAX exposure.
- Symbols outside the DWX matrix - unavailable for deterministic P2 backtests.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Expected trade frequency | Not specified in frontmatter; card implies event-driven D1 two-bar triggers. |
| Typical hold time | Profitable first closed bar after entry, otherwise maximum `10` D1 bars. |
| Expected drawdown profile | Reversal-breakout entries with ATR protective stop and time exit. |
| Regime preference | Price-action reversal after one-bar extension. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub source code
**Pointer:** `santiago-cruzlopez/MQL5`, `1_Expert_Advisors_EA/018_Price_Action_EA.mq5`, https://github.com/santiago-cruzlopez/MQL5/blob/master/1_Expert_Advisors_EA/018_Price_Action_EA.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10075_gh-santi-pa2.md`

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
| v1 | 2026-06-10 | Initial build from card | e5ae380a-6cd5-49b0-9037-7ccc0880bc1a |
