# QM5_10386_et-lunch-brk - Strategy Spec

**EA ID:** QM5_10386
**Slug:** `et-lunch-brk`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA runs on M5 index data. At the first eligible closed bar at or after broker time 19:00, it computes the highest high and lowest low of the prior 15 M5 bars once for that trading day as the lunch range. If the symbol is flat and no stop order pair is already working, it places a buy stop one tick above the range high and a sell stop one tick below the range low. The long stop is below the range low by 0.3 times the range, the short stop is above the range high by 0.3 times the range, and any open position or unfilled stop order is closed or cancelled after broker time 22:00.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_bars` | 15 | 12-18 | Number of closed M5 bars used to define the lunch high and low. |
| `strategy_stop_factor` | 0.30 | 0.20-0.50 | Fraction of lunch range added beyond the opposite side for the stop loss. |
| `strategy_trigger_ticks` | 1 | 1-3 | Stop entry offset beyond the lunch high or low. |
| `strategy_atr_period` | 20 | 10-40 | ATR period for the upper range-size filter. |
| `strategy_max_range_atr_mult` | 1.50 | 0.50-3.00 | Skip if lunch range is wider than this multiple of ATR. |
| `strategy_lunch_hhmm` | 1900 | 0000-2359 | Broker-time boundary after which the lunch breakout orders may be placed. |
| `strategy_close_hhmm` | 2200 | 0000-2359 | Broker-time close boundary for cancelling orders and flattening positions. |
| `strategy_allow_monday` | true | true/false | Include Monday entries. |
| `strategy_allow_tuesday` | true | true/false | Include Tuesday entries. |
| `strategy_allow_wednesday` | true | true/false | Include Wednesday entries. |
| `strategy_allow_thursday` | true | true/false | Include Thursday entries. |
| `strategy_allow_friday` | true | true/false | Include Friday entries. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol matches the card's US index breakout target.
- `NDX.DWX` - Nasdaq 100 is a live index CFD analog for US large-cap intraday breakout behaviour.
- `WS30.DWX` - Dow 30 is the closest live CFD analog to the source YM index contract.
- `GDAXI.DWX` - DAX custom symbol is the available DWX equivalent for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, from post-lunch breakout through same-day close |
| Expected drawdown profile | Slippage-sensitive intraday breakout drawdowns during low-volatility or fake-breakout regimes |
| Regime preference | breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/example-trading-system.44092/page-43`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10386_et-lunch-brk.md`

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
| v1 | 2026-06-14 | Initial build from card | 2a76e72b-db78-45e6-bd52-9386b286ac40 |
