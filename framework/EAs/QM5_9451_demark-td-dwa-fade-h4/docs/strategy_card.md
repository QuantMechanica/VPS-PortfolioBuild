---
ea_id: QM5_9451
slug: demark-td-dwa-fade-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/mean-reversion-to-vwap-proxy]]"
  - "[[concepts/range-weighted-average]]"
indicators:
  - "[[indicators/demark-td-dwa]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; ForexFactory thread plus DeMark (Wiley 1994) and Perl (Bloomberg 2008) book lineage provides clear single-source attribution."
r2_mechanical: PASS
r2_reasoning: "TD-DWA is a closed-form range-weighted rolling mean; all entry/exit conditions are deterministic closed-bar ATR comparisons with explicit SL and time-stop."
r3_data_available: PASS
r3_reasoning: "DWA requires only bar OHLC (no exchange volume); testable on all DWX FX, metals, oil, and index CFDs listed in target_symbols."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed periods (13, 14, 12) and thresholds throughout; 1-position-per-magic enforced; no ML, adaptive components, or martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 60
last_updated: 2026-05-19
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX]
g0_approval_reasoning: "R1 PASS: cites ForexFactory URL plus DeMark/Perl books; R2 PASS: deterministic H4 DWA/ATR entry, exit, SL, time stop with ~60 trades/year/symbol; R3 PASS: portable to DWX FX/metals/oil/index CFDs with SP500 T6 caveat; R4 PASS: fixed parameters, no ML/adaptive/grid/martingale, 1-position-per-magic."
---

# DeMark TD Dollar-Weighted Average Fade (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14001900 (ForexFactory
  Trading Systems sub-forum, DeMark indicator thread cluster, TD-DWA
  sub-thread, posts circa 2015–2025).
- Author lineage: Thomas R. DeMark — *The New Science of Technical
  Analysis* (Wiley 1994) ch. 7 (range-weighted price averages); Jason
  Perl — *DeMark Indicators* (Bloomberg Press 2008, ISBN 978-1576602065)
  ch. 14 "TD Pressure and Range-Weighted Statistics" — explicit
  TD-Dollar-Weighted-Average formula on range as proxy for traded volume.
  ForexFactory thread cluster discusses TD-DWA as an alternative-VWAP
  anchor for mean-reversion fades on FX where exchange volume is not
  available.
- Distinctness sibling cards (see Verwandte Strategien): QM5_9401
  (TDPRH/L fade — bar-OHLC-derived predicted-range fade primitive),
  QM5_9281 / QM5_9351 (TD Demand/Supply Line), QM5_1438 (TD-DeMarker
  oscillator), QM5_1394 / QM5_1585 / QM5_2296 / QM5_2351 (TD-Differential
  family). This card's primitive is the range-weighted average anchor
  (DWA), structurally distinct from predicted-range, demand/supply lines,
  the DeMarker oscillator, and Differential family.

## Mechanik

### TD-DWA computation (Perl 2008 ch. 14)

For each closed H4 bar `t`, define:

- `bar_range[t] = High[t] − Low[t]`
- `TD-DWA[t] = sum_{i=t−12}^{t} (Close[i] · bar_range[i])
              / sum_{i=t−12}^{t} bar_range[i]`

i.e. a 13-bar rolling mean of `Close` weighted by per-bar range. The
range weight makes "moved-money" bars dominate the average, mimicking
VWAP behavior on instruments without published exchange volume. N=13 is
DeMark's canonical Setup length.

Compute `ATR(14)` on closed H4 bars.

### Entry (mean-reversion fade)

Long trigger (mirror for short):

1. Prior bar deviation: `Close[t−1] ≤ TD-DWA[t−1] − 1.0·ATR(14)[t−1]`
   (bar `t−1` closed significantly below the range-weighted average).
