# QM5_1120 Big Ben London Open Breakout

## Card
- Source card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1120_bigben-london-open-breakout.md`
- Status: G0 APPROVED
- EA ID: 1120
- Slug: `bigben-london-open-breakout`

## Strategy Mapping
- No-Trade: M15 timeframe guard; framework kill-switch, news and Friday close remain active.
- Entry: once per broker day after 07:00, compute M15 Asian range from 00:00 through 07:00 broker time, then place BUY_STOP at range high plus buffer and SELL_STOP at range low minus buffer.
- Management: OCO cleanup deletes the opposite pending order after one side fills.
- Close: cancel unfilled pending orders at 11:00 broker time and flatten open position at 19:00 broker time.

## Card Parameters
- Symbols: `EURUSD.DWX`, `GBPUSD.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`, `EURGBP.DWX`
- Timeframe: M15
- Breakout buffer: 5 points
- Spread cap: 25 points at placement time
- Default SL: opposite Asian range side plus buffer
- Optional SL variant: H1 ATR(14) * 1.0
- Default TP: 2.0R
- News: off by default for P2
- Risk: `RISK_FIXED=1000` for backtest sets, `RISK_PERCENT=0.5` intended for live

## Build Notes
- The folder name follows the card slug requested by the build task even though it exceeds the V5 design note's 32-character compiled-name guidance.
- `ea_id_registry.csv` currently has no exact `1120` row in this workspace; this is a coordination blocker outside the allowed shared write scope.
