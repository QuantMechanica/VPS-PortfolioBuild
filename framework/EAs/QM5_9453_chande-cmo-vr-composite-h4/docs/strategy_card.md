---
ea_id: QM5_9453
slug: chande-cmo-vr-composite-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/volatility-regime-gate]]"
  - "[[concepts/cmo-trend-breakout]]"
indicators:
  - "[[indicators/chande-momentum-oscillator]]"
  - "[[indicators/chande-volatility-ratio]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; ForexFactory thread plus Chande/Kroll Wiley 1994 book lineage provides clear single-source attribution."
r2_mechanical: PASS
r2_reasoning: "CMO and VR are closed-form deterministic indicators; all entry/exit conditions are boolean closed-bar comparisons with fixed thresholds and an explicit time-stop."
r3_data_available: PASS
r3_reasoning: "Both indicators are price-only (no exchange volume); testable on all DWX FX, metals, oil, and index CFDs listed in target_symbols."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed periods (14, 7, 28, 16) and thresholds throughout; 1-position-per-magic enforced; no ML, adaptive parameters, or martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
last_updated: 2026-05-19
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX]
g0_approval_reasoning: "R1 PASS: cites ForexFactory URL plus Chande/Kroll Wiley source; R2 PASS: deterministic H4 CMO/VR entry, exit, SL, sizing and filters with plausible ~30 trades/year/symbol; R3 PASS: price-only rules testable on DWX FX/metal/oil/index CFDs with SP500 live caveat; R4 PASS: fixed parameters, no ML/adapt"
---

# Chande VR-Gated CMO Trend-Breakout (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14002200 (ForexFactory
  Trading Systems sub-forum, Chande/Kroll thread cluster, CMO+VR composite
  sub-thread, posts circa 2016–2025).
- Author lineage: Tushar Chande & Stanley Kroll — *The New Technical
  Trader* (Wiley 1994, ISBN 0-471-59780-5) ch. 5 "The Chande Momentum
  Oscillator" pp. 95–112 (CMO formula and ±50 trend-breakout
  interpretation) + ch. 6 "The Volatility Index and Volatility Ratio"
  pp. 113–134 (VR formula and trend-vs-consolidation regime
  classification). Chande's *Beyond Technical Analysis* (Wiley 2001)
  reproduces both primitives. ForexFactory thread cluster discusses
  CMO+VR as a composite where VR confirms regime before CMO trend
  trigger fires.
- Distinctness sibling cards (see Verwandte Strategien): QM5_1801 (CMO
  zero-cross primitive, **un-gated**), QM5_9404 (VR+RSI **mean-reversion**
  composite — VR<0.7 consolidation regime + short-RSI fade). This card
  is the **complementary regime** to 9404: VR>1.3 trending regime + CMO
  ±50 breakout. The two cards together probe whether VR-regime gating
  is general-purpose across Chande entry primitives (mean-reversion via
  9404 + trend-breakout via 9453).

## Mechanik

### CMO primitive (Chande & Kroll 1994 ch. 5)

For each closed H4 bar `t`, with lookback `N = 14`:

- `up_sum[t]  = sum_{i=t−N+1}^{t} max(Close[i] − Close[i−1], 0)`
- `dn_sum[t]  = sum_{i=t−N+1}^{t} max(Close[i−1] − Close[i], 0)`
- `CMO[t]     = 100 · (up_sum[t] − dn_sum[t]) / (up_sum[t] + dn_sum[t])`

CMO ∈ [−100, +100]. Chande's canonical trend-breakout thresholds are
±50 (deeper than RSI ±70/30 because CMO normalises differently).

### VR primitive (Chande & Kroll 1994 ch. 6)

- `VR[t] = ATR(7)[t] / ATR(28)[t]`

Chande's regime classification:
- `VR < 0.7` — consolidation regime (used by sibling 9404).
- `0.7 ≤ VR ≤ 1.3` — neutral, no trade.
- `VR > 1.3` — **trending regime** (used by this card).

### Entry (CMO breakout, gated by VR-trending)

Long trigger (mirror for short):

1. **Trending regime confirmed:** `VR[t] > 1.3`.
2. **CMO upside breakout:** `CMO[t−1] ≤ +50` AND `CMO[t] > +50`
   (closed-bar cross above the +50 level).
3. **Direction confirmation:** `Close[t] > Open[t]` (bullish trigger bar).
4. **Reject extension blow-offs:** `|Close[t] − Close[t−1]| ≤
   2.0·ATR(14)[t-1]` (the cross bar is not a single-bar gap blow-off —
   protects against entering at a momentum exhaustion peak).
5. Entry on the **next H4 bar's open** at market.

Short trigger: mirror with `CMO[t−1] ≥ −50`, `CMO[t] < −50`,
`Close[t] < Open[t]`.