2. Current bar revert: `Close[t] > Close[t−1]` AND `Close[t] > Open[t]`
   (closed bar `t` is green and closes above the prior bar's close).
3. Reject-tail discipline: `(Close[t] − Low[t]) ≥ 0.3·(High[t]−Low[t])`
   (lower wick: real rejection, not a doji).
4. Entry on the **next H4 bar's open** at market.

Short trigger: mirror with `Close[t−1] ≥ TD-DWA[t−1] + 1.0·ATR(14)[t−1]`,
red bar `t`, upper-wick discipline.

Magic = `9451 * 10000 + slot` (1-position-per-magic, HR4).

### Exit

**Profit target (DWA-revert):** close the position when `Close[t]`
first touches `TD-DWA[t]` (within ±0.1·ATR(14) band) after entry, on the
next H4 bar's open at market.

**Time stop:** if neither SL nor TP hit within 12 closed H4 bars after
entry, exit at market on bar 13's close.

### Stop Loss

- Long: `SL = Low[trigger_bar] − 0.8·ATR(14)` (trigger_bar = bar `t`
  above).
- Short: `SL = High[trigger_bar] + 0.8·ATR(14)`.

ATR snapshot at entry, fixed for the trade.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD (HR4).
- Live: `RISK_PERCENT = 0.5%` of equity at entry (HR4).

### Zusätzliche Filter

- Spread filter: skip if current spread > `0.20·ATR(14)`.
- Time filter: H4 bars only; no intra-bar entries; no entries during the
  weekly gap (Friday close → Sunday open). Sunday-open gap bar is
  excluded from the DWA window (range weight set to 0 to avoid
  range-inflation distortion).
- News filter (P1 baseline): skip entry if the news_calendar shows a
  HIGH-impact event for any quote currency of the symbol within ±60
  minutes of the entry-bar open.
- One-trigger discipline: after a long entry, no further long entries
  are taken until `Close[t]` has revisited `TD-DWA[t]`. Mirror for short.

## Concepts (was ist das für eine Strategie)

- [[concepts/mean-reversion-to-vwap-proxy]] — primary (range-weighted
  average as alternative-VWAP anchor)
- [[concepts/range-weighted-average]] — secondary (DWA primitive)
- [[concepts/oversold-bounce]] — tertiary (deviation + revert pattern)

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Tom DeMark: 35+ year track record at major institutions (Tudor, SAC). Primary publications Wiley 1994. Jason Perl (DeMark licensee) — Bloomberg Press 2008. ForexFactory thread cluster ongoing. R1 PASS expected under 2026-05-15 relaxed criteria. |
| R2 Mechanical | UNKNOWN | TD-DWA is a deterministic closed-form rolling weighted mean. Entry triggers reduce to ATR + close/open/high/low comparisons on closed bars. No look-ahead. Entry/SL/TP/time-stop all closed-form. R2 PASS expected. |
| R3 Data Available | UNKNOWN | DWA explicitly designed for instruments without exchange volume — uses range as volume proxy. Testable on all FX-majors, XAUUSD, XTIUSD, and Darwinex index CFDs (GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX) on H4. SP500.DWX backtest-only — T_Live promotion requires NDX.DWX or WS30.DWX parallel validation (Board Advisor T_Live-gate enforcement). R3 PASS. |
| R4 ML Forbidden | UNKNOWN | Fixed periods (13, 14, 12). Fixed thresholds (1.0, 0.3, 0.1, 0.8). No adaptive parameters, no ML, no neural net, no online learning. 1-position-per-magic. No martingale. R4 PASS expected. |

### R3 SP500.DWX live-promotion caveat

Live promotion T_Live gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T_Live deploy requires a
parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
This is Board Advisor's T_Live-gate enforcement, not Research's.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING — drafted by Research from
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 58.

## Verwandte Strategien

- [[strategies/QM5_9401_demark-tdprl-fade-h4]] — DeMark fade family, fades
  the TD-Predicted-Range Low (bar-OHLC-derived predicted-range primitive,
  not range-weighted average).
- [[strategies/QM5_9281_demark-td-demand-supply-line-h4]] — DeMark
  Demand/Supply Line locked-anchor variant.
- [[strategies/QM5_9351_demark-td-demand-line-active-h4]] — DeMark
  Demand Line active variant.
- [[strategies/QM5_1438_demark-td-demarker-h4]] — DeMarker oscillator
  primitive.
- [[strategies/QM5_1394_demark-td-differential-h4]] — TD-Differential
  family.

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 distinctness audit must verify TD-DWA primitive
  (range-weighted close average) is distinct from TDPRH/L predicted-range
  primitive (9401). DWA is a smoothed-anchor mean-reversion target; TDPR
  is a bar-bounded fade trigger.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
