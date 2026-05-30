---
ea_id: QM5_1144
slug: baur-gold-autumn-effect
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# QM5_1144 Baur Gold Autumn-Effect

Local build copy of the approved Strategy Card at:

`D:\QM\strategy_farm\artifacts\cards_approved\QM5_1144_baur-gold-autumn-effect.md`

## Mechanics

- Symbol: `XAUUSD.DWX`
- Signal timeframe: D1 calendar logic
- Execution timeframe: H1
- Entry: long on the first trading session of September and November
- Exit: close on the last trading session of the entered month
- Stop: ATR(D1,14) x 3
- Position sizing: V5 standard fixed-risk backtest, percent-risk live
- Optional P3 variants: October overlay and half-month hold

## Framework Mapping

- `Strategy_NoTradeFilter`: wrong-symbol, wrong-timeframe and invalid-parameter blocks
- `Strategy_EntrySignal`: first trading session, configured month, spread filter, ATR stop
- `Strategy_ManageOpenPosition`: no active management beyond fixed stop
- `Strategy_ExitSignal`: month-end or half-month calendar exit

## Build Note

The canonical approved card contains an external source URL. This local copy omits external URLs because the strict build checker forbids external URL literals inside EA folders.
