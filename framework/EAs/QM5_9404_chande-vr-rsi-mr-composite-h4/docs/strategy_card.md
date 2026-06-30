---
ea_id: QM5_9404
slug: chande-vr-rsi-mr-composite-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/volatility-regime-gate]]"
  - "[[concepts/short-rsi-mean-reversion]]"
indicators:
  - "[[indicators/chande-volatility-ratio]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; ForexFactory URL plus Chande & Kroll Wiley 1994 book attribution with verbatim VR formula provide clear lineage."
r2_mechanical: PASS
r2_reasoning: "VR gate, RSI extreme, SMA trend, and ATR-rejection bar conditions are all closed-bar comparisons; RSI-mid revert exit is deterministic."
r3_data_available: PASS
r3_reasoning: "VR and short-RSI primitives are instrument-agnostic; testable on DWX FX-majors, XAUUSD, XTIUSD, and index CFDs on H4."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed periods (ATR 14/50, RSI 3, SMA 200, 8 bars) and thresholds (0.7, 10, 90, 0.4) only; no ML, no PnL-adaptive parameters, one position per magic."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-19
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX]
g0_approval_reasoning: "R1 PASS source URL/book attribution; R2 PASS mechanical H4 VR/RSI/SMA/ATR entry+exit with ~70 trades/year/symbol; R3 PASS DWX FX/CFD testable; R4 PASS fixed rules no ML/martingale 1-pos-per-magic"
---

# Chande VR-Gated Short-RSI Mean-Reversion (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14002100 (ForexFactory
  Trading Systems sub-forum, Chande/Kroll thread cluster, Volatility-Ratio
  sub-thread, posts 2014-2024).
- Author lineage: Tushar Chande & Stanley Kroll — *The New Technical
  Trader* (Wiley 1994, ISBN 0-471-59780-5) ch. 6 "The Volatility Index
  and Volatility Ratio" pp. 113–134 — explicit Volatility Ratio
  formula and the trend-vs-consolidation regime classification.
  Chande's *Beyond Technical Analysis* (Wiley 2001) reproduces the VR
  with the same coefficients. ForexFactory thread cluster discusses
  VR as a regime filter on top of mean-reversion entries.
- This card is a **composite** primitive: Chande VR is the regime
  gate, short-RSI is the entry mechanic. Distinctness vs. the Connors
  RSI family (1505 / 1527 / 1546) rests on the VR mandatory pre-gate
  — Connors uses 2-bar RSI ungated or paired with percent-B; this
  card uses 3-bar RSI gated by VR < 0.7. Distinctness vs. the Chande
  family (1801 CMO, 1910 StochRSI POP, 2135 TrendScore) rests on
  combining two Chande primitives (VR + RSI-applied-mean-reversion)
  rather than using either alone.

## Mechanik

### Chande Volatility Ratio (Chande & Kroll 1994 ch. 6)

For each closed H4 bar `t`:

- `ATR_short[t] = ATR(14)[t]`
- `ATR_long[t]  = ATR(50)[t]`
- `VR[t]        = ATR_short[t] / ATR_long[t]`

Chande's regime classification:
- `VR < 0.7` → **consolidation regime** (mean-reversion favoured)
- `0.7 ≤ VR ≤ 1.3` → **transition** (no signal)
- `VR > 1.3` → **expansion regime** (trend-following favoured)

This card trades **only the consolidation regime** (mean-reversion side).

### Short-RSI mean-reversion entry

