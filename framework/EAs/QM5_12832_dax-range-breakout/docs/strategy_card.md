---
ea_id: QM5_12832
slug: dax-range-breakout
type: strategy
source_id: balke-range-breakout-dax-transfer-20260630
sources:
  - "[[docs/research/BALKE_RANGE_BREAKOUT_QM5_12700_2026-06-27]]"
concepts:
  - "[[concepts/range-breakout]]"
  - "[[concepts/session-opening-range]]"
indicators:
  - "[[indicators/session-range-high-low]]"
  - "[[indicators/daily-atr-band]]"
period: M15
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Direct asset-class transfer of QM5_12700 (René Balke range-breakout), which is an OOS-validated net-of-cost edge on USDJPY (PF 1.19 / Sharpe 1.84 / MaxDD 2.38% over 7yr). Source = the proven 12700 mechanic + the Balke method. R1 author-agnostic (2026-06-30)."
r2_mechanical: PASS
r2_reasoning: "Fully deterministic: build the session range (High/Low over a fixed window), enter on a completed-bar close beyond the range with a range-floor vs daily-ATR filter + volume surge + spread cap, SL = opposite range edge, fixed RR target, fixed exit hour, one trade/day. No ML, closed-bar signal."
r3_data_available: PASS
r3_reasoning: "GDAXI.DWX M15 history present (index in the .DWX set; live_commission index class). Needs only price + daily ATR."
r4_ml_forbidden: PASS
r4_reasoning: "No ML. Single-position-per-magic, no grid/martingale. Pure range-breakout."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
expected_pf: 1.20
expected_dd_pct: 6
last_updated: 2026-06-30
g0_approval_reasoning: "G0 2026-06-30 Claude. OWNER task #17: transfer the proven 12700 Balke range-breakout to DAX. WHY DAX: (1) index commission (~$4.4 RT) is LOWER than the FX $5 that 12700 had to fight -> net-of-cost is more forgiving; (2) GDAXI gives asset-class breadth + likely low corr to the USDJPY 12700 sleeve. The 12700 mechanic is cost-robust (fewer/bigger trades); the open question is the DAX-specific RANGE SESSION + exit, which is the sweep."
---

# QM5_12832 — DAX Range Breakout (12700/Balke transfer to GDAXI)

## Source & basis
Fork of **QM5_12700** (`framework/EAs/QM5_12700_balke-range-breakout/`), the OOS-validated Balke
range-breakout (USDJPY, net PF 1.19 / Sharpe 1.84 / MaxDD 2.38% / 7yr). Full derivation:
`docs/research/BALKE_RANGE_BREAKOUT_QM5_12700_2026-06-27.md`. THIS card = the GDAXI transfer.

## The mechanic (identical to 12700 — do not change the core)
- Build the **session range** (High/Low) over a fixed window; on a **completed-bar close beyond**
  the range edge → enter in that direction. **SL = opposite range edge.** Fixed **RR target** (start
  RR 2.5). **One trade/day.** Single-position-per-magic. Server time.
- **Filters (keep all from 12700):** range-size floor vs **daily ATR** (start 0.60×ATR — the key
  cost-robustness lever: bigger range → wider stop → fewer lots → less commission + bigger moves),
  **volume surge** (1.5×), **spread cap**, optional entry buffer.
- **Fixed exit hour** (flatten if still open).

## DAX adaptation ([DESIGN] — the sweep)
DAX is a European cash index (Frankfurt 09:00–17:30), not a 24h FX pair, so the range session +
exit differ from USDJPY's 03–06/20:00. Build the EA with these as **parameters** and sweep:
- **Range window candidates:** (a) **overnight/pre-open** (e.g. 22:00→08:00 broker) broken at the
  09:00 cash open; (b) **opening-range** (first 15–30 min after the open). Start with (a).
- **Exit hour candidates:** before the cash close (~17:00–17:30 broker). Start 17:00.
- **RR / range-floor:** start from 12700's vB (RR 2.5, floor 0.60×ATR), then sweep ±.

## Build notes (Codex)
- **Fork** `framework/EAs/QM5_12700_balke-range-breakout` → `QM5_12832_dax-range-breakout`.
- Re-point to **GDAXI.DWX**, expose the range-window + exit-hour as inputs (defaults = overnight
  22:00–08:00 range, breakout-at-open, exit 17:00), keep RR 2.5 / floor 0.60×ATR / vol 1.5×.
- Recompile **against the current resolver** (avoid the stale-resolver magic-spam log-bomb).
- RISK_FIXED backtest / RISK_PERCENT live; news-blackout on; no ML.

## Acceptance
Q02 → **Q04 net-of-cost (decisive; index commission ~$4.4 RT is gentler than 12700's FX $5)** →
Q05–Q08. If it clears, it's a **GDAXI sleeve** with asset-class breadth + likely low corr to the
USDJPY 12700 sleeve. Sweep the DAX range-window/exit/RR; pick the OOS-robust config (not in-sample
best — 12700 lesson: the simpler config generalized, the over-tuned one collapsed OOS).
