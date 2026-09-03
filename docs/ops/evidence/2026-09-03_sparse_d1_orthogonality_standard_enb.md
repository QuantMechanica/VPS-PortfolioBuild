# Orthogonality standard for sparse D1 sleeves — Effective Number of Bets (ENB)

Board-advisor proposal for **Vorlage V4** ("Korrelations-Beweisstandard") of the shadow
book-evaluation dossier (`docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.md`
§3c, §5) and runbook gap **G3** (`docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md`).

- Author: Claude (board-advisor lane), read-only, no commit/push.
- Worktree HEAD: `c032dbb1a50dfab0328aa17d80bad0c548e4ec28` (after `git merge --ff-only agents/board-advisor`: `a92cda60fe` → `c032dbb1a5`).
- Estimator script: `docs/research/2026-09-03_enb_orthogonality_estimator.py` — sha256 `8683db1976eee87cf5df8c05ea25d43eba2ac0dc4463cb3bece3e2ee6334daf7`. NOT added to `tools/`, NOT wired to any gate.
- Status: **evidence-only proposal.** Changes no gate threshold, no verdict, no book, no DB row. The ROT rule (gate thresholds & contract criteria) means only OWNER may ratify a new gate; this is the Vorlage.

---

## 0 · The defect being fixed (measured, not asserted)

`tools/strategy_farm/portfolio/portfolio_correlation.py:88-118` computes a pairwise Pearson
`r` only on days where **both** sleeves closed a trade, and drops any pair with
`overlap < min_overlap_days` (default 60, line 139). `sleeve_correlation.py:119` floors at
30 shared days. For sparse D1 sleeves this fails two ways, both **measured on the real
qualified pool** (`book_build_guard.py --status --venue both` → `qualified_pairs=5`):

- **Overlap floor never clears.** For the 5 qualified pairs at daily frequency the pairwise
  co-active overlap is **min=1, median=10, max=27 days; 0 of 10 pairs reach 60** (estimator
  run, POOL/daily). For the 9 audited members: **min=5, median=14, max=50; 0 of 36 pairs
  reach 60.** Every pair is dropped as `insufficient_overlap`. The tool returns **no**
  usable correlation for the book it is meant to gate.
- **0-fill biases the surviving numbers toward false orthogonality.** Aligning sparse daily
  series over the union window fills ~86% of the pool's day-slots with a structural zero
  (co-activity φ = 0.139: only 91 of 656 active day-slots have ≥2 sleeves active). Those
  zeros enter the standard-deviation denominator but not the cross-product numerator, so the
  correlation estimate is **pulled toward zero mechanically**. Measured signature: the
  aggregate equivalent correlation is **lower at daily (ρ_eq = 0.017) than at monthly
  (ρ_eq = 0.084)** for the same pool — the daily number is the biased one.

The Q15 hard rule (`|r| < 0.5` between any two Q10 equity curves, vault
`03 Pipeline/Q15 Final Portfolio Construction.md`) is therefore **unenforceable as written**
on this sleeve class: the estimator that feeds it produces no admissible pairwise `r`.

---

## 1 · Method (the standard)

Replace the *pairwise-overlap* test with an **aggregate eigen-spectrum** test that needs no
pair to clear a 60-day overlap, then re-express the result on the **same 0–1 correlation
scale** as the ratified `|r| < 0.5` rule so nothing has to be re-benchmarked.

**Object.** The book's daily P&L is the sum of its sleeves' daily P&L. Its diversification is
governed by the eigen-spectrum of the sleeves' daily-return **correlation** matrix — not by
any single pair. A book of `N` sleeves whose correlation matrix has eigenvalues
`λ_1…λ_N` (trace `N`) carries an **effective number of independent bets**

```
ENB_PR = (Σ λ_i)^2 / Σ λ_i^2  =  N^2 / Σ λ_i^2          (participation ratio; PRIMARY)
ENB_H  = exp( − Σ p_i ln p_i ),  p_i = λ_i / Σ λ_j       (Meucci entropy; reported alongside)
```

Both run from 1 (one factor explains everything — a fake book) to `N` (identity — perfectly
orthogonal). `ENB_PR` is primary because it has a closed-form inverse to an equicorrelation,
which lets the bar be *derived* from the existing rule instead of invented.

**Why zeros are kept, not an artifact to be "fixed away".** A day on which a sleeve holds no
position contributes exactly 0 to the book's daily P&L. Two sleeves that never trade the same
day genuinely have zero daily covariance and *do* smooth the book's equity path. So 0-fill is
the economically correct input for the *portfolio-variance* question — which is exactly the
question ENB asks, and exactly the question the deleted pairwise-overlap test could not ask
(it threw those days away). The residual problem is not the zeros; it is **estimation
support**: with few co-active days the off-diagonals are estimated from almost nothing. That
is handled by the trust guards (§4), not by discarding zeros.

