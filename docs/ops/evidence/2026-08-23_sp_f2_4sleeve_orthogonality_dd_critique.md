# SP-F2 — 4-Sleeve Orthogonality + DD-Aggregation Critique (Claude's own)

Date: 2026-08-23

Router task: `2c253b65-2ca6-47fc-91d0-1b9b01aa8738` (`SP-F2`, priority 40,
zone GELB). Depends on `SP-F1` (`cb771748-c85d-4819-87c7-98535ab0c047`,
closed `PARTIAL`); the pieces SP-F2 needs (the 5 EA IDs and their measured
trade streams) are independent of SP-F1's own blocker (the missing 10-of-13
Blueprint rows — SP-F2's 5 EA IDs are given directly in its own payload), so
this proceeds on those inputs directly rather than waiting on an unrelated
gap.

## Verdict

**Two of the four proposed pillars are structurally too sparse to satisfy
QM's own ratified activity criterion, in every single measured year. The
orthogonality claim is real but the "<3.2% combined DD" claim is a
razor-thin pass that depends on it. The "+10-14%/60d" claim is not
defensible: no 60-calendar-day window in the full available backtest
history reaches even the low end of that range.**

## Method

Read the canonical per-trade JSONL streams under
`D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\` for the 5 named EAs,
using the repo's own `read_stream()`/`classify()` functions from
`tools/strategy_farm/portfolio/audit_activity_criterion.py` (the same
parser and the same ratified entry-day activity criterion already used
company-wide — not a new methodology invented for this critique). All 5
streams use `RISK_FIXED` $1000/trade backtest sizing, so their `net` P&L
fields are directly dollar-comparable without re-normalization. Aggregated
against a **$100,000 reference capital** (the same convention
`build_book_ftmo.py --starting-capital` already defaults to) to express
drawdown and 60-day returns as percentages. Full history used:
2017-10-10 through 2025-12-30 (span dictated by the sparsest/longest
sleeve).

## Per-sleeve density and activity — this is the finding

| Sleeve | Symbol | Trades | Span (yrs) | Trades/yr | ≥25/yr? | Entry-days/yr basis | Years below 10 entry-days |
|---|---|---:|---:|---:|:---:|:---:|---|
| Gold | QM5_10145 / XAUUSD | 306 | 7.84 | 39.0 | PASS | meets every year | none |
| USDJPY | QM5_12969 / USDJPY | 300 | 8.22 | 36.5 | PASS | meets every year | none |
| EURGBP | QM5_13117 / EURGBP | 208 | 7.65 | 27.2 | PASS | 1 weak year | 2020 |
| **Oil** | **QM5_10919 / XTIUSD** | **28** | **7.42** | **3.8** | **FAIL** | **fails every year** | **2018,2019,2020,2021,2022,2023,2024,2025 (all 8)** |
| **Tech** | **QM5_13128 / NDX** | **57** | **7.21** | **7.9** | **FAIL** | **fails every year** | **2018,2019,2020,2021,2022,2023,2024,2025 (all 8)** |

This directly confirms and quantifies the task's own hard_constraint flag
("10919 zeigt nur ~30 Trades gesamt — Dichte pruefen"): QM5_10919 has 28
trades across **27 distinct entry days in 7.4 years** — not "close to the
floor," genuinely and severely below it in every one of the 8 measured
years. QM5_13128 is the same story at a slightly higher (still failing)
rate. The proposed "Oel+Tech" pillar is not one moderately-active sleeve —
it is **two structurally low-frequency EAs, neither of which individually
meets the ratified ≥10-entry-day/year Aktivitaetskriterium (OWNER
2026-08-20) even once**, blended together. Blending two under-active EAs
does not manufacture activity; it produces a pillar whose "activity" figure
would need to be evaluated on the union of their entry days, which is still
sparse (see correlation caveat below — the same sparsity that makes them
individually fail the activity floor also makes their correlation
measurement with anything else statistically weak).

## Orthogonality — real, but the low-frequency legs' correlation numbers are weak evidence

Full pairwise daily-P&L Pearson correlation (`docs/ops/evidence/2026-08-23_sp_f2_sleeve_correlation_matrix.csv`):
every pair among the 5 EAs is within **±0.05** of zero — genuinely no linear
relationship detected on a daily basis. The hard_constraint's specific
worries are addressed directly:

- **EURGBP (13117) vs USDJPY (12969), "beide FX":** correlation **+0.040** —
  negligible, despite both being FX pairs. Not a shared-currency artifact in
  this sample.
- **Oil (10919) vs Tech (13128), "Oel vs Tech":** correlation **-0.008** —
  negligible.
- 4-sleeve view with Oil+Tech pre-blended into one series: still all
  pairwise correlations within ±0.04 of zero against Gold, USDJPY, EURGBP.

**Caveat that must travel with this result:** for Oil (27 entry days) and
Tech (57 entry days) against a ~2,850-day union calendar, the correlation
coefficient is computed mostly over "0 vs 0" non-trading days. That
mechanically pulls any such pair's correlation toward zero *regardless of
the true relationship on the rare days both are active* — it is weak
evidence of genuine diversification, not strong evidence, for exactly the
same reason these two sleeves fail the activity floor. The Gold vs USDJPY
correlation (both dense, 300+ trades) is the one pairing in this set where
"orthogonal" is a well-supported claim rather than a sparsity artifact.

## Aggregated DD — technically under the claimed ceiling, but by a thin margin that the diversification story only partly explains

| Measure | Max DD (% of $100k) | Trough date |
|---|---:|---|
| Gold (10145) standalone | 3.82% | 2022-10-21 |
| USDJPY (12969) standalone | 1.32% | 2025-09-05 |
| EURGBP (13117) standalone | 2.16% | 2022-09-26 |
| Oil (10919) standalone | 1.12% | 2023-09-19 |
| Tech (13128) standalone | 0.89% | 2021-06-16 |
| Oil+Tech sub-combination | 1.05% | 2023-09-20 |
| **All 5 combined, equal-weight** | **3.17%** | **2022-11-02** |

The combined figure (**3.17%**) is technically **under** the claimed 3.2%
ceiling — but by only 0.03 percentage points, and Gold's own **standalone**
worst drawdown (3.82%, trough 2022-10-21) is **larger** than the claimed
combined ceiling. The combined trough (2022-11-02) lands 12 days after
Gold's own trough — i.e. the portfolio's worst period **overlaps
Gold's own crisis window**, not a period where Gold is quiet. Adding four
more sleeves only pulled the drawdown down from 3.82% to 3.17% during that
window (a 0.65pp cushion) — a real but modest diversification benefit, not
the kind of comfortable margin "<3.2%" implies on its face. This claim is
**defensible as measured, but fragile**: a slightly different accounting
convention (weighting, correlation window, or one more losing Gold trade
inside that exact 12-day gap) would flip it above 3.2%. It should not be
presented to OWNER as a robust structural result.

## The "+10-14%/60d" return claim — not defensible

Scanned every observed trading day as a 60-calendar-day rolling window start
across the full combined 5-sleeve equity curve (2017-2025, ~2,000+ windows):

- **Best 60-day window observed: +6.34%** (on $100k reference capital).
- **Worst 60-day window observed: -3.45%**.

**No 60-day window in the entire backtest history reaches the claimed
10-14% range** — the best historical result is less than half the low end
of the claim. Either the claim uses a different capital base / leverage
assumption than this RISK_FIXED $1000/trade backtest convention (in which
case that assumption needs to be stated explicitly, since it is not free —
it changes the DD claim too), or the claim is not supported by the same
measured evidence the DD claim relies on. Recommend this be treated as
**REFUTED as stated** until the Blueprint's own return-calculation
convention is produced and reconciled against this measurement.

## Summary judgment (Claude's own)

1. **Orthogonality**: largely holds for the two dense sleeves (Gold,
   USDJPY); weakly supported (not strongly refuted) for the two sparse ones
   (Oil, Tech) because sparsity itself, not demonstrated independence, is
   doing most of the work in their low correlation numbers.
2. **Combined DD <3.2%**: true as measured, but a thin, fragile pass that
   partially depends on Gold's own worst drawdown window, not a comfortable
   diversified margin.
3. **Density/activity**: Oil (10919) and Tech (13128) both fail the
   company's own ratified activity criterion in every single measured year,
   and both fail the ≥25 trades/year density reference. The "Oel+Tech"
   pillar as proposed is built from two sleeves that would not individually
   clear the bar this company already applies elsewhere.
4. **+10-14%/60d**: not supported by any historical 60-day window in the
   measured data; the best window is under 6.4%.

This is a critique, not a book-formation decision, per the task's own
hard_constraint ("Claude-eigene Kritik", implicitly "kein Buch-Bildung"
matching `SP-F1`/`SP-F3`'s explicit wording). No work item, pipeline
verdict, or live state was changed.

## Evidence

- `docs/ops/evidence/2026-08-23_sp_f2_sleeve_correlation_matrix.csv` (full
  5-EA pairwise + 4-sleeve Oil+Tech-blended correlation matrix).
- Source streams: `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\{10145_XAUUSD_DWX,12969_USDJPY_DWX,13117_EURGBP_DWX,10919_XTIUSD_DWX,13128_NDX_DWX}.jsonl`.
- Reused parser/criterion: `tools/strategy_farm/portfolio/audit_activity_criterion.py` (`read_stream`, `classify`).
- Reference capital convention: `tools/strategy_farm/portfolio/build_book_ftmo.py:437` (`starting_capital: float = 100_000.0`).
