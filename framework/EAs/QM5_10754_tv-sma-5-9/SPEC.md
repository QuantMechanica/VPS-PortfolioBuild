# QM5_10754_tv-sma-5-9 - Strategy Spec

**EA ID:** QM5_10754
**Slug:** tv-sma-5-9
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the TradingView SMA 5/9 crossover on closed M15 bars. A long entry is opened when SMA(5) crosses above SMA(9); a short entry is opened when SMA(5) crosses below SMA(9). The stop is the lowest low or highest high of the previous 5 completed candles, rejected if it is below broker minimum distance or wider than 3 * ATR(14), and the target is fixed at 2R. Any open trade is closed early when the opposite SMA(5/9) cross appears before TP or SL.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_M15` | M1-MN1 | Base timeframe for SMA cross, structure stop, and ATR cap. |
| `strategy_fast_sma_period` | `5` | `>=1` | Fast SMA period for crossover detection. |
| `strategy_slow_sma_period` | `9` | `> strategy_fast_sma_period` | Slow SMA period for crossover detection. |
| `strategy_structure_lookback` | `5` | `>=1` | Completed candles used for lowest-low / highest-high structure stop. |
| `strategy_atr_period` | `14` | `>=1` | ATR period used to cap outsized structure stops. |
| `strategy_max_stop_atr_mult` | `3.0` | `>0` | Maximum allowed stop distance as ATR multiple. |
| `strategy_take_profit_rr` | `2.0` | `>0` | Reward/risk multiple for TP placement. |
| `strategy_use_sma200_filter` | `false` | `true/false` | Optional P3 trend-context gate from the card. |
| `strategy_context_sma_period` | `200` | `>=1` | SMA period used when the optional trend gate is enabled. |
| `strategy_max_spread_points` | `0` | `>=0` | Optional spread ceiling; `0` disables this card-neutral guard. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - R3 forex basket member with SMA/OHLC data available.
- `GBPUSD.DWX` - R3 forex basket member with SMA/OHLC data available.
- `USDJPY.DWX` - R3 forex basket member with SMA/OHLC data available.
- `XAUUSD.DWX` - R3 metal basket member; card text used `XAUUSD`, mapped to canonical matrix symbol.
- `GDAXI.DWX` - DAX exposure; card text used unavailable `GER40.DWX`, mapped to the matrix DAX symbol.
- `NDX.DWX` - R3 index basket member with SMA/OHLC data available.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants and not part of this card basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday to multi-bar M15 holds until 2R target, structure stop, or opposite SMA cross. |
| Expected drawdown profile | High trade density with whipsaw risk in sideways markets. |
| Regime preference | Trend-following / short moving-average momentum. |
| Win rate target (qualitative) | Medium; fixed 2R target allows lower hit rate if trend legs persist. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `SMA Strategy`, author handle `ColasBreugnon`, https://www.tradingview.com/script/86RaWbno/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10754_tv-sma-5-9.md`

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
| v1 | 2026-05-31 | Initial build from card | aa7b9680-0431-4260-bd0c-d128c6b01936 |