**Aggregate equivalent correlation `ρ_eq` — the reportable number.** Invert the
equicorrelation ENB map: `ρ_eq` is the single constant pairwise correlation an `N`-sleeve book
would need to have the *measured* `ENB_PR`. It puts the entire eigen-structure on the ratified
0–1 scale. The standard is then stated identically to the old rule but applied to the whole
book at once:

> **BOOK ORTHOGONAL ⇔ ρ_eq < 0.5**, evaluated on the certifiable frequency, with the trust
> guards of §4 satisfied; else **INSUFFICIENT_EVIDENCE** (never a silent pass).

Because a hidden common factor loading, say, 0.4 on every sleeve passes every pairwise
`|r| < 0.5` check yet collapses `ρ_eq` above 0.5, the aggregate form is **strictly harder to
game** than the pairwise form while using the same threshold.

**Frequency ladder.** Compute at **daily first, then monthly**. Report co-activity φ at each.
Use the coarsest frequency that reaches adequate support (φ, δ guards, §4). `portfolio_common.py`
already ships `to_monthly_pnl` (lines 517-528) for exactly this class ("a few trades per year
⇒ ~0 co-active days, where daily-PnL correlation is statistically empty"). This proposal makes
that fallback a *rule with a trigger*, not an ad-hoc choice.

---

## 2 · Exact estimator (formulas)

Inputs: per sleeve `s`, its Q10/Q08 closed-trade stream. Per-trade P&L = the stream's own
`net` field (worst-case-commission-inclusive, `money_basis=FULL_POSITION_LIFECYCLE_ACTUAL_V1`);
centering removes any constant per-trade offset, so the commission convention is immaterial to
correlation (verified: raw `net` vs `net_of_cost` change no correlation).

1. **Bucket** each trade into its exit-day (UTC) [daily] or exit-month [monthly]; sum `net`
   within a bucket → sparse series `x_s`.
2. **Align** all sleeves on the union of buckets; missing = 0 → matrix `X ∈ ℝ^{n×N}`.
3. **Standardize** each column to zero mean, unit population std → `Z` (drop zero-variance
   columns). Sample correlation `R = Zᵀ Z / n` (unit diagonal).
4. **Ledoit-Wolf shrinkage** (conditioner; two targets reported):
   - *Identity* (Ledoit & Wolf 2004, *J. Multivariate Analysis* 88(2):365-411). With
     `S = Zᵀ Z / n`, `μ = tr(S)/p`, `I` the identity:
     ```
     d² = ‖S − μI‖_F²
     b̄² = (1/n²)( Σ_k ‖z_k‖⁴ − n‖S‖_F² )        # z_k = k-th observation row
     b² = min(b̄², d²);  δ = b²/d²
     Σ̂_ID = δ·μ·I + (1−δ)·S
     ```
   - *Constant-correlation* (Ledoit & Wolf 2003, *J. Empirical Finance* 10(5):603-621).
     Target `F`: `F_ii = S_ii`, `F_ij = r̄ √(S_ii S_jj)`, `r̄` = mean sample correlation.
     ```
     π̂ = Σ_{ij}[ (1/n)Σ_k (z_ki z_kj)² − S_ij² ]
     ρ̂ = Σ_i π̂_ii + Σ_{i≠j} (r̄/2)[ √(S_jj/S_ii)·ϑ_{ii,ij} + √(S_ii/S_jj)·ϑ_{jj,ij} ]
         ϑ_{ii,ij} = (1/n)Σ_k (z_ki² − S_ii)(z_ki z_kj − S_ij)
     γ̂ = ‖F − S‖_F²
     δ = max(0, min(1, ((π̂ − ρ̂)/γ̂)/n))
     Σ̂_CC = δ·F + (1−δ)·S
     ```
     Constant-correlation is the *skeptical* target: it pulls toward the average-pairwise
     structure, so a data-starved set cannot masquerade as orthogonal via shrinkage.
5. **Eigenvalues** `λ_i = eigvalsh(·)`, clip tiny negatives to 0. Compute `ENB_PR`, `ENB_H`,
   and `ρ_eq` (bisection inverse of the equicorrelation map, §1) for **raw `R`**,
   `Σ̂_ID`, and `Σ̂_CC`.

**Primary statistic = raw-`R` `ENB_PR` / `ρ_eq`**, valid because for both real sets
`n ≫ N` (656/848 buckets vs 5/9 sleeves), so classical estimation error is small and the raw
spectrum is well-determined. LW is retained as the conditioner for the regimes where it earns
its place (short windows, larger books where `n ≲ N`), and its intensity **δ is a trust dial**
(§4). This ordering is forced by the data: see the R1 over-shrinkage failure in §5.

**Equicorrelation reference (the non-invented bar).** For an `N×N` equicorrelation matrix with
off-diagonal `ρ`, eigenvalues are `1+(N−1)ρ` once and `1−ρ` with multiplicity `N−1`, so
`ENB_PR(ρ,N) = N² / [ (1+(N−1)ρ)² + (N−1)(1−ρ)² ]`. Evaluated at the ratified ceiling `ρ=0.5`
this is the **derived floor** every book must exceed:

| N | floor `ENB_PR(0.5,N)` | ENB@ρ=0.3 | ENB@ρ=0.2 | ENB@ρ=0.1 |
|---:|---:|---:|---:|---:|
| 5 | 2.500 | 3.676 | 4.310 | 4.808 |
| 9 | 3.000 | 5.233 | 6.818 | 8.333 |
| 10 | 3.077 | 5.525 | 7.353 | 9.174 |
| 25 | 3.571 | 7.911 | 12.755 | 20.161 |

The floor **saturates at 4** as `N→∞` (`1/ρ²` for `ρ=0.5`). That is itself a finding: the
existing pairwise `|r|<0.5` rule, applied to a 25-sleeve book, tolerates a structure with only
**~3.6 effective bets**. Stating the standard as `ρ_eq < 0.5` keeps the ratified number but
closes that hole; a *good* book target (e.g. `ρ_eq ≤ 0.2`, i.e. `ENB_PR ≥ 12.75` at N=25) is
left for OWNER to ratify — this proposal does not invent it.

---

## 3 · Refutation criterion (what proves the standard useless or gamed)

The standard is falsified if it **PASSES** a book that fails any of these. All four are run in
the script; R1/R2 are the decisive ones.

- **R1 — duplicate insensitivity.** Inject an exact copy of an admitted sleeve (same stream,
  relabeled as a second symbol). A perfect duplicate adds a redundant, not a new, bet:
  analytically, adding a copy to `K` orthogonal sleeves gives eigenvalues `{2, 1×(K−1), 0}`,
  so `ENB_PR` must **fall** to `(K+1)²/(K+3)` (e.g. 5→4.5). **If ENB does not fall (or rises),
  the standard is useless** — it cannot see redundancy, the exact thing an author gains by
  relabeling one edge onto two symbols (`11165` on AUDCAD+EURUSD; `10815` on EURUSD+GDAXI).
- **R2 — sparsity inflation.** Feed pairwise temporally-disjoint sleeves (φ≈0). Raw and
  identity-shrunk ENB both go to `N` ("perfect orthogonality") on **zero** joint evidence. **A
  standard that returns PASS here is gamed** by construction: submit ultra-sparse,
  never-co-trading sleeves and claim maximal diversification. The mandatory defense is the φ
  guard → `INSUFFICIENT_EVIDENCE`.
- **R3 — window instability.** If `ρ_eq` on the first vs second half of the common window
  differs materially, the PASS is a window artifact, not structure.
- **R4 — shrinkage dominance.** If δ→1, the shrunk matrix ≈ the target regardless of the data;
  any ENB read off it reflects the prior, not the sleeves. δ near 1 ⇒ do not certify off the
  shrunk matrix.

**Operational reading:** R1–R4 tripping is the standard **working** (it refuses to certify).
The standard is *falsified* only by a PASS that survives none of them. On the real sets (§5)
R2/R4 fire at daily → the honest verdict there is INSUFFICIENT, and certification moves to
monthly, where R1 and R3 both behave.

---

## 4 · Goodhart analysis + the guards that close each hole

| # | Attack (author / optimizer) | Why it beats a naive test | Guard in this standard |
|---|---|---|---|
| G1 | Submit ultra-sparse sleeves that never co-trade | daily `r`→0 by 0-fill, ENB→N | **φ guard** (co-activity fraction) + monthly cross-check; φ below support ⇒ INSUFFICIENT, not PASS (R2) |
| G2 | Relabel one edge onto two symbols / recompile a clone | counted as 2 sleeves, true corr≈1 | **raw eigen-spectrum** ENB falls per R1; family-fingerprint pre-screen (`concentration_tail.family_fingerprints`, already used by `book_build_guard`) |
| G3 | Inflate one sleeve's notional to dominate the spectrum | covariance eigenvalues dominated by it | use **correlation** (standardized), scale-invariant by construction |
| G4 | Cherry-pick a union window minimizing overlap | per-pair windows hide co-movement | **one fixed full-history window** for the whole book (the very per-pair-window bug being removed); report window + R3 stability |
| G5 | Optimizer decorrelates on the in-sample window | in-sample orthogonality is overfit | compute on **Q10 full-history / OOS** streams only (the gate sits at Q15, after Q10/Q14); R3 sub-window stability required |
| G6 | Lean on shrinkage toward identity to lift ENB | identity target biases ENB up toward N | **primary = raw spectrum**; constant-correlation (skeptical) target reported; **δ trust dial**; R4 |
| G7 | Switch return definition (gross/net, MTM vs realized) | pick the lowest-correlation definition | **fixed definition**: `net`, exit-bucketed, from the SHA-pinned stream |

The deepest hole is G1/G6 and it is **live on this pool at daily frequency**: LW-identity
shrinkage there returns ENB = exactly `N` (§5) — a book could bank that as "perfectly
diversified" while having supplied no joint evidence at all. The φ+δ guards and the raw-primary
ordering are what make the standard refuse it.

---

## 5 · Measured results (real streams, cited)

Run: `python docs/research/2026-09-03_enb_orthogonality_estimator.py`. Read-only; no DB write
(proof: `sqlite3 … mode=ro`, `PRAGMA query_only=1`, probe `CREATE TABLE` → *attempt to write a
readonly database*). Stream stores: qualified pool from the **C: `Common\Files`** store that
`portfolio_correlation.py` reads by default (`portfolio_common.DEFAULT_COMMON_DIR`); audited-9
from the **D:** store the dossier cited. Per-file sha256[:16] below.

### 5a · Qualified pool (the real 5, `book_build_guard --venue both`)

Streams (C: `…\MetaQuotes\Terminal\Common\Files\QM\q08_trades`):
`10706_GBPUSD_DWX` `85d7abd4d1cb9ed3` (366 tr) · `11421_EURUSD_DWX` `072b0c82ebdf96e4` (92) ·
`11422_USDCAD_DWX` `539567527f312817` (197) · `13054_XTIUSD_DWX` `261c2de68a544b29` (83) ·
`1537_XAGUSD_DWX` `6b1ae9ee1c6357d0` (22).

| freq | n buckets | φ | pairwise overlap (min/med/max; ≥60) | δ_ID / δ_CC | raw ENB_PR | raw ENB_H | **raw ρ_eq** | floor(0.5,5) | verdict |
|---|---:|---:|---|---|---:|---:|---:|---:|---|
| daily | 656 | 0.139 | 1 / 10 / 27 ; 0/10 | 1.000 / 1.000 | 4.994 | 4.997 | **0.017** | 2.500 | **INSUFFICIENT** (φ low, δ=1) |
| monthly | 99 | 0.919 | 7 / 45 / 81 ; 2/10 | 1.000 / 1.000 | 4.863 | 4.932 | **0.084** | 2.500 | **PASS** (ρ_eq 0.084 < 0.5) |

Union window 2017-10-10…2025-12-30. LW-identity returns ENB = exactly 5.000 at both
frequencies — the G6 inflation, visible. The certifiable (monthly) verdict is **PASS**: the
5-pair pool behaves like 5 sleeves at an equivalent pairwise correlation of **0.084**, versus
the 0.5 ceiling; `ENB_PR = 4.86` of a possible 5.0.

### 5b · Audited-16 cohort — the 9 with streams (dossier §3b, D: store)

`1556_XAUUSD` `b1e84c8a1e8c74f8` · `11132_SP500` `35aef7994a5b8f57` · `11165_AUDCAD`
`46354e14c7ce9a31` · `11165_EURUSD` `e30270fa71a427e5` · `11708_EURUSD` `0fbccdfed14837c8` ·
`11910_NZDUSD` `555bbee205432c62` · `12710_XTIUSD` `c09e9ea0bdeb4d88` · `12778_AUDUSD(basket)`
`276adef910f3eca3` · `12969_USDJPY` `1788388f79e41977`.

| freq | n | φ | overlap (min/med/max; ≥60) | δ_ID / δ_CC | raw ENB_PR | **raw ρ_eq** | floor(0.5,9) | verdict |
|---|---:|---:|---|---|---:|---:|---:|---|
| daily | 848 | 0.307 | 5 / 14 / 50 ; 0/36 | 1.000 / 1.000 | 8.858 | **0.045** | 3.000 | **INSUFFICIENT** |
| monthly | 99 | 0.990 | 20 / 44 / 93 ; 10/36 | 1.000 / 0.919 | 8.031 | **0.123** | 3.000 | **PASS** |

Monthly verdict **PASS**: 9 sleeves at equivalent correlation **0.123** (`ENB_PR = 8.03` of 9).
Note ρ_eq rises daily→monthly (0.045→0.123) — the daily number was **downward-biased by
0-fill**, confirming §0. This 9-set is only a screening prior (the dossier's own caveat):
6 of 9 streams bind to superseded identities, so these are *not* book-grade — the method is
sound, the inputs are not yet.

### 5c · Refutation runs

- **Self-test (known answer):** 4 independent + 1 near-duplicate pair (corr 0.989), n=2000 →
  raw `ENB_PR = 4.519` vs analytic perfect-dup target **4.500**; δ_CC = 0.009. Estimator is
  sensitive and correctly counts the collapsed pair as ~1 bet.
- **R1 duplicate (monthly):** pool raw `ENB_PR 4.863 → 4.407` (Δ **−0.457**, target −0.363 to
  4.500); audited raw `8.031 → 7.600` (Δ **−0.431**). Raw detects redundancy. **Const-corr fails**:
  audited const-corr `8.992 → 9.083` (**+0.090**, δ_CC rose to 0.442) — over-shrinkage *hides*
  the duplicate. This is why the raw spectrum is the primary statistic (§2, G6).
- **R2 disjoint (synthetic φ=0):** raw / identity / const-corr all `ENB_PR = 6.000 = N` on zero
  joint evidence. The φ guard correctly rules this **INSUFFICIENT_EVIDENCE**, not PASS.
- **R3 split-window (monthly, raw):** pool ρ_eq H1 0.131 / H2 0.112; audited H1 0.164 / H2 0.139.
  Stable, both halves ≪ 0.5 → the PASS is not a window artifact.
- **R4:** δ = 1.000 at daily for both sets → daily is non-certifiable off the shrunk matrix,
  as the verdicts already state.

---

## 6 · Minimum data requirements

Reuse the ratified **Aktivitätskriterium** (OWNER 2026-08-20): ≥10 distinct **entry** days per
scored year per sleeve — no new invented per-sleeve number. Add three aggregate gates, whose
**caps are proposed for OWNER ratification against the measured values here**, not asserted:

- **Certification frequency:** the coarsest of {daily, monthly} at which the guards pass; report
  which was used.
- **Co-activity φ:** report; certify only above OWNER's floor. Measured: daily φ = 0.14 (pool) /
  0.31 (audited) are **inadequate**; monthly φ = 0.92 / 0.99 are adequate. A defensible floor
  sits between (e.g. φ ≥ 0.5).
- **Shrinkage intensity δ:** report; do not certify off the shrunk matrix when δ → 1. Measured:
  δ_CC = 1.000 daily (degenerate), 0.919 (audited monthly). The raw spectrum, primary here, is
  unaffected because `n ≫ N`.
- **One fixed full-history window** for the whole book; report `[first,last]` and `n`.

**Data reality check (why inputs, not method, are the blocker).** The min entry-days/year is
below the ratified activity floor in several years for most members
(`11421:EURUSD` has 3 years < 10; `1556:XAUUSD` 4 years; `11165:EURUSD` min 2). Several members
are not yet activity-clean; the ENB standard measures cleanly, but the streams under it are
sparse and mostly bound to superseded identities. The correct next input — not commissioned
here — is **Q14-terminal, hash-bound streams** (dossier V1(b)).

---

## 7 · Recommendation (Vorlage V4)

**Adopt ENB / `ρ_eq < 0.5` as the aggregate orthogonality standard for sparse D1 books**,
computed on the certifiable frequency with the φ/δ/window guards, replacing the unenforceable
per-pair `min_overlap_days=60` Pearson test at Q15. It keeps the ratified 0.5 number, is
strictly harder to game (catches hidden common factors the pairwise test passes), and returns
**INSUFFICIENT_EVIDENCE** rather than a false zero when support is thin. The dossier's
V4 recommendation (b) — *require fresh Q14-terminal streams before any orthogonality claim* —
is **compatible and prior to** this: this standard is the *method*; Q14-terminal bound streams
are the *inputs* it still awaits. Ratifying the standard now (a GELB item: new lever, hypothesis
+ refutation criterion + frequency check + parameter count all supplied) lets the first
Q14-terminal cohort be judged the moment it exists.

Open OWNER knobs (each needs a number OWNER sets, none invented here): the *good-book* target
band on `ρ_eq` (below the 0.5 hard bar), the φ floor, the δ cap, and whether ENB is a Q15 hard
gate or a reported diagnostic beside the retained pairwise rule.
