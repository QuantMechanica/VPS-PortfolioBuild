---
ea_id: QM5_20004
slug: turn-of-month-index-long
type: strategy
source_id: fx_edge_army_A3_2026-07-16
source_citation: "McConnell, J. J., & Xu, W. (2008). Equity Returns at the Turn of the Month. Financial Analysts Journal, 64(2), 49-64. DOI 10.2469/faj.v64.n2.11. Lakonishok, J., & Smidt, S. (1988). Are Seasonal Anomalies Real? A Ninety-Year Perspective. Review of Financial Studies, 1(4), 403-425 (Journal). URL https://doi.org/10.2469/faj.v64.n2.11"
sources:
  - "docs/research/FX_EDGE_DISCOVERY_SCIENTIFIC_FRAMEWORK_2026-07-16.md"
  - "docs/research/FX_EDGE_ARMY_RANKED_ACTIONS_2026-07-16.md"
  - "docs/research/CARD_DRAFT_TURN_OF_MONTH_INDEX_LONG_2026-07-16.md"
concepts:
  - turn-of-month-calendar-flow
  - long-only-index-overlay
  - non-discretionary-flow
indicators:
  - trading-day-counter
  - sma-trend-filter
  - atr-stop
target_symbols: [DE40.DWX, NDX.DWX]
logical_symbol: QM5_20004_DE40_TURN_OF_MONTH_D1
period: D1
expected_trade_frequency: "D1 calendar overlay, approximately 12 long events/year/index (turn-of-month window)."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-17
g0_approval_reasoning: "R1 PASS McConnell-Xu 2008 (Financial Analysts Journal) + Lakonishok-Smidt 1988 (RFS) turn-of-month effect, ninety-year persistence; R2 PASS pure calendar entry/exit, deterministic, <=3 DoF; R3 PASS DE40.DWX and NDX.DWX exist in the tester universe; R4 PASS no ML/grid/martingale. Non-discretionary pension/401k/payroll inflow flow (price-inelastic). fx-edge-army A3, highest-EV genuinely-new build, orthogonal new family."
expected_pf: 1.3
expected_dd_pct: 12.0
priority_track: true
neighborhood_note: "Calendar-discrete params (window days-before/after, exit-day N) must be perturbed +/-1 lattice step at Q08, never +/-pct (see docs/research/Q08_NEIGHBORHOOD_PARAM_TYPE_AWARE_SPEC_2026-07-17.md)."
supersedes_direction_error: "CARD_DRAFT_MONTHEND_FX_REBALANCING (killed as-specified; direction-inverted)"
---

# Turn-of-Month Equity-Index Long-Only Overlay

## Source

Peer-reviewed turn-of-the-month effect literature: **McConnell, J. J., & Xu, W. (2008), "Equity Returns
at the Turn of the Month," Financial Analysts Journal, 64(2), 49-64** (DOI 10.2469/faj.v64.n2.11) — the
market's excess return historically concentrates in the ~4-day turn-of-month window; and **Lakonishok, J.,
& Smidt, S. (1988), "Are Seasonal Anomalies Real? A Ninety-Year Perspective," Review of Financial Studies,
1(4), 403-425** — ninety-year persistence. Mechanism: non-discretionary, date-fixed pension / 401(k) /
payroll-deferral inflows plus calendar-locked fund rebalancing deployed regardless of price — a
price-inelastic structural flow, not a discretionary bet, which is why it survives publication.
URL https://doi.org/10.2469/faj.v64.n2.11 . In-house expression from the fx-edge-army (wf_28fc3bf4, A3),
vetted against the QuantMechanica FX-edge scientific framework (named limit-to-arbitrage flow,
low-frequency/cost-friendly, orthogonal new family).

## thesis
Around the turn of the month (last ~1 trading day + first ~3–4 of the new month) equity indices face
**non-discretionary, date-fixed BUY pressure**: automatic pension / 401(k) / payroll-deferral inflows
and calendar-locked fund rebalancing must be deployed regardless of price (Xu–McConnell; Lakonishok–Smidt
"turn-of-the-month effect"). Go **LONG the index** into that window and exit as the flow completes.

