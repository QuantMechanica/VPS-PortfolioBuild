# QM5_1023_chan-at-bb-pair - Strategy Spec

**EA ID:** QM5_1023
**Slug:** `chan-at-bb-pair`
**Source:** `SRC05_S01`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements the approved Chan AT Bollinger-band pair-spread card as a
low-frequency market-neutral commodity basket on `XTIUSD.DWX` and
`XAUUSD.DWX`. It maps Chan's USO/GLD example to the Darwinex WTI and gold CFDs,
then evaluates the D1 price spread:

`spread = XTIUSD - beta * XAUUSD`

`beta` is recomputed daily from a rolling 20-bar OLS regression of oil on gold.
The spread is converted to a rolling z-score over the same lookback. A negative
z-score below -1.0 opens the long-spread package: buy oil and sell beta-scaled
gold. A positive z-score above +1.0 opens the short-spread package: sell oil and
buy beta-scaled gold. Both legs close when the spread reverts to the mean
(`exit_z = 0.0` by default).

The hedge ratio used for order sizing is frozen at entry. Daily OLS updates are
used for signal and exit evaluation only, matching the card's reading of Chan's
implementation.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1` | 20 | 10-50 | D1 bars for rolling OLS and spread z-score |
| `strategy_entry_z` | 1.0 | 0.75-2.0 | Absolute z-score entry threshold |
| `strategy_exit_z` | 0.0 | 0.0-0.75 | Mean-reversion exit band |
| `strategy_min_hedge_ratio` | 0.001 | 0.001-0.05 | Minimum valid rolling OLS hedge ratio |
| `strategy_max_hedge_ratio` | 2.0 | 0.5-5.0 | Maximum valid rolling OLS hedge ratio |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR period used only for RISK_FIXED lot sizing |
| `strategy_atr_sizing_mult` | 3.0 | 2.0-5.0 | Volatility budget multiplier for lot sizing |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | XAU entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |
| `strategy_entry_hour_broker` | 2 | 0-23 | Earliest broker hour to attempt the daily basket entry |
| `strategy_entry_minute_broker` | 0 | 0-59 | Earliest broker minute to attempt the daily basket entry |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and oil spread leg, magic slot 0.
- `XAUUSD.DWX` - gold hedge leg, magic slot 1.
- Logical basket symbol: `QM5_1023_XTI_XAU_BBPAIR_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: D1 state refresh on `QM_IsNewBar()`; entry can be delayed until
  the configured broker entry time and both legs are tradable.

## 5. Expected Behaviour

- Expected spread packages/year: about 20-50 in the original ETF example; the
  Darwinex CFD mapping may be lower after costs and Friday flattening.
- Typical hold: days to weeks.
- Regime preference: short-term oil/gold spread dislocations.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Ernest P. Chan, *Algorithmic Trading: Winning Strategies and Their Rationale*
(Wiley, 2013), Chapter 3, Example 3.2 "Bollinger Band Mean Reversion
Strategy", with rolling OLS hedge-ratio precondition from Example 3.1.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

The card specifies no native stop-loss for this mean-reversion construction.
This implementation therefore uses ATR only to convert the fixed risk budget
into stable leg lots and sends both legs without broker stop-loss orders. The V5
kill switch and standard account-level controls remain the catastrophic backstop.

No live manifest or `T_Live` file is touched by this build.
