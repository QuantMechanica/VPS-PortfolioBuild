---
ea_id: QM5_12796
slug: carver-vol-trend
type: strategy
source_id: carver-vol-trend-inhouse-2026-06-29
sources:
  - "[[sources/carver-systematic-trading]]"
  - "[[sources/carver-leveraged-trading]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-targeting]]"
  - "[[concepts/ewmac-crossover]]"
indicators:
  - "[[indicators/ewma]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Rob Carver's vol-targeted trend (EWMAC crossover + volatility scaling), published in 'Systematic Trading' / 'Leveraged Trading' - a reputable, widely-replicated CTA-style method (same family as Clenow 'Following the Trend' we already flagged). Independently mined as SM_285_CarverVolTrend / SM_321_CarverSlowAbsoluteMR (.ex5-only). BUILD IN-HOUSE from the published method. R1-R4 waived."
r2_mechanical: PASS
r2_reasoning: "Deterministic: EWMAC(fast,slow) crossover forecast, scaled by recent volatility, capped; position sized to a target volatility; long/short. No discretion, no ML, no optimization-in-EA."
r3_data_available: PASS
r3_reasoning: ".DWX daily history for indices/gold/energy; EWMA + ATR/realized-vol only; no external data."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed-parameter EWMAC + vol scaling; no ML, no martingale/grid; single bounded position; vol-targeted sizing is risk-reducing (not loss-scaling)."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 15
expected_pf: 1.30
expected_dd_pct: 12
last_updated: 2026-06-29
g0_approval_reasoning: "G0 2026-06-29 Claude, OWNER-directed 'alles selbst bauen'. Second high-value LOW-COMMISSION candidate from the Dropbox SM campaign (SM_285/321 Carver, .ex5-only -> build from the published method). Carver vol-targeted trend = reputable CTA method, same family as Clenow; built on indices/gold/energy (low-commission, where trend gross approx net). Crucially, VOL-TARGETING is exactly the sizing layer our hot-VaR finding called for (fill the VaR budget). Pure trend = maximally uncorrelated to our MR-heavy book. Decisive gates: Q04 net-of-cost (low-freq -> DL-070/076 track) + Q08."
---

# Carver Vol-Targeted Trend (in-house build)

## Purpose
Build Rob Carver's vol-targeted trend (EWMAC crossover + volatility scaling) from the published
method. A reputable pure-trend, vol-targeted sleeve on low-commission instruments - maximally
uncorrelated to our MR-heavy book, and the vol-targeting is the sizing layer the hot-VaR test
wanted (fills the 6.5% VaR budget).

## Source / basis
Rob Carver, "Systematic Trading" + "Leveraged Trading" (EWMAC forecasts, vol scaling, vol-target
sizing). Same family as Clenow "Following the Trend" (already flagged, [[project_qm_tv_ff_retail_survey_2026-06-28]]).
Mined as SM_285_CarverVolTrend + SM_321_CarverSlowAbsoluteMR (no source).

## Strategy (build spec)
- **Signal:** EWMAC = EWMA(fast) - EWMA(slow). Canonical speed pairs: (16,64) default; optionally
  combine (8,32)+(16,64)+(32,128) as a multi-speed forecast (average). Long if forecast>0, short if <0.
- **Volatility scaling:** raw forecast / recent return volatility (e.g. EWMA stdev of daily returns),
  then scale to a target forecast and CAP (Carver caps the scaled forecast, e.g. +/-20) to bound risk.
- **Sizing:** position vol-targeted -> lots set so the position's expected vol approximates a target
  (this is the vol-target sizing layer; in V5 backtest use RISK_FIXED equivalent off the ATR stop).
- **Stop/exit:** trend-following with an ATR-based protective stop; exit on forecast sign flip
  (or opposite EWMAC cross). Low cadence (~10-20/yr).
- **Optional sibling (SM_321):** Carver "slow absolute MR" - a slow mean-reversion variant; build the
  trend version first.

## V5 conventions
Single-position-per-magic, RISK_FIXED backtest / RISK_PERCENT live, QM_KillSwitch, QM_NewsFilter,
magic = ea_id*10000+slot, QM_RiskSizer/QM_Logger, closed-bar (D1). Costs injected at Q04/Q08.

## Instruments
Low-commission, trend-friendly: NDX, US500, GER40, XAUUSD, XAGUSD, XTIUSD, NATGAS. (Trend on FX is
weaker and cost-heavier - index/gold/energy first.)

## Acceptance
Q02 + low-freq trade floor -> Q04 net-of-cost (route to DL-070/076 low-freq/pooled track given ~10-20
tr/yr) -> Q08. Value = a pure-trend, vol-targeted, low-correlation diversifier for the MR-heavy book
(target: improves book Sharpe via decorrelation, and being vol-targeted it FILLS the VaR budget unlike
our low-vol D1 sleeves). Anti-correlation check vs the book + vs the breakout sleeves at admission.
