---
ea_id: QM5_20072
slug: 4h-box-frankfurt-london-r1-recovery
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/range-breakout]]"
  - "[[concepts/session-timing]]"
indicators:
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-23
target_symbols: [EURUSD.DWX, GBPUSD.DWX, EURGBP.DWX, EURJPY.DWX]
expected_trades_per_year_per_symbol: 70
card_body_incomplete: false
card_body_missing: ""
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: draft
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
r2_reasoning: "Fixed 03:00-07:00 box high/low, OCO Buy-Stop/Sell-Stop breakout with box-size sanity gate and fixed 1.5x-box TP/opposite-box SL — fully deterministic, no discretion."
r3_reasoning: "Target symbols EURUSD.DWX, GBPUSD.DWX, EURGBP.DWX, EURJPY.DWX are all DWX pairs with H1 data available."
r4_reasoning: "Fixed window/RR/ATR parameters, no ML/grid/martingale, OCO pending pair enforces one position per magic."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_1226_4h-box-frankfurt-london.md"
source_citation: ""
identity_repair_required: false
identity_repair_conflicts: ""
recovered_from_ea_id: "QM5_1226"
identity_repair_resolved: true
identity_repair_resolved_at: "2026-07-23T20:29:54+00:00"
recovery_status: IDENTITY_REPAIRED
g0_approval_reasoning: "R1 informational (FF Trading Systems cluster, source_id present); R2 PASS deterministic 03:00-07:00 Frankfurt box high/low, OCO Buy-Stop/Sell-Stop breakout, box-size sanity gate, 1.5xbox-size TP, opposite-box SL; R3 PASS EURUSD/GBPUSD/EURGBP/EURJPY.DWX H1; R4 PASS fixed params, OCO pending pair = si"
expected_pf: 1.15
expected_dd_pct: 20.0
---

# QM5_1226 4-Hour Box — Frankfurt-Range Pre-London Breakout

## Quelle
- Primary: ForexFactory Trading Systems forum — "4-hour box" /
  "Frankfurt session breakout" thread cluster, multiple named-FF-handle
  owners. The mechanic captures the 03:00-07:00 broker-time range
  (Frankfurt session, last 4 hours before London open) and trades the
  break of that range at/after the London open.
- URL hint: FF Trading Systems forum search "4 hour box Frankfurt
  breakout" (multiple community threads).
- Mechanic provenance: well-known FX session-overlap edge — Frankfurt
  open (03:00 broker-time) builds a coherent pre-London range; London
  open (07:00 broker-time) injects volume that breaks the range. This
  is a session-timing primitive distinct from the BigBen Asian-range
  (00:00-07:00) breakout already cardified as QM5_1120.

## Mechanik

### Entry
- Define box-window: 03:00 to 07:00 broker-time (NY-Close server,
  i.e. GMT+2 outside US DST / GMT+3 during US DST — last 4 hours
  before London open).
- At 07:00 broker-time on the daily close-bar boundary, compute:
  - `Box_High` = max(High) over 03:00-07:00 (4 H1 bars)
  - `Box_Low`  = min(Low) over same window
  - `Box_Size` = Box_High − Box_Low
- Place pending orders at 07:00:
  - `BuyStop` at `Box_High + 1 spread` with SL at `Box_Low − 1 pip`,
    TP at `Box_High + Box_Size × 1.5`
  - `SellStop` at `Box_Low − 1 spread` with SL at `Box_High + 1 pip`,
    TP at `Box_Low − Box_Size × 1.5`
- First fill cancels the other pending (OCO).
- Box-validity window: pending orders live until 12:00 broker-time. If
  neither fills by 12:00, both cancelled (no chase into NY session).
- One position per symbol per magic (HR14).

### Exit
- Primary: TP hit (Box_Size × 1.5 from breakout level).
- Secondary: SL hit (other side of the box).
- Tertiary: end-of-day stop at 22:00 broker-time — flat all positions
  before the daily-roll spread widening (P3-toggleable, default ON).

