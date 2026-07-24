# STR-069 — Claude independent spec (pre-reconciliation)

Source: thread 535657 (Nik13, ~2015). Exec TF H1. BASKET CLASS: the
source trades EURUSD and GBPUSD SIMULTANEOUSLY with a coupled equity
close — one EA, host chart EURUSD.DWX, slots 0 (EURUSD) + 1 (GBPUSD);
host_symbol REQUIRED (basket recipe).

## Rules

1. At the close of the FIRST H1 candle of the broker day: for EACH of the
   two symbols independently — close above that symbol's daily open → BUY
   that symbol; below → SELL (both trades opened at the same evaluation;
   equality → skip that symbol).
2. Per-position SL 10 pips / TP 10 pips (server-side).
3. **Equity close (the source's "additional option", prior build dropped
   it):** while BOTH positions are open, if the combined floating profit
   reaches the pip-value equivalent of +20 pips (both at +10 "in a row" =
   simultaneously), close both at market. Mechanization flagged (Equity
   Sentry semantics); evaluated per tick with a once-latch.
4. One evaluation per day; positions not force-closed at day end (source
   silent; SL/TP/equity close are the exits; Friday close applies).
5. One campaign per symbol per day.

## Inputs

```
strategy_sl_pips        = 10.0
strategy_tp_pips        = 10.0
strategy_basket_tp_pips = 20.0   // combined-floating close (flagged mechanization)
```

## Hooks sketch

Filter: H1/params/warmup ≥ 2 days. Entry: first-H1-close evaluation (own
day latch; TWO requests via the two-phase pattern — slot 0 then slot 1
with per-symbol direction). Manage: basket equity close (combined
floating pips of own positions ≥ basket_tp → close all; per-tick,
retry-latched). Exit: false. News: default.

## Notes

- Prior build QM5_10049 removed the basket coupling and added per-symbol
  EOD exit + spread gate (G0_REVIEW_T6) → outcomes not transferable.
- Basket-class build: host_symbol in card/sets (Q08 requirement);
  cross-symbol pip aggregation uses per-symbol pip values.
- 10-pip targets on two majors → high fill frequency (~250 eval days,
  most with 2 fills) — churn judged by Q02.
