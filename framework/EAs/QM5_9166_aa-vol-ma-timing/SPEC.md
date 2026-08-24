# QM5_9166_aa-vol-ma-timing — Strategy Spec

**EA ID:** QM5_9166

**Slug:** `aa-vol-ma-timing`

**Approved card:** `docs/strategy_card.md`

**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`

**Last revised:** 2026-08-24

## 1. Strategy Logic

At the first available D1 bar of each calendar month, the EA builds one
restart-stable snapshot as of the start of that month. It calculates the
annualized sample standard deviation of 252 completed D1 log returns for the
13-symbol registered basket, ranks available symbols from highest to lowest
volatility, and seals the host symbol's membership for the month. Ties resolve
by ascending registry slot.

For at least 10 available instruments, the highest `ceil(N * 20%)` form the
active quintile. With 3–9 available instruments, the card's fallback selects
the top three. Fewer than three complete volatility histories fail closed.

For the host symbol, the EA derives the last 10 completed month-end closes from
bounded D1 history (DWX monthly bars are not a reliable tester contract). Their
arithmetic mean is `SMA10M`; the most recent observation is the completed
monthly close. A selected symbol enters long when that close is above `SMA10M`.
The default is long/cash; the declared optional short input enables the
symmetrical below-SMA short variant. A position exits when the host leaves the
sealed high-volatility sleeve or the monthly close crosses to the flat side of
`SMA10M`.

Each entry carries the card's 3.0 × ATR(20, D1) catastrophic stop. There is no
trailing stop, break-even move, partial close, pyramiding, grid, martingale, or
ML mechanism.

## 2. Parameters

| Input | Default | Contract |
|---|---:|---|
| `strategy_sma_months` | 10 | Number of exact completed month-end closes averaged for `SMA10M`. |
| `strategy_vol_lookback_days` | 252 | Completed D1 log returns used for every basket member's realized volatility. |
| `strategy_atr_period` | 20 | Closed-D1 ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 3.0 | Catastrophic-stop ATR multiple. |
| `strategy_min_warmup_bars` | 252 | Lower bound on bounded basket-history warmup and month-end scan. |
| `strategy_enable_shorts` | false | Optional symmetric short variant; false preserves the approved long/cash default. |

All framework inputs are passed through `QM_FrameworkInit`. Backtest setfiles
keep `RISK_FIXED=1000`, `RISK_PERCENT=0`; live packaging must instead use
`RISK_PERCENT` with `RISK_FIXED=0`.

## 3. Symbol Universe

The slot-ordered basket is:

1. `GDAXI.DWX`
2. `NDX.DWX`
3. `SP500.DWX`
4. `UK100.DWX`
5. `WS30.DWX`
6. `XAUUSD.DWX`
7. `EURUSD.DWX`
8. `GBPUSD.DWX`
9. `USDJPY.DWX`
10. `USDCHF.DWX`
11. `AUDUSD.DWX`
12. `USDCAD.DWX`
13. `NZDUSD.DWX`

The order matches `magic_numbers.csv`, canonical setfiles, and
`basket_manifest.json`. Each instance trades only `_Symbol` through its
MagicResolver slot. Foreign-symbol reads are limited to a guarded, bounded
monthly volatility snapshot after `QM_SymbolGuardInit` and
`QM_BasketWarmupHistory`; no foreign symbol is traded.

`SP500.DWX` remains backtest-only. The card's T6 parallel-validation condition
for `NDX.DWX` or `WS30.DWX` remains unchanged and is outside this build task.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Cross-symbol data | Completed `D1` bars only, bounded to the monthly snapshot. |
| Rebalance key | `QM_CalendarPeriodKey(PERIOD_MN1)` derived from reliable D1 dates. |
| Entry retry cadence | At most once per new D1 bar while the sealed monthly opportunity remains unfilled. |
| Exit cadence | Every tick while the sealed monthly exit condition and position persist. |

## 5. Expected Behaviour

- The basket snapshot is sealed once per month and is identical after restart
  because every input window ends at the prior month's final second.
- Only the highest-volatility quintile (or the documented top-three fallback)
  may enter; a sleeve leaving that set exits.
- The source-faithful default is long/cash, with a small number of monthly
  decisions per symbol and potentially multi-month holds.
- Invalid basket, month-end, history, price, or spread evidence fails closed.
- Trending high-volatility regimes are preferred; choppy regimes can generate
  ATR stop-outs and monthly MA whipsaws.

## 6. Source Citation

Wesley Gray, PhD, “Technical Analysis may actually work!”, Alpha Architect,
2011-05-02, source ID `ede348b4-0fa7-5be1-baa8-09e9089b67b7`. The approved
card records R1–R4 as PASS and remains the strategy authority.

## 7. Risk Model

`RISK_FIXED` and `RISK_PERCENT` are basket budgets, not per-sleeve budgets. The
entry path uses the framework's explicit risk-mode overload with
`basket_budget / sealed_active_sleeve_count`; the framework then applies
`PORTFOLIO_WEIGHT`. Thus aggregate requested risk is at most
`basket_budget * PORTFOLIO_WEIGHT`, split equally across selected sleeves.

### Entry and exit safety

- Wrong chart timeframe, invalid parameters, or slot/symbol mismatch fails
  `OnInit`.
- Entry news and spread filters run only after management and strategy exits.
- The 20-day spread guard requires exactly 20 positive completed-D1 spread
  observations, a positive bid/ask ordering, and a positive median.
- A monthly entry is consumed only by a confirmed `DEAL_ENTRY_IN/INOUT` in MT5
  history. Broker, stress, governor, or risk rejection leaves the opportunity
  eligible for the next D1 attempt; restart cannot create a second monthly
  entry after a confirmed fill.
- Exit remains requested on every tick while the position and exit condition
  persist, so a rejected close is retried until the position is flat.

## 8. Framework Alignment

| Card / V5 requirement | Implementation |
|---|---|
| Cross-sectional high-volatility quintile | `Strategy_BuildMonthlySnapshot` |
| Exact 10 completed month-end SMA | `Strategy_ReadCompletedMonthEnds` |
| Entry | `Strategy_EntrySignal` |
| Trade management / snapshot refresh | `Strategy_ManageOpenPosition` |
| MA or sleeve-removal exit | `Strategy_ExitSignal` |
| Equal basket-risk distribution | `Strategy_OpenWithDistributedRisk` |
| Magic allocation | `QM_FrameworkMagic()` / `QM_MagicResolver.mqh` include chain |
| MAE | `QM_FrameworkTrackOpenPositionMae()` first in `OnTick` |
| News and Friday close | `QM_NewsAllowsTrade2` and `QM_FrameworkHandleFridayClose` |

## 9. Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-22 | Initial per-symbol draft. |
| v2 | 2026-08-24 | Review rework: true cross-sectional selection, exact month-end SMA, distributed risk, confirmed-entry state, independent exits, and fail-closed spread evidence. |
