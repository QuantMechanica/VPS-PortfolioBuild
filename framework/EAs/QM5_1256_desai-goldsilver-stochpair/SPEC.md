# QM5_1256 Desai Gold/Silver Stochastic Pair

## Card
- `ea_id`: 1256
- `slug`: desai-goldsilver-stochpair
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1256_desai-goldsilver-stochpair.md`
- Status: APPROVED / G0

## Framework Alignment
- No-Trade: allows only `XAUUSD.DWX` or `XAGUSD.DWX` H1 charts, valid parameters, framework news, Friday close and kill switch.
- Entry: requires 60 trading-day proxy correlation (`1440` H1 return bars) above `0.90`, computes gold/silver ratio, then opens long-gold/short-silver on `%K` re-entry above `20`, or short-gold/long-silver on `%K` re-entry below `80`.
- Management: no trailing overlay; pair is managed by paired exit and stop conditions.
- Close: closes both legs on stochastic midline cross, adverse z-score move of `2.5`, emergency combined loss of `1.5R`, or 10 trading-day proxy time stop (`240` H1 bars).

## Symbols And Magic
- Slot 0: `XAUUSD.DWX`, magic `12560000`
- Slot 1: `XAGUSD.DWX`, magic `12560001`

## Notes
- Pair legs are opened manually with `OrderSend` and `QM_MagicChecked`, because the V5 single-entry request represents only one symbol at a time.
- Volatility-balanced sizing uses recent H1 return volatility to split fixed combined risk across both legs.
- No backtests or pipeline phases were run during build.
