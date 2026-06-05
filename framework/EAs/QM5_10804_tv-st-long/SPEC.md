# QM5_10804_tv-st-long - Strategy Spec

**EA ID:** QM5_10804
**Slug:** tv-st-long
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

This EA trades long only. It calculates SuperTrend from `hl2` using ATR period 10 and multiplier 3.0, then enters a buy when the last closed bar changes from bearish SuperTrend state to bullish SuperTrend state. It exits when the last closed bar changes back from bullish to bearish, with an optional stale-trade time stop. The initial hard stop is the lower of the active SuperTrend lower band and a 2.0 * ATR(14) floor below entry, and open long positions trail their stop to the active bullish SuperTrend band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_st_atr_period` | 10 | 7-14 in P3 sweep | ATR period used by the SuperTrend calculation. |
| `strategy_st_multiplier` | 3.0 | 2.0-8.5 in P3 sweep | Volatility multiplier used by the SuperTrend bands. |
| `strategy_safety_atr_period` | 14 | 14 fixed | ATR period for the V5 safety stop floor. |
| `strategy_safety_atr_mult` | 2.0 | 2.0 fixed | Multiplier for the V5 safety stop floor. |
| `strategy_st_warmup_bars` | 200 | 20-500 | Closed bars used to stabilize the SuperTrend state. |
| `strategy_enable_max_bars_exit` | true | true/false | Enables the optional V5 stale-trade exit. |
| `strategy_max_bars_h4` | 120 | 120 fixed | Maximum H4 bars to hold before stale exit. |
| `strategy_max_bars_d1` | 60 | 60 fixed | Maximum D1 bars to hold before stale exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 forex basket member with native DWX coverage.
- `GBPUSD.DWX` - card R3 forex basket member with native DWX coverage.
- `USDJPY.DWX` - card R3 forex basket member with native DWX coverage.
- `XAUUSD.DWX` - canonical DWX form of the card's `XAUUSD` gold target.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` target.
- `NDX.DWX` - card R3 US index basket member with DWX coverage.
- `WS30.DWX` - card R3 US index basket member with DWX coverage.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - registry symbols must carry the `.DWX` suffix in backtest context.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | multi-bar trend holds; stale exit at 120 H4 bars or 60 D1 bars |
| Expected drawdown profile | whipsaw losses in sideways regimes |
| Regime preference | trend-following / volatility-trailing-stop |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `SuperTrend STRATEGY`, author handle `holdon_to_profits`, updated 2026-02-11
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10804_tv-st-long.md`

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
| v1 | 2026-06-05 | Initial build from card | a8405e71-3692-44d0-baa3-1e2f3c4c29a4 |
