---
ea_id: QM5_1205
slug: bhatti-gold-vwap-ema
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Bhatti Gold VWAP-EMA Pullback Continuation

Build-local copy of the approved Strategy Card from:
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_1205_bhatti-gold-vwap-ema.md`

## Mechanik

- Symbol: `XAUUSD.DWX`
- Timeframe: M15
- Indicators: session VWAP from daily session open using MT5 tick volume, EMA(50), EMA(200), ATR(14)
- Long regime: close above EMA(200) and above session VWAP
- Short regime: close below EMA(200) and below session VWAP
- Long entry: after price touches or closes within 0.15 ATR of EMA(50), open long on the next M15 open if the bar closes back above EMA(50)
- Short entry: after price touches or closes within 0.15 ATR of EMA(50), open short on the next M15 open if the bar closes back below EMA(50)
- Stop: 1.5 ATR beyond the EMA(50) rejection candle extreme
- Exit: close-based EMA(50) trailing exit
- Filters: skip first 45 minutes of the trading day and high-impact FOMC/CPI/NFP windows via V5 news controls

No backtests or pipeline phases were run for this build.
