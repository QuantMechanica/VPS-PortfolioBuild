---
ea_id: QM5_12846
slug: euro-night-mr-eurusd
type: strategy
source_id: davey-euro-night-mr-20260630
sources:
  - "[[docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/overnight-session]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/rolling-high-low-mean]]"
period: H1
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Overnight-session mean-reversion (low-liquidity extremes exhaust and snap back rather than trend) is a documented FX regularity; Davey's Euro Night template. Surfaced via the Davey synthesis (agy video, Claude synthesis 2026-06-30). R1 author-agnostic — the session-liquidity thesis is public."
r2_mechanical: PASS
r2_reasoning: "Deterministic: limit orders at avg(High,X) - Y*ATR(Z) (buy) / avg(Low,X) + Y*ATR(Z) (sell), symmetric; hard SL; TP fixed; new entries only inside a session window, hard time-exit at session end. Single-position-per-magic, closed-bar limit logic. No ML, no grid. (X/Y/Z + TP are the calibration DOF.)"
r3_data_available: PASS
r3_reasoning: "EURUSD.DWX H1 history 2017-2026 present on T1-T5. Needs price + ATR + rolling High/Low mean."
r4_ml_forbidden: PASS
r4_reasoning: "No ML. Single-position-per-magic, no grid/martingale, no averaging-down. Pure limit-MR rule."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
expected_pf: 1.20
expected_dd_pct: 7
last_updated: 2026-07-01
g0_approval_reasoning: "G0 2026-07-01 Claude. Davey Euro Night + OWNER 'card the slate'. Mean-reversion on overnight FX is STYLISTICALLY orthogonal to our breakout/trend book -> good diversification. BUT it lives in the same cost-danger zone as pre-optimization 12700 (medium-freq FX, ~$45 RT commission is the HIGH class) -> MUST be built with the 12700 cost-discipline baked in (widen the limit distance Y to cut frequency and lift per-trade size). Explicitly needs-design + cost-gated; Q04 net-of-cost is the acid test."
---

# QM5_12846 — Euro Night MR (EURUSD overnight mean-reversion)

## Source & basis
Davey Euro Night template, synthesis candidate **B2**
(`docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md`). The book's first **mean-reversion
on FX** — diversifying, but the highest cost-risk of the slate. Read alongside the commission
model (FX ~$45 RT HIGH) and the 12700 cost-robustness lesson.

## The mechanic
- **Entry (limit orders, symmetric):** buy-limit = `avg(High, X bars) − Y·ATR(Z)`;
  sell-limit = `avg(Low, X bars) + Y·ATR(Z)`. New entries only **inside the overnight window**
  (Davey: ~18:00→01:00 ET entries).
- **Exit:** hard **SL** (fixed % / ATR-scaled); fixed **TP** (calibrate via one-shot WFA);
  **hard time-exit at session end** (~07:00 ET). Single-position-per-magic.

## ⚠️ COST DISCIPLINE (binding — this is why it's gated)
Medium-freq FX dies on commission (the whole reason 12700 was engineered to trade fewer,
bigger, cost-robust trades). **Bake the fix into the defaults:** widen `Y` (deeper limit →
fewer, higher-conviction fills → bigger per-trade size → commission a smaller % of edge).
Target the frequency DOWN toward ~80–120 tr/yr, not up. If Q04 net-of-cost is negative,
widen Y further before abandoning.

## strategy_params (explicit — build as EA inputs)
| param | default | type | sweep / notes |
|---|---|---|---|
| `lookback_bars` (X) | 20 | int | rolling High/Low window |
| `atr_mult` (Y) | 2.0 | double | **the cost lever — sweep UP 1.5/2.0/2.5/3.0 to cut freq** |
| `atr_period` (Z) | 14 | int | |
| `sl_atr_mult` | 2.0 | double | hard stop distance |
| `tp_mode` | fixed_atr | enum{fixed_atr,fixed_pct} | via one-shot WFA |
| `tp_atr_mult` | 1.5 | double | sweep |
| `entry_start_hour` | 0 | int (broker) | **[DESIGN] map 18:00 ET → broker (GMT+2/+3); confirm, don't invent** |
| `entry_end_hour` | 7 | int (broker) | last-entry cutoff (~01:00 ET) |
| `exit_hour` | 13 | int (broker) | hard flatten (~07:00 ET) |
| `risk_per_trade_pct` | 1.0 | double % | RISK_FIXED backtest / RISK_PERCENT live |

Keep ≤2–3 swept inputs at a time (Davey DOF): the real DOF are `atr_mult` (Y), `tp_atr_mult`,
and the session hours.

## Build notes
- New EA `framework/EAs/QM5_12846_euro-night-mr-eurusd`, symbol **EURUSD.DWX**, period **H1**
  (session-time-gated; the overnight window matters more than the bar TF — do NOT invent a
  non-standard 105-min TF).
- **News-blackout ON** (FX overnight includes some releases). Recompile against the current
  resolver; real ea_id 12846; RISK_FIXED backtest / RISK_PERCENT live; no ML; no grid.

## Acceptance & validation
Q02 → **Q04 net-of-cost = THE acid test (FX HIGH commission; this is where it lives or dies)**
→ Q05–Q08. One-shot WFA for TP (Davey: never re-tune after seeing OOS). On a soft Q08, run the
Round24 admission screen (97e655fe): an overnight-EUR MR sleeve should be strongly orthogonal
to the breakout/trend book. **If it can't clear Q04 net-of-cost even with a wide Y, retire it**
— we do NOT force a cost-losing FX edge into the book.
