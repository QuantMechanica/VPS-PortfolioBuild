# QM5_9506 carver-starter - Strategy Spec

**EA ID:** QM5_9506
**Slug:** carver-starter
**Source:** 1a059d6d-84fa-5d0c-94c5-86dd0481637c (`sources/carver-leveraged-trading`)
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA mechanizes the approved Carver starter-system card as a daily symmetric trend follower. On each D1 closed bar it reads SMA(16) and SMA(64). A bullish crossover opens one long position for the current magic slot; a bearish crossover opens one short position. Existing positions close when the opposite SMA state appears or when the configured maximum hold time is reached.

The entry path requires enough D1 history, a non-crossed quote, and current spread no higher than the configured multiple of recent median D1 spread. Stop distance uses annualized close-return volatility bounded by ATR(25) multiples.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_fast_sma_period` | 16 | Fast SMA lookback on D1 closes. |
| `strategy_slow_sma_period` | 64 | Slow SMA lookback on D1 closes. |
| `strategy_risk_lookback_bars` | 256 | D1 close-return window for annualized stop estimate. |
| `strategy_atr_period` | 25 | ATR lookback used to bound stop distance. |
| `strategy_annual_risk_mult` | 0.50 | Multiplier on annualized price standard deviation. |
| `strategy_min_atr_stop_mult` | 2.0 | Minimum stop distance in ATR units. |
| `strategy_max_atr_stop_mult` | 8.0 | Maximum stop distance in ATR units. |
| `strategy_max_hold_bars` | 252 | Time-stop horizon in D1 bars. |
| `strategy_min_history_bars` | 300 | Minimum D1 history before entries. |
| `strategy_spread_median_days` | 60 | D1 spread sample for entry filter. |
| `strategy_spread_mult` | 2.0 | Maximum current spread relative to median spread. |

## 3. Symbol Universe

Registered Q02 basket:

- `EURUSD.DWX`
- `GBPUSD.DWX`
- `USDJPY.DWX`
- `AUDUSD.DWX`
- `USDCAD.DWX`
- `XAUUSD.DWX`
- `NDX.DWX`
- `WS30.DWX`

The basket follows the approved card's DWX-native FX, metal, and index universe and avoids unavailable proxy symbols.

## 4. Timeframe

The strategy is D1-only. `Strategy_NoTradeFilter` blocks non-D1 charts. All signal, stop-sizing, history, and spread-sample reads use bounded D1 windows.

## 5. Expected Behaviour

The EA should place at most one open position per `(symbol, magic)` slot. It should trade infrequently on D1 trend transitions, remain flat until the fast and slow averages cross, and avoid entries when history or quote data are unavailable. It has no grid, martingale, pyramiding, intraday timing layer, ML input, or optimization-dependent parameter switch.

## 6. Source Citation

Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9506_carver-starter.md`.

Source lineage from card frontmatter: Robert Carver, `Leveraged Trading` (Harriman House, 2019), source id `1a059d6d-84fa-5d0c-94c5-86dd0481637c`. The card records G0 approval for deterministic SMA entry/exit with ATR/volatility stop sizing and DWX-testable D1 symbols.

## 7. Risk Model

Backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Position sizing is delegated to the V5 framework. The strategy supplies only direction, reason, magic slot, and initial stop-loss distance; live sizing remains disabled in these artifacts.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-06-27 | Initial build from approved card `QM5_9506_carver-starter`. |
