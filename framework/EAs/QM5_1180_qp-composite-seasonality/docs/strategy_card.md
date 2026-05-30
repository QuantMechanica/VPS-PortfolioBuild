---
ea_id: QM5_1180
slug: qp-composite-seasonality
type: strategy
g0_status: APPROVED
pipeline_phase: G0
card_body_incomplete: true
---

# Quantpedia Composite Seasonal Calendar Strategy

Source: Quantpedia encyclopedia case study, Quantpedia Composite Seasonal Calendar Strategy. Named authors: Radovan Vojtko and Matus Padysak.

## Mechanik

On each completed D1 bar for `SP500.DWX`, build four deterministic calendar signals:

- Turn-of-month: last trading day of the month through first trading day of the next month.
- FOMC: close before scheduled FOMC announcement day through close after the meeting.
- Option-expiration week: Friday before the second Saturday through Thursday of regular monthly option-expiration week.
- Payday: 15th calendar day, or next trading day if the 15th is closed, through next close.

Open one aggregate long position only when any calendar signal is active and completed D1 close is above SMA(200). Do not leverage overlapping signals.

Exit when no calendar signal remains active, when completed D1 close is below SMA(200), or after 10 trading days if the calendar state fails to terminate.

Initial stop is ATR(20) x 2.0 on D1. P3 variant disables ATR stop to test calendar/SMA exit only.

## Position Sizing

- Backtest: `RISK_FIXED=1000`
- Live: `RISK_PERCENT=0.25`

## Live Caveat

`SP500.DWX` is not broker-routable. T6 deploy requires parallel validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
