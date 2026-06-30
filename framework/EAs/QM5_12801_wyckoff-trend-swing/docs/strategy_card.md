---
ea_id: QM5_12801
slug: wyckoff-trend-swing
type: strategy
source_id: hyonix-wyckoff-trend-swing-2026
sources:
  - "[[sources/hyonix-wyckoff-trend-swing]]"
  - "[[sources/wyckoff-method]]"
concepts:
  - "[[concepts/wyckoff-phases]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/volume-confirmation]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/volume]]"
  - "[[indicators/support-resistance]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "From OWNER's Hyonix collection. The most mechanical EA of the Hyonix 'other-EA' batch (agent-D triage: volume+trend+ATR, quant-friendly Wyckoff phase logic, not pattern-art). Wyckoff = reputable published method. R1-R4 waived for discovery."
r2_mechanical: PASS
r2_reasoning: "Deterministic: algorithmic Wyckoff phase detection (accumulation/distribution) + S/R levels + volume-spike confirmation + trend-strength gate; ATR-based SL; partial close at 1.5R; volatility filter. Closed-bar H4. No discretion (per source triage)."
r3_data_available: PASS
r3_reasoning: ".DWX H4 history for indices/gold; ATR + volume + S/R only."
r4_ml_forbidden: PASS
r4_reasoning: "CLEAN (Hyonix triage): ATR-based SL, partial close, volume threshold, volatility filter, NO martingale. No ML."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
expected_pf: 1.30
expected_dd_pct: 12
last_updated: 2026-06-29
g0_approval_reasoning: "G0 2026-06-29 Claude, OWNER 'alles selbst bauen'. The most mechanical of the Hyonix non-breakout EAs (agent-D: volume+trend+ATR Wyckoff phases = quant-friendly, clean, no martingale). H4 swing trend = a different cadence/edge from the intraday breakout lanes -> diversifier. Per cost model target indices/gold. Decisive gates: Q04 net-of-cost + Q08."
---

# Wyckoff Trend Swing (Hyonix -> V5 port)

## Purpose
Port the most mechanical of the Hyonix non-breakout EAs: a Wyckoff-phase trend swing
(volume + trend + ATR). H4 swing cadence -> diversifies the intraday breakout lanes.

## Source
`C:/Users/Administrator/Downloads/Hyonix/Hyonix/WyckoffTrendSwing.mq5`. Hyonix triage: MED-HIGH,
most mechanical of the batch, CLEAN (ATR SL, partial close, volume + volatility filters, no martingale).

## Strategy (build spec)
- **Phase detection:** algorithmic Wyckoff accumulation/distribution (price structure + volume).
- **Entry:** in detected trend/phase direction, at S/R level + volume-spike confirmation +
  trend-strength gate.
- **Stop:** ATR-based SL. **Target:** partial close at 1.5R, runner with ATR trail.
- **Filter:** volatility filter (skip disaster regimes). TF H4. ~30 trades/yr (swing).

## Required (V5)
Single-position-per-magic, magic = ea_id*10000+slot, RISK_FIXED backtest / RISK_PERCENT live,
QM_KillSwitch (3% daily), QM_NewsFilter (DL-080), QM_RiskSizer/QM_Logger, closed-bar H4.
Re-mechanize logic into a V5 card (don't lift the raw .mq5 indicator handles blindly).

## Instruments
Indices (NDX/GER40/US500) + gold (XAUUSD) first (low-commission, trend-friendly on H4).

## Acceptance
Q02 + low-freq trade floor -> Q04 net-of-cost -> Q08. Value = an H4 volume/trend swing diversifier
(different cadence from the intraday breakout sleeves + the D1 trend). Anti-correlation check at admission.
