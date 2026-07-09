---
ea_id: QM5_9403
slug: williams-pro-go-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/professional-vs-public-money]]"
  - "[[concepts/intra-bar-vs-overnight-component]]"
indicators:
  - "[[indicators/pro-go]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; ForexFactory URL plus Larry Williams Wiley 1999 ch. 14 book attribution and MQL5 community reproductions provide clear lineage."
r2_mechanical: PASS
r2_reasoning: "Pro and Go are closed-form cumulative sums of OHLC primitives; zero-cross entry, SMA/ATR filters, Pro-flip exit, and time-stop are all deterministic."
r3_data_available: PASS
r3_reasoning: "OHLC-based Pro/Go primitive is instrument-agnostic; testable on DWX FX-majors, XAUUSD, XTIUSD, and index CFDs on H4."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed periods (N=14, SMA=50, 30 bars) and thresholds (1.5, 2.0, 1.0) only; no ML, no PnL-adaptive parameters, one position per magic."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 45
last_updated: 2026-05-19
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX]
g0_approval_reasoning: "R1 PASS: cites ForexFactory URL and Williams book; R2 PASS: mechanical H4 Pro zero-cross/SMA/ATR entries and explicit exits with ~45 trades/year/symbol; R3 PASS: OHLC H4 strategy testable on DWX FX/metals/oil/indices with SP500 caveat; R4 PASS: fixed params, no ML/adaptive/martingale, 1-position-per"
---

# Williams Pro-Go Composite Cross (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14001800 (ForexFactory
  Trading Systems sub-forum, Larry Williams thread cluster, Pro-Go
  sub-thread, posts 2016-2024).
- Author lineage: Larry Williams — *Long-Term Secrets to Short-Term Trading*
  (Wiley 1999, ISBN 0-471-29722-4) ch. 14 "Professional Indicator vs.
  Public Indicator" pp. 213–222 — defines Pro and Go as the two
  components of intra-day participation. Williams' lecture series
  ("Pro Go indicator", 2003–2010) further refined the cross-signal
  application. Independent reproductions on MQL5 Code Base
  (community-attributed, 2018–2024).
- Distinctness sibling cards: covered in Verwandte Strategien below.
  Pro-Go is NOT an oscillator and NOT a breakout primitive — it is a
  decomposition of the close-vs-open and open-vs-prior-close moves
  into "professional" (intra-bar) and "amateur" (overnight) components.

## Mechanik

### Pro and Go indicators (Williams 1999 ch. 14)

For each closed H4 bar `t`, define:

- **Pro[t]** ("Professional money", body component):
  `Pro[t] = Σ_{i=t-N+1}^{t} (Close[i] − Open[i])`
- **Go[t]** ("Going money", gap component):
  `Go[t]  = Σ_{i=t-N+1}^{t} (Open[i] − Close[i-1])`