Magic = `9453 * 10000 + slot` (1-position-per-magic, HR4).

### Exit

**Profit target (CMO mean-revert through 0):** close the position on the
**next H4 bar open** after `CMO[t]` crosses **back through zero against
the position**:

- Long: closed-bar `CMO[t−1] > 0` AND `CMO[t] ≤ 0` → exit at next open.
- Short: closed-bar `CMO[t−1] < 0` AND `CMO[t] ≥ 0` → exit at next open.

**Time stop:** if neither SL nor CMO-zero-exit hit within 16 closed H4
bars after entry, exit at market on bar 17's close.

### Stop Loss

- Long: `SL = entry − 1.0·ATR(14)` (entry-bar ATR snapshot).
- Short: `SL = entry + 1.0·ATR(14)`.

ATR snapshot at entry, fixed for the trade.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD (HR4).
- Live: `RISK_PERCENT = 0.5%` of equity at entry (HR4).

### Zusätzliche Filter

- Spread filter: skip if current spread > `0.20·ATR(14)`.
- Time filter: H4 bars only; no intra-bar entries; no entries during the
  weekly gap (Friday close → Sunday open).
- News filter (P1 baseline): skip entry if the news_calendar shows a
  HIGH-impact event for any quote currency of the symbol within ±60
  minutes of the entry-bar open.
- Whipsaw guard: after a SL exit, no fresh entries on the same symbol
  until `CMO[t]` revisits zero. This prevents re-entering on the same
  failed breakout.

## Concepts (was ist das für eine Strategie)

- [[concepts/volatility-regime-gate]] — primary (Chande VR > 1.3 as
  trending-regime pre-gate)
- [[concepts/cmo-trend-breakout]] — secondary (CMO ±50 cross trigger)
- [[concepts/trend-following]] — tertiary

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Tushar Chande: 20+ years systematic-research, multiple Wiley publications, named CTA. Stanley Kroll: 40+ year published trader (Wiley 1980s–1990s). *The New Technical Trader* (Wiley 1994) is the canonical reference for both CMO and VR. ForexFactory thread cluster ongoing. R1 PASS expected under 2026-05-15 relaxed criteria. |
| R2 Mechanical | UNKNOWN | Both CMO and VR are closed-form deterministic indicators. Entry gating is two boolean conditions + a bar-direction check + a blow-off filter. Exit is a CMO zero-cross on closed bars. No look-ahead. Entry/SL/TP/time-stop all closed-form. R2 PASS expected. |
| R3 Data Available | UNKNOWN | Both primitives are price-only (no volume). Testable on all FX-majors, XAUUSD, XTIUSD, and Darwinex index CFDs (GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX) on H4. SP500.DWX backtest-only — T_Live promotion requires NDX.DWX or WS30.DWX parallel validation (Board Advisor T_Live-gate enforcement). R3 PASS. |
| R4 ML Forbidden | UNKNOWN | Fixed periods (14, 7, 28, 16). Fixed thresholds (±50, 1.3, 2.0, 1.0, 0.20). No adaptive parameters, no ML, no neural net, no online learning. 1-position-per-magic. No martingale. R4 PASS expected. |

### R3 SP500.DWX live-promotion caveat

Live promotion T_Live gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T_Live deploy requires a
parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
This is Board Advisor's T_Live-gate enforcement, not Research's.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING — drafted by Research from
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 58.

## Verwandte Strategien

- [[strategies/QM5_1801_chande-momentum-oscillator-h4]] — CMO primitive
  un-gated (zero-cross + ±50 breakout). Distinct: 9453 mandates VR>1.3
  trending pre-gate.
- [[strategies/QM5_9404_chande-vr-rsi-mr-composite-h4]] — Complementary
  regime: VR<0.7 consolidation + short-RSI mean-reversion. Together
  9404 + 9453 probe VR-gating as a general-purpose Chande primitive.
- [[strategies/QM5_1800_chande-vidya-cross-h4]] — Chande VIDYA adaptive
  MA primitive.
- [[strategies/QM5_1857_chande-forecast-oscillator-h4]] — Chande FO
  primitive.
- [[strategies/QM5_2135_chande-trendscore-h4]] — Chande TrendScore
  primitive.

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 distinctness audit must verify the CMO+VR composite is
  meaningfully distinct from 1801 (CMO alone). The distinctness rests
  on the mandatory VR>1.3 pre-gate, which Chande explicitly recommends
  in *The New Technical Trader* ch. 6 to filter false breakouts in
  range-bound regimes. If P2 shows 9453 and 1801 producing near-identical
  trade lists, the composite is redundant; if 9453 produces meaningfully
  fewer-but-cleaner trades, VR-gating is validated as a general-purpose
  Chande primitive (in tandem with the complementary 9404 evidence).

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
