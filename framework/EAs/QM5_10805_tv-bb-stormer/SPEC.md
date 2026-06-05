# QM5_10805_tv-bb-stormer - Strategy Spec

**EA ID:** QM5_10805
**Slug:** `tv-bb-stormer`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

This EA trades Bollinger Band breakouts on the close of a bar. It opens long when the just-closed bar crosses above the upper Bollinger Band and opens short when the just-closed bar crosses below the lower Bollinger Band. When enabled, the EMA filter requires long closes to be above the EMA and short closes to be below the EMA. The stop is the lowest low or highest high over the configured lookback, the target is a fixed R multiple, and an open position closes early on an opposite Bollinger breakout.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 14, 20, 34 | Bollinger Band lookback length. |
| `strategy_bb_deviation` | 2.0 | 1.5, 2.0, 2.5 | Bollinger Band standard deviation multiplier. |
| `strategy_ema_filter_period` | 0 | 0, 50, 100, 200 | Optional EMA side filter; 0 disables it. |
| `strategy_stop_lookback` | 10 | 5, 10, 20 | Bars used for structure stop placement. |
| `strategy_target_rr` | 1.6 | 1.0, 1.6, 2.0 | Take-profit distance as a multiple of initial risk. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 portable FX basket member with DWX data.
- `GBPUSD.DWX` - Card R3 portable FX basket member with DWX data.
- `USDJPY.DWX` - Card R3 portable FX basket member with DWX data.
- `XAUUSD.DWX` - Card R3 gold member; card omitted `.DWX`, matrix confirms `XAUUSD.DWX`.
- `GDAXI.DWX` - DAX proxy for card-stated `GER40.DWX`; matrix confirms `GDAXI.DWX`.
- `NDX.DWX` - Card R3 portable US index basket member with DWX data.
- `WS30.DWX` - Card R3 portable US index basket member with DWX data.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - Missing `.DWX` suffix in backtest context; use `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

The card also lists `M30` and `H4` as parameter-test timeframes; matching backtest setfiles are generated for those frames.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Not specified in card; bounded by fixed R target, structure stop, opposite breakout, and Friday close. |
| Expected drawdown profile | Breakout system with losses clustered in false-breakout or low-follow-through regimes. |
| Regime preference | Trend-following / volatility-expansion breakout. |
| Win rate target (qualitative) | Medium; payoff is controlled by fixed R target. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** https://www.tradingview.com/script/aksPa3e7-Bollinger-Bands-Modified-Stormer/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10805_tv-bb-stormer.md`

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
| v1 | 2026-06-05 | Initial build from card | 8f3b05e4-7631-4b55-9e86-e312128480b9 |