with `N = 14` (Williams' canonical value).

Williams' interpretation: `Pro` measures whether close-to-close moves
happen *during* the trading window (professional accumulation); `Go`
measures whether they happen *between* windows (retail / amateur
gap-trading). When `Pro > 0` while `Go < 0`, professionals are buying
during the session while amateurs sell into the gap — a bullish
divergence in participation.

For H4 application, "intra-bar" = bar's own open-to-close move; "gap"
= prior-bar-close to current-bar-open move. FX/CFDs have small gaps
except across the weekly close, so `Go` is dominated by weekly-gap
contribution unless filtered (see Zusätzliche Filter below).

### Entry

**LONG Pro-Go-cross trigger:**
1. `Pro[t]   > 0`                          (cumulative Pro positive)
2. `Pro[t-1] ≤ 0`                          (just crossed zero from below)
3. `Close[t] > SMA(Close, 50)[t]`          (above 50-bar trend filter)
4. `(Close[t] − SMA(Close, 50)[t]) ≤ 1.5 × ATR(14)`  (not over-extended)

**SHORT Pro-Go-cross trigger (mirror):**
1. `Pro[t]   < 0`
2. `Pro[t-1] ≥ 0`
3. `Close[t] < SMA(Close, 50)[t]`
4. `(SMA(Close, 50)[t] − Close[t]) ≤ 1.5 × ATR(14)`

Entry: next H4 bar's open (market order).

Magic = `9403 * 10000 + slot` (1-position-per-magic, HR4).

### Exit

**Profit target (mechanical):**

- For LONG:  `TP = Close[t_entry] + 2.0 × ATR(14)`.
- For SHORT: `TP = Close[t_entry] − 2.0 × ATR(14)`.

**Pro-flip exit (Williams' continuation rule):** if `Pro` crosses back
through zero against the position (`Pro[s] < 0` while LONG, or
`Pro[s] > 0` while SHORT) on any closed bar `s` after entry, exit
at the open of bar `s+1`.

**Time stop:** if neither SL nor TP nor Pro-flip exit fires within
30 closed H4 bars after entry, exit at market on bar 31's close.

### Stop Loss

- For LONG:  `SL = Close[t_entry] − 1.0 × ATR(14)`.
- For SHORT: `SL = Close[t_entry] + 1.0 × ATR(14)`.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD (HR4).
- Live: `RISK_PERCENT = 0.5%` of equity at entry (HR4).

### Zusätzliche Filter

- Spread filter: skip if current spread > `0.20·ATR(14)`.
- Time filter: H4 bars only; no intra-bar entries; no entries during the
  weekly gap. The bar immediately after weekly open MUST be excluded
  from `Go` summation — its `Open − prior Close` term is treated as
  `0` because the weekly-gap distorts the "amateur gap" interpretation
  on FX/CFDs.
- News filter (P1 baseline): skip entry if the news_calendar shows a
  HIGH-impact event for any quote currency of the symbol within ±60
  minutes of the entry-bar open.
- One Pro-cross signal per direction at a time (the active position
  must close before a new cross in the same direction triggers).

## Concepts (was ist das für eine Strategie)

- [[concepts/professional-vs-public-money]] — primary
- [[concepts/intra-bar-vs-overnight-component]] — secondary (Pro/Go
  decomposition)
- [[concepts/trend-following]] — tertiary (50-SMA filter)

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Larry Williams: 50+ year track record. Primary publication Wiley 1999 ch. 14 with verbatim formula. MQL5 Code Base community reproductions (2018-2024). ForexFactory thread cluster discussion. R1 PASS expected. |
| R2 Mechanical | UNKNOWN | Pro and Go are closed-form cumulative sums of close-open and open-prior-close differences. Cross-zero entry is deterministic. SMA + ATR primitives are native MT5. R2 PASS expected. |
| R3 Data Available | UNKNOWN | Pro-Go primitive is OHLC-based and instrument-agnostic. Testable on all FX-majors, XAUUSD, XTIUSD, Darwinex index CFDs on H4. SP500.DWX backtest-only — T6 live promotion requires NDX.DWX or WS30.DWX parallel validation. R3 PASS. |
| R4 ML Forbidden | UNKNOWN | Fixed periods (14, 50, 30), fixed thresholds (1.5, 2.0, 1.0). No adaptive parameters, no ML, no online learning. 1-position-per-magic. No martingale. R4 PASS expected. |

### R3 SP500.DWX live-promotion caveat

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation
on NDX.DWX or WS30.DWX before AutoTrading enable. This is Board Advisor's
T6-gate enforcement, not Research's.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING — drafted by Research from
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 57.

## Verwandte Strategien

- [[strategies/QM5_2025_williams-accumulation-distribution-h4]] — also a
  Williams accumulation primitive but uses A/D-line (running sum of
  weighted moves), not the Pro/Go decomposition.
- [[strategies/QM5_1533_williams-sentiment-index-h4]] — Williams family,
  different primitive (sentiment index).
- [[strategies/QM5_2079_williams-ultimate-oscillator-h4]] — Williams
  family, oscillator primitive (distinct from Pro-Go cumulative
  component).

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 distinctness audit must verify the Pro cumulative
  primitive is not reducible to a simple SMA(Close − Open). The
  cumulative-N sum has a memory horizon that a per-bar momentum
  oscillator lacks. P2 must confirm Pro-cross signal stream differs
  from straight C-O-momentum on H4 DWX data.
- 2026-05-19: Weekly-gap `Go` filter is critical for FX — without it,
  weekly-gap dominates the `Go` series.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