## market_universe
**DE40.DWX primary, NDX.DWX secondary.** DE40 is deliberately preferred: the US turn-of-month effect has
partially **arbitraged away post-publication**, so a less-crowded European index is the higher-prior bet.
Long-only (the flow is one-directional).

## timeframe
D1. Enter at/near the close of the **last trading day of the calendar month**; hold through the **first
N trading days** of the new month (N=3 default); exit on the day-count. ~12 events/yr → low cost drag
(index round-trip ≈ $4.4 vs a ~30–50 bp window drift ≈ **~10× cost cushion**).

## entry
Pure calendar: on the last D1 bar of the month, open LONG. One primary parameter = the window definition
(days-before / days-after). Optional light filter: skip if the index closed the month in a hard downtrend
(e.g. below its 50-day SMA) — inflows still arrive but the drift is swamped in bear regimes.

## exit
Time-based: flat at the close of the N-th trading day of the new month (N=3). Optional protective SL at
k×ATR(20). No fixed price target — the edge is the calendar window, not a level.

## stop
Protective stop-loss (SL) at k×ATR(20) of the index (wide — this is a flow trade, not a tight scalp);
position sized off the ATR-based SL distance so risk stays ≤1% per sleeve.

## risk
`RISK_FIXED` backtest / `RISK_PERCENT` live, hard ≤1% per sleeve. Long-only single-index exposure.

## filters
- Turn-of-month calendar window only (trading-day counting off the index's own D1 stream; broker-time
  month boundaries, GMT+2/+3 US-DST).
- High-impact news blackout (order the flatten BEFORE the news return — no-weekend ordering-gap fix).
- Optional trend gate (above/below 50-SMA) to duck bear-regime windows.

## falsification (MANDATORY — army guard)
Pre-register and gate on a **2015–2025 OOS** test: the ~4-day window must be **positive DRIFT (not a
reversal)** AND clear the ~$4.4 index cost with margin, on DE40 *and* NDX separately. If the US window is
a decayed reversal, keep DE40 only. If neither is drift-positive net, **kill the card** — no parameter
mining of the window to manufacture a fit.

## q08_q11_risks
- **LOW_SAMPLE** (~12/yr) — admissible per OWNER 2026-07-16 (≥6 tr/yr); pool DE40+NDX for power.
- **Neighborhood/Q08** — params are calendar-discrete; perturb ±1 lattice step, not ±% (OWNER rule
  2026-07-17; see Q08_NEIGHBORHOOD_PARAM_TYPE_AWARE_SPEC_2026-07-17).
- **Long-only regime dependence** — bad in sustained bear markets; the OOS gate + optional trend filter
  address it; expect `8.10_regime_crisis` scrutiny, report regime-split P&L.
- **Orthogonality** — a calendar EQUITY-flow bet, uncorrelated with our FX/carry/cointegration/JPY-calendar
  sleeves → high marginal book value (framework Part V). New family for the book.

## implementation_notes
- Calendar entry/exit via trading-day counting on the index D1 stream (skip weekends/holidays).
- Single primary parameter (window) + exit-day N + optional trend filter → **≤3 real DoF** (DSR-honest).
- Compile via `compile_one.ps1`; real-tick Model 4; index commission injected at Q04+.
- This is the corrected successor to the month-end **FX** card — that idea shorted the flow (inverted)
  and used a D1 close that never trades the 4pm fix; here the flow is captured directly as index length.

## why this is the right new build (army linkage)
fx-edge-army action **A3**: strongest cost cushion (~10×) of any discovered edge, cleanest
price-inelastic non-discretionary flow, **no new data infrastructure**, orthogonal new family. Verified
survives=true, mechanizable=true. The highest-EV genuinely-new build in the set.
