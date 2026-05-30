---
ea_id: QM5_1116
slug: hopwood-asctrend-h1-tf
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/indicator-color-flip]]"
indicators:
  - "[[indicators/asctrend]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS ForexFactory URL and named Hopwood source; R2 PASS ASCTrend/EMA entry and flip/RR exits are mechanical; R3 PASS FX majors available on DWX; R4 PASS fixed parameters one-position no ML/grid/martingale."
---

# QM5_1116 Hopwood ASCTrend H1 Trend-Follower

## Quelle
- Primary: ForexFactory thread/166910 "Steve's Simple System" + thread/282290
  "Steve Hopwood Forex" master thread (long-running EA-cluster index).
- URL hub: https://www.forexfactory.com/thread/166910
- Author: `Steve Hopwood` (named ForexFactory identity, ~2009-2018 active;
  open-sourced ~30 MT4 EAs to the community under the same name).
- Mechanic provenance: ASCTrend1.mq4 indicator (semaphore color-flip) used as
  the trigger on H1, with a long EMA acting as direction filter. The Hopwood
  EAs are wrappers around this same primitive.

## Mechanik

### Entry
- Compute ASCTrend1 semaphore on H1 (parabolic-SAR-like with `RISK=3` default).
- Compute EMA(200, H1) as long-trend filter.
- LONG: previous bar's ASCTrend dot prints below the bar (blue/up state) AND
  `Close[1] > EMA(200, H1)`. Enter market on next bar open.
- SHORT: mirror — dot prints above the bar (red/down) AND `Close[1] < EMA(200, H1)`.
- One position per symbol per magic (HR14). On a flat-to-trend flip, exit
  current position before reversing.

### Exit
- Primary: ASCTrend dot flips to opposite color on the closed H1 bar.
- Safety: hard-stop fixed RR = 2.0 from initial stop distance (P3 sweepable
  in {1.5, 2.0, 3.0}).

### Stop Loss
- Initial SL: `ATR(14, H1) × 2.0` from entry price (P3 sweep
  {1.0, 1.5, 2.0, 2.5}).
- Alternative for P3: prior H1 swing low (long) / swing high (short) within
  the last 10 H1 bars.

### Position Sizing
- `RISK_FIXED = $1000` for P2-baseline (HR4).
- `RISK_PERCENT = 0.5%` for live (RISK_PERCENT-mode in T6 set file).
- Lot size derived from SL distance × pip-value.

### Filters
- Spread cap: 25 pts.
- News-filter hook (off by default for P2 — callable for live).
- No grid, no martingale, no scale-in. One position, one stop, deterministic.

## Concepts
- [[concepts/trend-following]] — primary (ASCTrend = SAR-family direction)
- [[concepts/indicator-color-flip]] — secondary (entry+exit on semaphore flip)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named FF handle (Steve Hopwood), specific master-thread URL, ~9-year-old community-canonical EA cluster. Relaxed-R1 (2026-05-15) requires only a verifiable link. |
| R2 Mechanisch | PASS | ASCTrend = deterministic SAR-family indicator with closed-form formula; entry rule (dot-color + EMA-filter) and exit rule (dot-flip / hard RR) are unambiguous. |
| R3 DWX-testbar | PASS | Hopwood deployed on FX majors — all in DWX feed. Suggested P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, EURJPY.DWX, GBPJPY.DWX. |
| R4 No ML | PASS | Fixed RISK_FIXED in inputs, fixed ASCTrend RISK=3 parameter, fixed EMA(200), no adaptive lot sizing. No ML, no online learning, no grid. |

All four PASS expected — G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from ForexFactory batch 3 (Hopwood cluster)

## Implementation Notes for Codex (P1)
- ASCTrend1 has multiple community ports for MT5; the canonical formula is:
  given `Risk` parameter (default 3), compute a Wilder-smoothed range and
  plot a dot/semaphore that flips when price closes beyond the trailing
  channel. Implement inline rather than depending on a 3rd-party indicator.
- DWX symbols for P2: **EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX,
  EURJPY.DWX, GBPJPY.DWX** (6 majors + JPY-crosses where the trend
  mechanic is most active).
- Trading timeframe: H1 (entry signal + exit signal).
- Higher-TF context: EMA(200, H1) — same TF, no MTF-handle complexity.
- Smoke (P1): EURUSD.DWX H1 one month; full P2: 1-year H1 per symbol.

## Verwandte Strategien
- Cousin of QM5_1051 (cc-3ducks-sma60-mtf, 6e967762) — both are
  SMA/MA-direction trend-followers, but 1051 is MTF-confluence (H4+H1+M5)
  whereas this is single-TF (H1 only) with a SAR-family color-flip trigger.
- Differentiator: ASCTrend dot-flip exit is more responsive than 1051's
  "lowest-duck SMA flip" exit.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*