Compute `RSI(3, Close)[t]` on closed H4 bars (3-bar RSI — Chande's
recommended fast-RSI period for mean-reversion entries in
ch. 6 p. 124; distinct from Connors' 2-bar variant).

Compute `SMA(Close, 200)[t]` as a long-trend filter.

**LONG mean-reversion entry:**
1. `VR[t]   < 0.7`                          (Chande consolidation gate)
2. `RSI(3)[t]  < 10`                        (deep oversold short-RSI)
3. `Close[t] > SMA(Close, 200)[t]`          (in long-term uptrend)
4. `Close[t] > Low[t]` AND
   `(Close[t] − Low[t]) ≥ 0.4 × ATR(14)`    (bar rejected the low —
   genuine intra-bar dip-buyer activity)

**SHORT mean-reversion entry (mirror):**
1. `VR[t]   < 0.7`
2. `RSI(3)[t]  > 90`
3. `Close[t] < SMA(Close, 200)[t]`
4. `Close[t] < High[t]` AND
   `(High[t] − Close[t]) ≥ 0.4 × ATR(14)`

Entry: next H4 bar's open (market order).

Magic = `9404 * 10000 + slot` (1-position-per-magic, HR4).

### Exit

**Profit target (mechanical — RSI-mid revert, Chande p. 126):**

- For LONG:  exit at the open of the next bar after `RSI(3) > 50`.
- For SHORT: exit at the open of the next bar after `RSI(3) < 50`.

**Time stop:** if RSI-revert exit does not fire within 8 closed H4 bars
after entry, exit at market on bar 9's close.

### Stop Loss

- For LONG:  `SL = Low[t_trigger]  − 0.4·ATR(14)`.
- For SHORT: `SL = High[t_trigger] + 0.4·ATR(14)`.

`t_trigger` = bar that produced the RSI-extreme + VR-gate trigger.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD (HR4).
- Live: `RISK_PERCENT = 0.5%` of equity at entry (HR4).

### Zusätzliche Filter

- Spread filter: skip if current spread > `0.20·ATR(14)`.
- Time filter: H4 bars only; no intra-bar entries; no entries during the
  weekly gap.
- News filter (P1 baseline): skip entry if the news_calendar shows a
  HIGH-impact event for any quote currency of the symbol within ±60
  minutes of the entry-bar open.
- One signal per direction at a time. While LONG, ignore further LONG
  triggers until the position closes.

## Concepts (was ist das für eine Strategie)

- [[concepts/volatility-regime-gate]] — primary (Chande VR consolidation
  gate is the distinctness primitive)
- [[concepts/short-rsi-mean-reversion]] — secondary (entry mechanic)
- [[concepts/trend-aligned-mean-reversion]] — tertiary (200-SMA aligns
  fade with longer-term trend)

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Tushar Chande & Stanley Kroll: published authors, *The New Technical Trader* (Wiley 1994) is canonical reference. VR formula and consolidation/expansion classification published verbatim. R1 PASS expected. |
| R2 Mechanical | UNKNOWN | All rules reduce to closed-bar comparisons on ATR + RSI + SMA primitives — all native MT5. VR-gate, RSI-extreme, SMA-trend, ATR-rejection all closed-form. R2 PASS expected. |
| R3 Data Available | UNKNOWN | VR and short-RSI primitives are instrument-agnostic. Testable on all FX-majors, XAUUSD, XTIUSD, Darwinex index CFDs on H4. SP500.DWX backtest-only — T6 live promotion requires NDX.DWX or WS30.DWX parallel validation. R3 PASS. |
| R4 ML Forbidden | UNKNOWN | Fixed periods (14, 50, 3, 200, 8), fixed thresholds (0.7, 10, 90, 50, 0.4). No adaptive parameters, no ML, no online learning. 1-position-per-magic. No martingale. R4 PASS expected. |

### R3 SP500.DWX live-promotion caveat

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation
on NDX.DWX or WS30.DWX before AutoTrading enable. This is Board Advisor's
T6-gate enforcement, not Research's.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING — drafted by Research from
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 57.

## Verwandte Strategien

- [[strategies/QM5_1505_connors-cumulative-rsi-h4]] — Connors RSI
  mean-reversion family; this card differs by mandatory Chande VR
  pre-gate and 3-bar RSI (vs. Connors 2-bar / cumulative).
- [[strategies/QM5_1527_connors-crsi-composite-h4]] — Connors composite;
  same distinctness comment.
- [[strategies/QM5_1801_chande-momentum-oscillator-h4]] — Chande family,
  CMO entry primitive (distinct from VR-gated RSI).
- [[strategies/QM5_1910_chande-stochastic-rsi-pop-h4]] — Chande family,
  StochRSI-POP entry primitive.
- [[strategies/QM5_2135_chande-trendscore-h4]] — Chande family,
  TrendScore composite primitive.

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 distinctness audit must compare the VR-gate signal
  stream against Connors-cumulative-RSI on H4 DWX data — the gate
  must produce a materially different trigger distribution; if it
  doesn't, this card collapses to a Connors-variant and should be
  REJECTed as duplicate. The composite distinctness is the entire
  point of this card.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
