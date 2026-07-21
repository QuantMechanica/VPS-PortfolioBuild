---
ea_id: QM5_20029
slug: wti-monfri-daily
strategy_id: GORSKA-KRAWIEC-WTI-CAL-2015_S02
source_id: GORSKA-KRAWIEC-WTI-CAL-2015
status: APPROVED
created: 2026-07-21
created_by: Research+Development
strategy_type_flags: [calendar-seasonality, day-of-week, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
timeframes: [D1]
ml_required: false
g0_status: APPROVED
q01_status: PASS
pipeline_phase: Q02
---
# WTI Monday-Friday Daily Rotation

## Hypothesis

WTI daily returns exhibit a signed weekday contrast: the source reports a
negative Monday mean and positive Friday mean, with their difference
statistically significant at 5%. Trade the two states in one fixed carrier:
short Monday and long Friday, resetting exposure at the next D1 boundary.

## Source citations

- Primary tier A: Gorska and Krawiec (2015), *Calendar Effects in the Market
  of Crude Oil*, Problems of World Agriculture 15(4), 62-70,
  DOI 10.22630/PRS.2015.15.4.54, Tables 1-2 and concluding remarks.
- Full text: https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf
- Source location: Table 1 reports WTI Monday mean -0.000943 and Friday mean
  0.001731; Table 2 reports Monday-Friday z=-2.3617 (5% rejection).

## Rules and parameters

- On a new broker-calendar Monday D1 bar, SELL XTIUSD.DWX once.
- On a new broker-calendar Friday D1 bar, BUY XTIUSD.DWX once.
- Consume the day's attempt before entry gates; never retry a rejected signal.
- Close at the next D1 boundary or after one stale calendar day. The retained
  framework Friday-close rule flattens the Friday leg at 21:00 broker time.
- ATR(20) stop at 2.75 ATR and 2500-point spread cap.
- RISK_FIXED=1000, RISK_PERCENT=0, portfolio weight 1. No parameter sweep.
- No TP, trailing, scale, grid, martingale, ML, or external runtime feed.

## Author claims

The source concludes that its equality-of-means tests show traditional Monday
and Friday effects in oil returns. No performance claim is imported: Q02 must
judge the fixed rule on Darwinex XTIUSD.DWX history.

## Risk

Main risks are post-publication decay, spot/CFD versus source-benchmark basis,
broker calendar/session mapping, Friday truncation, gaps, and repeated weekly
exposure. Q02 must reject on governed cadence, PF, drawdown, or determinism.

## Non-duplicate and framework alignment

Existing `QM5_12596` and `QM5_12597` isolate one side apiece. This is a new
single signed two-state carrier whose hypothesis and risk stream are the
source-tested Monday-Friday contrast, analogous to the repository's approved
signed February/October carrier but operating on weekday state. It is not an
event, inventory, trend, ratio, RSI, or month-of-year strategy.

- no_trade: lock XTIUSD.DWX/D1/slot and source-fixed parameters.
- trade_entry: Monday short or Friday long on the new D1 bar.
- trade_management: close at the following D1 boundary or stale-day guard.
- trade_close: ATR hard stop, strategy time exit, and Friday framework close.

## Safety

Q02 only. No live set, AutoTrading, T_Live, deploy manifest, or portfolio-gate
change is authorized.
