# Q08 — Davey Statistical Validation

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q08 |
| **Makrophase** | 1 · Strategie beweist sich (Phasenabschluss → eingefrorene, target-neutrale Baseline) |
| **v3-Herkunft** | Q08 (Davey Statistical Validation) — ID unverändert |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q07 Multi-Seed]] · → [[Q09 Baseline Full Run]] |

**Herkunft:** v4 Q08 = v3 Q08 (Davey Statistical Validation), ID, 11 Sub-Gates und Schwellen unverändert (ROT). Die hash-gebundene Full-History-Baseline aus Q08 ist die wiederverwendbare Evidenzquelle für v4 Q09 (Baseline Full Run). In-Text-Verweise auf Gates Q09–Q16 sind bereits auf die v4-Nummerierung aktualisiert; Mapping siehe [[Gate Manifest v4 Diff]].

---

**Gate Owner:** Pipeline-Op (automated)
**Data window:** Full history 2017 → present
**Spec version:** 2026-05-23 (post-rewrite)

**Hard gate.** All 11 sub-gates are evaluated. A clean PASS tolerates soft signals (`EDGE_SOFT`) **only** from the non-merit sub-gates **8.4 / 8.6 / 8.10 / 8.11** — they measure single-EA robustness across seasons / trade-order / ATR-regime that the Q10 anti-correlation portfolio absorbs by diversification (DL-082 §3c, OWNER 2026-07-16, ratified 2026-07-19; `aggregate.py` `ALLOWANCE_SOFT_GATES`). A soft signal on any merit sub-gate (e.g. 8.7 PBO fallback, 8.8 edge-decay) routes the EA to the Q10 portfolio track as FAIL_SOFT, not a PASS. The **DL-072 cost-cushion gate** additionally applies (cushion = gross / realistic cost: **≥ 2.0 PASS**, **1.0–2.0 EDGE_SOFT**; OWNER-ratified 2026-06-09).

---

## Purpose

Q08 is the statistical end-validation before an EA goes to the OWNER-owned phases (Q15+). The 11 sub-gates collectively answer:

- Is the measured performance statistically significant or backtest-overfit?
- Is the edge real or luck-dependent?
- Does it survive when we attack it from 11 different statistical angles?

Reference: Kevin Davey's research on 2,000+ strategies showing that EAs passing the Chopping Block sub-gate (8.6) perform 25-30% better in real-time deployment than those that don't.

---

## All 11 Sub-Gates

### 8.1 Correlation vs Existing Portfolio
**Criterion:** Pairwise |r| **< 0.50** against every EA currently in Q15+ status.
**Why:** A new EA that correlates highly with an existing one adds no diversification.
**Implementation:** Pearson correlation of daily P&L series, full history overlap.

### 8.2 Deflated Sharpe Ratio + Monte Carlo + FDR
**Criterion:**
- Tier 1 (Core): DSR p **< 0.05**
- Tier 2 (Watchlist): Benjamini-Hochberg FDR pass (controls family-wise error across all 369+ strategies tested)
**Why:** Raw Sharpe is inflated by multiple-testing bias. DSR adjusts for the fact that we've tested many strategies.

### 8.3 Tail Dependence
**Criterion:** Correlation with portfolio under top/bottom 5% market moves must be **≤ baseline pairwise correlation** (no extra correlation in tails).
**Why:** Portfolio diversification fails if assets correlate strongly when crises hit. We want EAs that decouple in extreme moves.

### 8.4 Seasonal
**Criterion:** **All 12 calendar months net profit > 0** over full history (averaged across years).
**Why:** Eliminates hidden calendar anomalies — an EA that loses money every August is fragile to seasonal regime shifts.

### 8.5 Neighborhood Stability
**Criterion:** ±10% perturbation of each Q03-chosen parameter must keep PF > 1.0 AND DD < 1.5× baseline.
**Why:** Confirms the EA sits on a robust parameter plateau, not a sharp peak that real-world execution will slip off.

