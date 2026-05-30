# QM5_1246_miffre-comm-mom SPEC

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1246_miffre-comm-mom.md`
- Source concept: Miffre-Rallis commodity cross-sectional momentum
- Scope: V5 build only; no pipeline phase or backtest executed.

## Universe

The EA trades the approved DWX commodity mini-basket:

- `XAUUSD.DWX`
- `XAGUSD.DWX`
- `XTIUSD.DWX`

Each chart instance uses its own magic slot for the active symbol.

## Entry

On the first tradable D1 bar of each rebalance period, the EA computes trailing daily close return over `strategy_formation_months * 21` bars for every basket member.

- Long the highest-ranked symbol when its trailing return is positive.
- Short the lowest-ranked symbol when its trailing return is negative.
- Stay flat if fewer than two symbols have valid data, if top and bottom collapse to the same symbol, or if the current chart symbol is not an active top/bottom candidate.

Default formation window is six months. P3 sweeps can use 3, 6, or 12 months and monthly or quarterly rebalancing.

## Exit

On rebalance, close any open position if:

- the symbol no longer has the desired top/bottom rank, or
- its desired direction crosses to flat/opposite.

The hard stop handles intra-period adverse movement.

## Risk And Stops

- Backtest default: `RISK_FIXED=1000`
- Live convention: `RISK_PERCENT=0.25`
- `PORTFOLIO_WEIGHT=0.3333`
- Hard stop: `strategy_atr_sl_mult * ATR(D1, strategy_atr_period_d1)`, default `3.0 * ATR(20)`.
- No averaging down, no pyramiding, no trailing, no partial close.

## Framework Alignment

- No-Trade: D1-only, approved basket only, approved parameter domain, minimum history, valid ATR settings.
- Entry: monthly/quarterly closed-bar ranking signal plus spread guard.
- Management: no discretionary management beyond initial hard ATR stop.
- Close: rebalance and zero/opposite-return rank exit.

## Notes

The approved source URL is kept in the original card. The local EA card copy is URL-sanitized to satisfy the repository build check's external URL scan.
