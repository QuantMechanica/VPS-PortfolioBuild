# QM5_10131_tv-nifty-range-short - Strategy Spec

**EA ID:** QM5_10131
**Slug:** `tv-nifty-range-short`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see TradingView popular Pine scripts source)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades only short setups after the first 60 minutes of the local index cash-session analog. It records the opening-range high and low, requires price to trade above the opening-range high, then waits for a later M15 candle to close back below that high. A short market entry is sent once per session when the range height is between 0.5 and 2.5 ATR(14), with a stop at the larger of opening-range high plus 0.5 ATR or entry plus 1.5 ATR. The position exits at the opening-range low target, at session end, or when a closed bar is back above the opening-range high.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period used for range validation and short stop placement. |
| `strategy_open_range_minutes` | 60 | 15-240 | Minutes from session start used to build the opening range. |
| `strategy_min_range_atr_mult` | 0.5 | 0.1-5.0 | Minimum opening-range height as a multiple of ATR. |
| `strategy_max_range_atr_mult` | 2.5 | 0.1-10.0 | Maximum opening-range height as a multiple of ATR. |
| `strategy_range_sl_atr_mult` | 0.5 | 0.0-5.0 | ATR buffer added above the opening-range high for the short stop candidate. |
| `strategy_entry_sl_atr_mult` | 1.5 | 0.1-10.0 | ATR stop distance above entry for the second short stop candidate. |
| `strategy_max_spread_stop_frac` | 0.10 | 0.0-1.0 | Maximum allowed spread as a fraction of stop distance. |
| `strategy_dax_start_hour` | 9 | 0-23 | Broker-time hour for the DAX opening-range analog. |
| `strategy_dax_start_minute` | 0 | 0-59 | Broker-time minute for the DAX opening-range analog. |
| `strategy_dax_end_hour` | 17 | 0-23 | Broker-time hour for DAX session-end exit. |
| `strategy_dax_end_minute` | 30 | 0-59 | Broker-time minute for DAX session-end exit. |
| `strategy_us_start_hour` | 15 | 0-23 | Broker-time hour for the US cash-open analog. |
| `strategy_us_start_minute` | 30 | 0-59 | Broker-time minute for the US cash-open analog. |
| `strategy_us_end_hour` | 22 | 0-23 | Broker-time hour for US session-end exit. |
| `strategy_us_end_minute` | 0 | 0-59 | Broker-time minute for US session-end exit. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - canonical available DWX DAX index proxy for the card's `DAX.DWX` target.
- `NDX.DWX` - Nasdaq 100 index analog for the US cash-session failed upside breakout.
- `WS30.DWX` - Dow 30 index analog for the US cash-session failed upside breakout.
- `SP500.DWX` - S&P 500 backtest-only index analog for the US cash-session failed upside breakout.

**Explicitly NOT for:**
- Forex and commodity `.DWX` symbols - the card is an index opening-range reversal strategy.
- `DAX.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Intraday, from post-opening-range trigger to session end at the latest. |
| Expected drawdown profile | Short index reversal trades can cluster losses during strong trend days. |
| Regime preference | Intraday reversal after a failed upside opening-range breakout. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView user script search/category entry
**Pointer:** `https://www.tradingview.com/scripts/search/entry/page-28/?script_access=all&script_type=strategies`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10131_tv-nifty-range-short.md`

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
| v1 | 2026-06-09 | Initial build from card | 9a76b503-b95c-408b-bf6d-e1a1c67b0f7d |
