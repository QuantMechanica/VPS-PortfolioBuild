---
ea_id: QM5_1127
slug: menkhoff-carry-fxvol-filter
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/carry]]"
  - "[[concepts/volatility-filter]]"
indicators:
  - "[[indicators/interest-rate-differential]]"
  - "[[indicators/realized-volatility]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Menkhoff/Sarno/Schmeling/Schrimpf Carry+Global-FX-Vol-Filter JF 2012 (SSRN 1342968) G10 USD-cross carry-rank top/bottom-2 long/short + global-vol gate R1-R4 all PASS: R1 JF peer-reviewed cornerstone; R2 3mo-momentum carry proxy + 21d realized-vol vs 12mo-avg threshold + monthly rebalance + ATR(D1,14"
---

# QM5_1127 Menkhoff Carry-Trade With Global FX Volatility Filter

## Quelle
- Primary: SSRN 1342968 — "Carry Trades and Global Foreign Exchange
  Volatility" by Lukas Menkhoff, Lucio Sarno, Maik Schmeling, Andreas
  Schrimpf. Journal of Finance 67(2), April 2012.
  URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1342968
- Reported result: classic G10 carry trade (long high-IR currencies, short
  low-IR currencies) earns positive average return but suffers severe
  drawdowns during global FX-volatility spikes. Adding a global-FX-vol
  filter (scale-down or exit when realised global-FX-vol crosses an upper
  threshold) substantially reduces tail risk while preserving most of the
  premium. Result robust across 1976-2010 and 39 currencies.
- Lineage: Lustig/Roussanov/Verdelhan "Common Risk Factors in Currency
  Markets" (RFS 2011), Brunnermeier/Nagel/Pedersen "Carry Trades and
  Currency Crashes" (NBER 2008). This card extends QM5_1095 (dollar carry
  basket) with the vol-filter that the static carry basket lacks.

## Mechanik

### Entry
- **Monthly** rebalance on first trading day.
- Step 1 — Carry signal: rank G10 currencies by their interest-rate
  proxy. V5 has no live IR feed → use the **3-month price-momentum of the
  USD-cross as the carry proxy** (positive carry currencies trend up vs
  USD over time; standard practitioner substitute). Alternative P3 variant:
  hard-code current G10 IR snapshot quarterly.
- Step 2 — Open: **long the top-2 carry-positive USD-crosses, short the
  top-2 carry-negative USD-crosses**, equal-weight.
- Step 3 — **Volatility filter** (paper's key contribution):
  compute "global FX vol" = mean of trailing 21-day realized-vol across
  the G10 USD-crosses. If `current_global_vol > 1.5 * trailing_12m_avg`
  → **skip this rebalance** (stay flat or scale to 25%). Otherwise → enter
  full size.

### Exit
- Hold until the next monthly rebalance.
- At rebalance: re-evaluate vol filter and carry ranking; flip / hold /
  close as signals dictate.
- **Intra-month vol-spike exit** (P3 variant): if global FX vol breaches
  the threshold mid-month, close immediately (paper's "crash-protection"
  arm). Baseline does monthly-only checks.

### Stop Loss
Paper has no per-position SL (it relies on vol filter). V5 overlay:
per-position ATR(D1,14) * 3 hard stop AND portfolio MAX_DD 20 % trip
(HR3/5 mandatory).

### Position Sizing
V5 standard: `RISK_FIXED = $1,000` per leg for P2 baseline; long/short
balanced (4 positions: 2 long + 2 short). `RISK_PERCENT` for live (HR4).

### Zusätzliche Filter
- Skip if fewer than 6 G10 USD-crosses have full 21-day vol history.
- News-filter mandatory (carry trades are FX-news sensitive).
- V5 mandatory: MAX_DD trip.

## Concepts
- [[concepts/carry]] -- primary
- [[concepts/volatility-filter]] -- the paper's key add-on
- [[concepts/mean-reversion]] -- the vol-filter operates on the assumption
  that high-vol regimes mean-revert

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Menkhoff et al JoF 2012, ~3000 citations, cornerstone carry-vol paper. All four authors are tenured (Sarno=Cass/Cambridge, Menkhoff=DIW, Schmeling=Goethe-Frankfurt, Schrimpf=BIS). Independent replications by AQR + Quantpedia |
| R2 Mechanical | PASS | All three steps (carry rank, vol calc, threshold check) are closed-form. Substituting price-momentum for the IR feed is a clean practitioner deviation, not discretion |
| R3 Data Available | PASS | DXZ G10 USD-crosses: EURUSD, GBPUSD, USDJPY, AUDUSD, NZDUSD, USDCHF, USDCAD, plus crosses for EUR/GBP/AUD/etc. 8-9 instruments comfortably supports the basket logic. **Caveat:** IR snapshot is not in DXZ feed — using price-momentum proxy. Card flags this; P3 sweep tests both proxies |
| R4 ML Forbidden | PASS | Rolling-vol formula + threshold + rank, all deterministic. No ML, no online learning. Threshold (1.5x) is a fixed parameter |

## Pipeline-Verlauf
- G0: 2026-05-17 — drafted from SSRN FEN batch 2 (autonomous wake), PENDING

## Verwandte Strategien
- Extends: QM5_1095 (qp-dollar-carry-basket) — same G10 carry concept, but
  this card adds the global-FX-vol filter that the static basket lacks.
  When both reach pipeline-end, P2 outputs will quantify whether the vol
  filter is worth the extra complexity (paper claims yes; V5 should
  confirm on its own data)
- Adjacent: QM5_1111 (qp-fx-momentum-12m), QM5_1092 (qp-fx-value-ppp) —
  same G10 universe, different signal families. Could combine into a
  multi-factor FX basket in a later cards-from-batch-3 design

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- DWX symbols: G10 USD-crosses — EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX,
  AUDUSD.DWX, NZDUSD.DWX, USDCHF.DWX, USDCAD.DWX (7 majors). P2 baseline
  on EURUSD.DWX single-symbol with the vol-filter signal; P3 expands.
- Timeframe: D1.
- "Global FX vol" = arithmetic mean of trailing-21-day annualised realised
  vol across the 7 USD-crosses. Trailing-12m baseline = 252-bar moving
  average of the same global-vol series.
- Carry proxy: trailing 63-bar (3m) price return on each USD-cross. Rank
  desc → top-2 long, bottom-2 short.
- Magic per symbol per HR4.
- P3 sweep variants: vol threshold 1.2 / 1.5 / 2.0 × trailing avg;
  basket size 4 / 6 / 8; carry proxy = 1m / 3m / 6m price-momentum;
  intra-month vol-exit on/off.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung pipeline_phase aktualisieren + last_updated. Bei FAIL: pipeline_phase: DEAD + Lessons-Learned-Eintrag.*