### 8.6 Chopping Block (Davey)
**Criterion:** Remove the top 5% most profitable trades → recomputed **PF > 1.0**.
**Why:** Davey's signature test. Eliminates luck-dependence from a few outlier-good trades. EAs that pass this consistently outperform real-time.

### 8.7 PBO (Probability of Backtest Overfitting)
**Criterion:** PBO **< 0.40** via CSCV (Combinatorially Symmetric Cross-Validation, López de Prado & Bailey 2014).
**Why:** Quantifies the probability that the in-sample performance ranking will reverse out-of-sample. High PBO = the EA's ranking is noise.

### 8.8 Edge Decay
**Criterion:** Rolling 12-month PF decline **< 40%** over the full backtest period.
**Why:** Detects dying edges (e.g. PF 2.5 in 2017 collapsing to 1.1 in 2025). An EA whose edge is fading is not a candidate for forward deployment.
**Implementation:** Sliding 12-month windows; track PF time series; compute (PF_recent_year - PF_first_year) / PF_first_year.

### 8.9 Runs Test (Wald-Wolfowitz)
**Criterion:**
- Wald-Wolfowitz runs test on win/loss sequence: **p > 0.05** (no significant clustering)
- Profit concentration: top 20% of months must account for **≤ 70%** of total profit
**Why:** Trade outcomes should look approximately random per Wald-Wolfowitz; profit shouldn't depend on a handful of huge months.

### 8.10 Regime + Crisis (informational)
**Criterion (hard):** Profitable in **all 3 ATR regimes** (low / normal / high volatility classification).
**Criterion (informational):** Crisis-slice performance reported per applicable slice (COVID-2020, SNB-2015, Ukraine-2022, GFC-2008, China-deval-2015, Inflation-2022) — **never blocks Q08**. Surfaced in EA detail page.
**Why:** Three-regime test enforces robustness across volatility states. Crisis slices give qualitative insight without false-failing EAs that don't trade affected instruments.

### 8.11 Monte-Carlo Shuffle Drawdown (soft-only)
**Criterion:** Preserve the realized trade outcomes, shuffle their order without replacement (1000 permutations), and compare the 95th-percentile shuffled max drawdown to the realized max DD and the 10% capital floor. A soft signal here is within the non-merit allowance (see hard-gate note) and never blocks a PASS.
**Why:** Trade *sequence* luck — a benign realized equity path can hide a fragile ordering. Shuffling the same outcomes exposes tail drawdowns the single realized order happened to avoid.

---

## Sub-Gate Pass Summary Table

| # | Sub-gate | Hard threshold | Block if FAIL? |
|---|---|---|---|
| 8.1 | Correlation vs portfolio | \|r\| < 0.50 | YES |
| 8.2 | DSR + MC + FDR | p < 0.05 OR FDR PASS | YES |
| 8.3 | Tail Dependence | tail corr ≤ baseline | YES |
| 8.4 | Seasonal | 12/12 months profitable | YES |
| 8.5 | Neighborhood Stability | PF > 1.0, DD < 1.5× under ±10% perturbation | YES |
| 8.6 | **Chopping Block** | PF > 1.0 after removing top 5% | YES |
| 8.7 | PBO | < 0.40 | YES |
| 8.8 | Edge Decay | 12m PF decline < 40% | YES |
| 8.9 | Runs Test | p > 0.05 AND top-20% months ≤ 70% profit | YES |
| 8.10 | Regime + Crisis | 3/3 ATR regimes profitable (hard) + crisis informational | YES (regimes) / NO (crisis) |
| 8.11 | MC Shuffle Drawdown | 95th-pct shuffled DD vs realized DD + 10% floor | NO (non-merit allowance) |

---

## Code Modules

