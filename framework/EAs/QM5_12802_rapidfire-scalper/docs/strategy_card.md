---
ea_id: QM5_12802
slug: rapidfire-scalper
type: strategy
source_id: hyonix-rapidfire-scalper-2026
sources:
  - "[[sources/hyonix-scalping-robot-2.0]]"
concepts:
  - "[[concepts/intraday-trend-scalp]]"
  - "[[concepts/eod-flat-no-swap]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/parabolic-sar]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "From OWNER's Hyonix collection ('Scalping Robot 2.0'/RapidFireScalper). Source-verified CLEAN by the Hyonix 5-agent audit. R1-R4 waived for discovery; this is a code-sharer build, not an edge claim."
r2_mechanical: PASS
r2_reasoning: "Deterministic M5 trend-stack: on new M5 bar, BUY if Ask>SMA(60) AND Ask>SAR (mirror SELL); hard SL+TP (or %-of-price profile for gold) + trailing. Session-gated. Closed-bar via IsNewBar. No discretion."
r3_data_available: PASS
r3_reasoning: ".DWX M5 history for gold/indices; SMA+SAR+ATR only."
r4_ml_forbidden: PASS
r4_reasoning: "CLEAN (Hyonix teardown): calcLots = risk% off SL distance (no loss-scaling), no martingale/grid/averaging, hard SL on every order. No ML. Port = single-position (drop hedging) + EOD-flat (minimal swap)."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 300
expected_pf: 1.20
expected_dd_pct: 10
last_updated: 2026-06-29
g0_approval_reasoning: "G0 2026-06-29 Claude, OWNER 'alles selbst bauen'. The one immediately-usable clean higher-cadence candidate from the Hyonix scalper batch. M5 SMA+SAR trend scalp -> fits the high-freq need, BUT only on LOW-COMMISSION instruments (gold/indices): the forex 1:1-RR 20-pip profile dies on ~$45/RT commission (REJECT FX). Edge is THIN (SMA+SAR/1:1) -> must earn through Q04/Q08, not assumed. Port fixes from the source teardown: single-position (drop hedging), magic 666->V5 registry, RISK_FIXED backtest, news filter, fix the CloseAllOrders non-flatten bug."
---

# RapidFire Scalper (Hyonix -> V5 port)

## Purpose
Port the one clean higher-cadence scalper from OWNER's Hyonix collection: M5 SMA+SAR trend
scalp. Higher frequency = fills the VaR budget, BUT only viable on low-commission gold/indices.

## Source
`C:/Users/Administrator/Downloads/Hyonix/Hyonix/RapidFireScalper.mq5` (+ scalpgold.set/scalpforex.set).
Hyonix teardown verdict: CLEAN (fixed-% risk, hard SL, no martingale/grid).

## Strategy (build spec)
- **TF:** M5, evaluate on new bar. **Signal:** SMA(60) + Parabolic SAR(0.2/0.2) trend-stack —
  BUY if Ask>SMA AND Ask>SAR; SELL if Bid<SMA AND Bid<SAR.
- **Stop/target:** hard SL + TP. Two profiles: fixed-points (indices) or %-of-price (gold,
  SType=1, 0.4%/0.4%). Trailing optional (fixed / prev-candle / fast-MA).
- **Session gate** + force-flat EOD (minimal swap). One position (drop the original's hedging).
- **Cadence:** ~few/day/symbol intraday.

## Required (V5)
Single-position-per-magic (remove hedging), magic = ea_id*10000+slot (replace 666), RISK_FIXED
backtest / RISK_PERCENT live, QM_KillSwitch (3% daily), QM_NewsFilter (DL-080), QM_Logger.
Fix the source's CloseAllOrders bug (it only deletes pending orders, not open positions).

## Instruments
**GOLD (XAUUSD, %-profile) + INDICES (NDX/GER40/US500/US30)** only. REJECT FX (commission-killed).

## Acceptance
Q02 + intraday trade floor -> Q04 net-of-cost (decisive — the SMA+SAR/1:1 edge is thin) -> Q08.
Realistic: may well fail Q04; port it to let the gate rule. If it survives, it's an intraday
gold/index sleeve that fills the VaR budget.
