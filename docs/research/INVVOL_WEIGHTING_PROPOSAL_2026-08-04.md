# Inverse-Vol Weighting for the DXZ Book — Proposal (AWAITING OWNER DECISION)

Date: 2026-08-04 · Author: Claude · Status: **PROPOSED** — no live change is part
of this document. Mandate: OWNER-ratified long-term plan 2026-08-03 ("Gewichtung
= billigster Hebel", package due before the 2026-08-24 probation review).
Doctrine: gates decide WHO is in the book; inverse-vol decides HOW MUCH
(weighting roadmap 2026-07-18).

## Data substrate

Stage-1 extraction (Codex ticket 2f5a7926, APPROVED 2026-08-04):
`D:/QM/reports/portfolio/invvol_stage1_20260804/` — 23/24 deployed sleeves as a
uniform 2,348-weekday panel (2017-01-01..2025-12-31) of daily EUR returns at
RISK_FIXED-1000 normalization, from SHA-bound native Q10 full-history reports;
live fills kept as a separate overlay; QM5_10440 fail-closed (no extractable
lineage) and excluded here as well.

## Method

- Weight per sleeve ∝ 1/ann-vol, normalized to the median sleeve, **clamped to
  [0.5, 3.0]**× the equal unit, then renormalized so the weight sum stays at 23
  units (aggregate deployed risk unchanged).
- Comparison frame: portfolios scaled to EQUAL annualized vol (Darwinex
  re-levers the Darwin to target VaR, so the risk-adjusted profile is what an
  investor receives; lever 1.98× for the clamped inverse-vol book).
- Correlation discipline check (DL-083): 253 pairs — only 2 with |c|>0.15
  (max +0.295, both XAU pairs), **none** >0.40. Inverse-vol does not need a
  correlation adjustment on this book; revisit if new correlated sleeves enter.

## Evidence

Full-sample (2017–2025, weights from the whole panel, vol-normalized):

| Book | Total (EUR) | Max DD | Ret/DD | Ret/Vol |
|---|---|---|---|---|
| Equal (status quo) | 457,006 | 36,639 | 12.47 | 17.07 |
| Inverse-vol clamped | 546,822 | 30,128 | **18.15** | **20.42** |

**Walk-forward (no look-ahead): weights re-formed each January from the prior
year's vol only, applied out-of-sample 2018–2025:**

| Book | Total | Max DD | Ret/DD | Years won (ret/DD) |
|---|---|---|---|---|
| Equal | 451,819 | 36,639 | 12.33 | 1/8 |
| Inverse-vol WF | 539,589 | 32,517 | **16.59** | **7/8** |

Per-year: IV wins 2018, 2019 (flips the equal book's negative year positive),
2020, 2021, 2023, 2024, 2025; loses only 2022 narrowly (5.75 vs 6.05).
Artifacts: `stage2_summary.json`, `yearly_robustness.csv`,
`walkforward_weights_by_year.csv`, `live_weights_2026_formation2025.csv` in
`D:/QM/reports/portfolio/invvol_stage2_20260804/`.

## Proposed live weights (formation = 2025 trailing vol, clamp [0.5, 3.0])

Range 0.37–2.21× the equal unit after renormalization; 4 high-vol sleeves at
the floor (10706/GBPUSD, 10911/GDAXI, 13213/USDJPY, 13301/GDAXI), 2 ultra-low-vol
sleeves at the cap (13128/NDX, 1556/XAUUSD). Full table:
`live_weights_2026_formation2025.csv`. Reweighting cadence: annually each
January (walk-forward-validated); no intra-year chasing.

## Implementation path (NOT executed with this proposal)

1. OWNER ratifies weights + cadence.
2. Translate weights to per-sleeve `RISK_PERCENT` in the live set files
   (`gen_setfile.ps1` inputs), keeping book-aggregate risk at the current level.
3. T_Live apply is a full OWNER ceremony: deploy manifest, SHA256 verification,
   set-file ENV/risk-mode check, decision record under `decisions/` — per the
   Hard Rules (T_Live = OWNER + Claude only).

## Caveats

- Substrate is Q10 backtest dailies, not live fills (live overlay exists but is
  only weeks old; 08-02 deploy). The backtest lineage is the same evidence class
  the gates certify.
- Zero-filled no-trade weekdays understate vol for sparse sleeves in per-trade
  terms; the clamp caps the resulting per-trade size increase at 3× (in
  practice 2.21×).
- Floored sleeves keep half a unit — retiring them instead is a Q11 portfolio
  decision, not a weighting decision, and is out of scope here.
- 2019 remains the stress year in both variants; the improvement there comes
  from downweighting the GBPUSD/GDAXI vol cluster, not from any single sleeve.

## Decision ask

Ratify: (a) clamped inverse-vol weights per the 2026 table, (b) annual January
reweighting, (c) scheduling of the T_Live set-file ceremony before 2026-08-24.