| Sub-gate | Module |
|---|---|
| 8.1 | `framework/scripts/q08_davey/sub_8_1_correlation.py` |
| 8.2 | `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py` |
| 8.3 | `framework/scripts/q08_davey/sub_8_3_tail_dependence.py` |
| 8.4 | `framework/scripts/q08_davey/sub_8_4_seasonal.py` |
| 8.5 | `framework/scripts/q08_davey/sub_8_5_neighborhood.py` |
| 8.6 | `framework/scripts/q08_davey/sub_8_6_chopping_block.py` |
| 8.7 | `framework/scripts/q08_davey/sub_8_7_pbo.py` (wraps existing `pbo_calculator.py`) |
| 8.8 | `framework/scripts/q08_davey/sub_8_8_edge_decay.py` |
| 8.9 | `framework/scripts/q08_davey/sub_8_9_runs_test.py` |
| 8.10 | `framework/scripts/q08_davey/sub_8_10_regime_crisis.py` (absorbs old crisis slice runner) |
| 8.11 | `framework/scripts/q08_davey/sub_8_11_mc_shuffle_dd.py` |
| Aggregator | `framework/scripts/q08_davey/aggregate.py` — runs all 11 sub-gates, emits combined verdict |

---

## What Q08 explicitly does NOT do

- ❌ Allow any sub-gate to be skipped "because the EA is otherwise strong"
- ❌ Average across sub-gates (binary AND, not weighted score)
- ❌ Use synthetic / proxy data (Q05/Q06/Q07 are the noise-injection gates; Q08 uses real trade history only)

---

## Workflow

1. Pipeline-Op reads Q07 PASS list per EA.
2. For each (EA, symbol), the Q08 aggregator runs all 11 sub-gates in sequence.
3. Per-sub-gate verdict is recorded with full numeric evidence.
4. Combined Q08 verdict = AND of all merit sub-gates (soft signals from the non-merit allowance 8.4/8.6/8.10/8.11 do not block; see hard-gate note).
5. Output:
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q08/<symbol>/8_<N>_<name>.json` (one per sub-gate)
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q08/<symbol>/aggregate.json` (combined verdict)
   - `D:/QM/reports/pipeline/QM5_<NNNN>/Q08/report.csv` (per-symbol AND verdict)

→ Runtime: `framework/scripts/q08_davey/` (Aggregation: `aggregate.py`)

---

## Dashboard Display

The Q08 row in the EA detail page expands to show an 11-row checklist:

```
Q08 · NDX.DWX · 8/11 PASS  (FAIL)
  ✓ 8.1  Correlation vs portfolio          |r|=0.12   < 0.50
  ✓ 8.2  DSR + MC + FDR                    p=0.018    < 0.05
  ✓ 8.3  Tail Dependence                   tail=0.08  ≤ 0.12 baseline
  ✗ 8.4  Seasonal                          Aug=$-180  (must be > 0)
  ✓ 8.5  Neighborhood Stability            ±10% PF=1.22, DD=1.3×
  ✓ 8.6  Chopping Block                    PF=1.18 after -5%
  ✓ 8.7  PBO                               0.31       < 0.40
  ✗ 8.8  Edge Decay                        -52% over backtest
  ✓ 8.9  Runs Test                         p=0.21, top-20%=63%
  ✗ 8.10 Regime + Crisis                   ATR-high regime PF=0.84
  ✓ 8.11 MC Shuffle Drawdown               95th-pct DD=14% < 10% floor OK
```

Every sub-gate is shown with its actual measured value and threshold. No black-box "FAIL" with no reason.

---

## After Q08 PASS

- Symbol advances to Q09 Baseline Full Run (Phase 2). Die eingefrorene, hash-gebundene Full-History-Baseline aus Q08 ist dort die wiederverwendbare Evidenzquelle (sonst ein Baseline-Lauf).

## After Q08 FAIL

- Symbol removed from the EA's active universe.
- The specific failing sub-gates are recorded — they're the most actionable diagnostic the pipeline produces.
- If a sub-gate FAIL pattern repeats across many EAs (e.g. everyone fails 8.8 Edge Decay), that's a research-direction signal worth a decision record.