### Stop Loss
- Defined at entry: opposite side of the box.
- Box-size sanity check: skip the day if `Box_Size < 0.5 × ATR(14, D1)`
  (degenerate range, no break-edge) or `Box_Size > 2.0 × ATR(14, D1)`
  (already extended, breakout is exhaustion). P3 sweepable.

### Position Sizing
- `RISK_FIXED = $1000` for P2-baseline (HR4).
- `RISK_PERCENT = 0.5%` for live (RISK_PERCENT-mode in T6 set file).
- Lot size derived from SL distance × pip-value.

### Filters
- Day-of-week: Mon-Thu only by default (P3 sweepable: include Fri,
  exclude Mon).
- Spread cap at entry-fill: 25 pts.
- News-filter hook (high-impact London-AM releases, e.g. UK CPI / ECB
  speakers) — off by default for P2, callable for live.
- No grid, no martingale, no scale-in. One position via OCO pending
  pair, one stop, deterministic.

## Concepts
- [[concepts/range-breakout]] — primary (box-break at London open)
- [[concepts/session-timing]] — primary (Frankfurt-Pre-London window
  is the source of the edge)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | ForexFactory Trading Systems forum thread cluster, multiple named-FF-handle owners documenting the same Frankfurt-pre-London mechanic. Relaxed-R1 (2026-05-15) requires only a verifiable forum-source attribution. |
| R2 Mechanisch | PASS | Box definition is time-based and high/low over a fixed window — fully deterministic. OCO pending pair + TP/SL at fixed multiples of box size. No discretion. |
| R3 DWX-testbar | PASS | Frankfurt-pre-London range breakout deployed on EUR-crosses and GBP-crosses — all in DWX feed. Suggested P2 basket: EURUSD.DWX, GBPUSD.DWX, EURGBP.DWX, EURJPY.DWX (European-session-driven pairs preferred). |
| R4 No ML | PASS | Fixed window (03:00-07:00), fixed RR (1.5), fixed ATR multiplier on box-sanity, fixed lot sizing. No adaptive parameters. No ML, no online learning, no grid, no martingale. |

All four PASS expected — G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-18 — drafted from ForexFactory batch 4 (4-hour box / Frankfurt
  session cluster)

## Implementation Notes for Codex (P1)
- Broker-time = NY-Close server time. Confirm via `TimeTradeServer()`
  return at OnInit and log offset; do NOT assume GMT.
- Box-window bar iteration: iterate H1 bars where `Hour(bar.time) IN
  {3, 4, 5, 6}` — that's exactly 4 bars on a normal session day. Skip
  partial sessions (e.g., bank holidays where fewer than 4 bars are
  present in window).
- DST handling: the 03:00-07:00 window in NY-Close server time stays
  pinned to the Frankfurt-pre-London local window through both DST
  transitions — the server clock IS the broker clock, so no shift logic
  needed inside the EA.
- Pending order placement: use `OrderSend` with `ORDER_TYPE_BUY_STOP`
  and `ORDER_TYPE_SELL_STOP`. OCO logic: on one fill, cancel the
  remaining pending in `OnTradeTransaction`.
- DWX symbols for P2: **EURUSD.DWX, GBPUSD.DWX, EURGBP.DWX, EURJPY.DWX**.
- Trading timeframe: H1 (box-bar TF + entry/exit-management TF).
- Smoke (P1): EURUSD.DWX H1 one month; full P2: 1-year H1 per symbol.

## Verwandte Strategien
- Sibling of QM5_1120 (bigben-london-open-breakout) — both are
  pre-London range breakouts, but 1120 uses the full Asian-overnight
  range (00:00-07:00, 7 H1 bars) and 1226 uses only the Frankfurt
  4-hour pre-London window (03:00-07:00, 4 H1 bars). 1226 should fire
  with a smaller box size, higher win-rate on tight ranges, and
  fewer false breaks from the overnight noise.
- Differentiator vs trend-followers in this source (1116, 1117, 1223):
  this is a pure SESSION-TIMING edge, not an indicator-driven edge.
  Adds another regime diversifier to the ForexFactory contribution.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*
