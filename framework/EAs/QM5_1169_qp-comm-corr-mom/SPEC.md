# QM5_1169 qp-comm-corr-mom

## Strategy

Approved Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1169_qp-comm-corr-mom.md`

Quantpedia commodity momentum with an intra-market correlation filter. The EA trades the four-symbol DWX commodity universe on D1 and evaluates entries only on month-end closed bars. If the 20-day average pairwise return correlation is greater than the 250-day average pairwise return correlation, it ranks the universe by 12-month return and opens long positions in the top-ranked symbols and short positions in the bottom-ranked symbols. Positions are closed and rebalanced at the next month-end.

## Framework Alignment

- No-Trade: V5 framework guards plus D1 timeframe, universe-symbol, parameter, and history checks.
- Entry: month-end closed-bar gate, no existing position for the current magic, spread filter, 20d > 250d average pairwise correlation filter, 12-month return rank, ATR stop validation.
- Management: no trailing, break-even, or partial close; the card specifies a hard ATR stop and monthly rebalance.
- Close: month-end rebalance exit closes open positions; if the correlation filter is false on the next entry evaluation, no new position is opened.
- Risk: V5 standard `RISK_FIXED=1000` for backtest and `RISK_PERCENT=0.25` for live setfiles.
- Magic: `ea_id=1169`, slots `0..3` for `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, `XNGUSD.DWX`.

## Parameters

- `strategy_momentum_lookback_d1_bars`: default `252`.
- `strategy_short_corr_d1_bars`: default `20`.
- `strategy_long_corr_d1_bars`: default `250`.
- `strategy_min_history_d1_bars`: default `270`.
- `strategy_rank_slots_each_side`: default `2`.
- `strategy_atr_period`: default `20`.
- `strategy_atr_sl_mult`: default `5.0`.
- `strategy_spread_median_days`: default `20`.
- `strategy_spread_mult`: default `3.0`.

## Notes

The approved card is marked body-incomplete in metadata, but it contains enough mechanical rules for the V5 build: target symbols, monthly rebalance, correlation windows, 12-month rank, ATR stop, history gate, and spread gate. No external data source or pipeline phase is used by this EA build.
