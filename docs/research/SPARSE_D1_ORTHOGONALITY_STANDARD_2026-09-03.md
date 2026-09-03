# Sparse-D1 Orthogonality Standard (Q15 supplement) — 2026-09-03

**Scope.** Answers Book-Ceremony runbook gap **G3** and OWNER Vorlage **V4** (correlation
evidence standard): how to judge orthogonality between two EA×symbol Q10/Q14 equity curves
when the streams are **sparse daily (D1) sleeves** — a handful of trades per year, multi-day
holds, and almost no coincident exit days — for which the current tool is structurally blind.

**Authority boundary.** This document adopts an *estimator and a decision-rule shape*; it does
**not** set gate thresholds. Gate thresholds and contract criteria are ROT (Stehende Vollmacht
2026-08-20). Every numeric threshold below is either (i) an existing OWNER-facing constant quoted
from a source `file:line`, (ii) a published-method constant with citation, or (iii) a *proposed*
default explicitly marked "OWNER-ratify" and never asserted as decided. No threshold is invented.

**Merge / provenance.** Worktree fast-forwarded `agents/board-advisor`: `a92cda60fe` →
**`d0367451a2`** (ff-only, no merge commit). Cited source files (sha256[:16], this HEAD):

| file | sha256[:16] |
|---|---|
| `tools/strategy_farm/portfolio/portfolio_correlation.py` | `ec0a890b49502c5e` |
| `tools/strategy_farm/portfolio/portfolio_common.py` | `905bc2a4a71fb94d` |
| `tools/strategy_farm/portfolio/build_book_ftmo.py` | `31d0e81509cd6609` |
| `tools/strategy_farm/book_build_guard.py` | `8c11e369f19852af` |
| `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` | `e903e472feaf4bd4` |
| `docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.md` | `3d28b6927b0c0477` |

---

## 1 · The defect being fixed (confirmed against source at this HEAD)

The Q15 hard rule (vault `03 Pipeline/Q15 Final Portfolio Construction.md`, quoted in runbook
line 213): **|r| < 0.5 between any two EAs' Q10 equity curves.** The tool that is supposed to
measure it fails on this cadence in two independent ways, both read directly from source:

1. **Both-nonzero conditioning (selection-on-outcome).** `portfolio_correlation.py:102-106`
   keeps only calendar days where **both** sleeves closed a trade (`left_value != 0.0 and
   right_value != 0.0`) before Pearson. Conditioning the correlation on joint activity biases
   |r| upward and, for sparse sleeves, leaves 2–20 day samples = pure noise.
2. **Hard 60-day floor → silent drop (fail-open by omission).** `portfolio_correlation.py:44`
   (`min_overlap_days: int = 60`) and `:108` (`if overlap < min_overlap_days: … value = None`)
   return `None` and append the pair to `insufficient_overlap`. A pair that returns `None` is
   **not evaluated** by the |r|<0.5 control — so an author who fires on days incumbents are flat
   gets a **free pass into the book**. The control is fail-**open** exactly where it should bite.

Two supporting facts, also from source:

- **Exit-day bucketing.** `portfolio_common.py:509-513` (`to_daily_pnl`) buckets each trade's
  net-of-cost P&L on `trade.time` — the **close/exit** stamp (rows are `TRADE_CLOSED`,
  `_load_one_stream` at `:550`, trade construction from `:571`). Daily-P&L co-movement therefore only "sees" a sleeve on its exit
  days, blind to the many days it holds an open position.
- **Union-window zero-fill.** `align` (`portfolio_common.py:531-548`) unions all dates
  (`dates = sorted({day for series in …})`) and zero-fills a dense matrix. Pre-birth / post-death
  days of a not-yet-existing sleeve become fabricated structural zeros that dilute |r| toward 0.

**An in-tree partial attempt already exists:** `to_monthly_pnl` (`portfolio_common.py:527-528`)
whose own docstring says daily correlation is "statistically empty" for "a few trades per year".
Monthly buckets are a cruder fix (they still bucket on exit time and throw away all within-month
resolution); the standard below supersedes that path.

**Measured consequence (dossier §3c, sha `3d28b6…`, independently citable):** across the 9
audited streams that have data, **every** pair fails the 60-day floor — the largest co-active
(both-exit) overlap is **50 days** (`1556/XAUUSD × 12710/XTIUSD`); max 0-filled |r| = **0.102**
(`11910/NZDUSD × 1556/XAUUSD`); no pair reaches |r| ≥ 0.3. The tool returns a usable correlation
for **0** book-relevant pairs.

---

## 2 · Adopted standard — a two-layer, fail-closed screen

The two proposals map exactly onto runbook G3's own menu ("trade-level co-activity, block
bootstrap, or ENB on returns", line 335). They are **not** competitors: each proposal explicitly
states it *supplements* the Q15 |r|<0.5 rule and does not replace the separate family-fingerprint
and tail-concentration caps. The judge panel split 1–1 — the statistical-validity lens ranked
**ZK-SBB 8 > COS 7** (COS wins its exact null but on a *surrogate* estimand; its own headline
shows Λ=8.61 co-occupancy at Pearson r≈0.001), the Goodhart lens ranked **COS 8 > ZK-SBB 7**
(COS's position-open observable is immune to exit-timing games and catches same-EA/two-symbol
redundancy that daily-r certifies as orthogonal). The synthesis keeps **both**, each in the role
its own weakness assigns it:

- **Layer A — primary certifier: ZK-SBB** (Zeros-Kept daily-return Pearson + stationary
  block-bootstrap CI). Chosen as primary because its estimand is **identical to the Q15 hard-rule
  object** (daily-return correlation of the equity curves) and its decision on the **CI upper
  bound with fail-closed abstain** is the statistically honest treatment of thin data — thin
  evidence produces *abstention*, never certification.
- **Layer B — mandatory supplementary flag: COS** (trade-level open-position co-occupancy +
  exact circular-shift null). Chosen as a *flag, not a certifier*, because its estimand is a
  **surrogate** (time-in-market ≠ return co-movement). It is kept because it sees two things Layer
  A is structurally blind to on this cadence: **(i)** same-EA / same-family redundancy that
  daily-r certifies orthogonal (both judges cite the same-EA r≈0.004 case), and **(ii)**
  **held-but-unexited co-exposure** — the exit-day P&L basis shared by *both the tool and Layer A*
  cannot see a position that is open (and co-directional) on an incumbent's active day but has not
  yet closed.

### 2.1 · Layer A — ZK-SBB (primary; the Q15 estimand)

Let `x_t, y_t` = daily net-of-cost P&L (from `to_daily_pnl`, `portfolio_common.py:509`, unchanged
commission handling) of sleeves A,B on business day `t = 1..n`, where the day grid is the
**exogenous Mon–Fri business-day set over the common-support window** `[max(first_A,first_B) ..
min(last_A,last_B)]` (the *intersection* of each stream's own `[first,last]`, **not** the union).
Non-trade days are real zeros (kept). This simultaneously removes both source defects: no
both-nonzero subsetting, and no pre-birth/post-death padding.

**Point estimate (Pearson, zeros kept):**

```
r_hat = Σ_t (x_t − x̄)(y_t − ȳ) / sqrt( Σ_t (x_t − x̄)² · Σ_t (y_t − ȳ)² )
```

**Uncertainty (the deliverable): stationary block bootstrap** (Politis & Romano 1994). Resample
the **paired** vector `(x_t, y_t)` in geometric-length blocks (restart prob `p = 1/b` each step,
else advance circularly), recompute `r` on each of `B` replicates, take the 2.5/97.5 percentiles
→ `[r_lo, r_hi]`. Report `|r|_upper = max(|r_lo|, |r_hi|)`. Block length `b` auto-selected by
Politis & White 2004 (flat-top kernel) with the Patton–Politis–White 2009 stationary-bootstrap
variance constant, taken as `b = max(b_x, b_y, b_{x·y})` (longer block ⇒ more preserved serial
dependence ⇒ wider, more conservative CI). `B` and the RNG seed are reported constants, not gate
criteria.

**Layer-A verdict (fail-closed):** `CERTIFY_A` iff the CI `(r_lo, r_hi) ⊂ (−0.5, +0.5)` — the
Q15 hard rule, also the code default `WORKING_DEFAULT_MAX_PAIRWISE_CORRELATION = 0.50`
(`build_book_ftmo.py:70`). Otherwise **`ABSTAIN`** (treat as potentially correlated; require more
Q14-terminal overlap). Data starvation manifests automatically as a CI too wide to clear ±0.5.

### 2.2 · Layer B — COS (supplementary co-timing flag)

Each trade carries `entry_time` and `time` (exit), both unix-UTC (schema:
`portfolio_common.py:55` for `entry_time`, `:52` for `notional`, `:550`+ for the loader).
A sleeve's **occupancy set** `D_s` is the union over its trades of every UTC calendar day from
`entry_day..exit_day` inclusive. On a common calendar-day ring `d_1..d_T` (every day in
`[min entry, max exit]` across the pool — assumption-free, no market-calendar model), let
`o_s ∈ {0,1}^T`, `o_s[i]=1 ⇔ d_i ∈ D_s`, `n_s = Σ_i o_s[i]`.

```
Observed co-occupancy:  O_ab   = Σ_i o_a[i]·o_b[i]
Expected (indep. mean): E_ab   = n_a·n_b / T                    (exact mean of the shift null)
Co-activity LIFT:       Λ_ab   = O_ab / E_ab = O_ab·T/(n_a·n_b) (1 = chance, >1 = clustered)
```

**Exact circular-shift null (all T rotations)** — rigid rotation exactly preserves each sleeve's
in-market count and its run-length (holding-period) multiset, destroying only cross-sleeve phase:

```
O_ab(δ) = Σ_i o_a[i]·o_b[(i−δ) mod T],  δ = 0..T−1   (computed exactly by FFT circular
                                                       cross-correlation; no Monte-Carlo error)
p_upper = #{δ : O_ab(δ) ≥ O_ab} / T                  (≥ 1/T; Phipson & Smyth 2010 add-one)
```

Multiplicity: Benjamini–Hochberg 1995 FDR across the `C(n,2)` `p_upper` values.

**Signed refinement (same-instrument pairs only, undefined cross-symbol):** with `notional` and
`side`, `δ_s(d) = sign(Σ_{trades open on d} sign(side)·notional)`, and
`Ψ_ab = ( #{d: δ_a=δ_b} − #{d: δ_a=−δ_b} ) / O_ab` — `+1` = same-direction stacking (dangerous),
`−1` = hedged. Reported only when co-occupied same-instrument days `O_ab ≥ 20`, else `N/A` (never
guessed).

**Layer-B flag:** `FLAG_B` iff the pair shows **significant excess simultaneity** (BH-adjusted
`p_upper ≤ α` **and** `Λ_ab > λ*`) **and**, where defined, `Ψ_ab` indicates same-direction
stacking. `α`, `λ*` are OWNER-ratify (§4). COS is **untestable** (report `UNTESTABLE_SATURATION`,
route to Layer A) when a sleeve occupies a large fraction of the ring (`E_ab → n_a`, `Λ → 1`
mechanically).

### 2.3 · Combined decision rule (fail-closed)

For a pair with **< 60 co-active exit-days** (the regime where `portfolio_correlation.py` returns
`None`):

| Layer A (CI ⊂ ±0.5?) | Layer B (FLAG_B?) | verdict |
|---|---|---|
| CERTIFY_A | not flagged | **CERTIFY_ORTHOGONAL** (screening prior — see §7) |
| CERTIFY_A | FLAG_B | **REVIEW** (temporally concentrated / redundant despite low daily-r; escalate to family/tail caps) |
| ABSTAIN | any | **ABSTAIN** (not admitted; needs more Q14-terminal overlap) |
| A untestable **and** B untestable | — | **ABSTAIN** |

For a pair with **≥ 60 co-active exit-days**, the incumbent **Pearson |r| < 0.5** on the
zeros-kept common-support window (Vault Q15, `build_book_ftmo.py:70`) is the **decisive** test and
Layer B is advisory only. The two layers are the *sparse-regime screen below the floor*; they do
not override the equity-curve rule where the data supports it.

**Separation of concerns (unchanged, kept explicit):** COS/ZK-SBB is a co-*timing* / co-*return*
screen. Cross-symbol economic correlation (oil↔USDCAD, EUR↔GBP), signal-family redundancy, and
tail co-crash clustering remain the job of the **already-implemented** aggregate controls —
`select_under_aggregate_control` (`build_book_ftmo.py:181`, pairwise-corr + cluster reject +
account-wide risk budget) plus the family≤3 / symbol≤2 caps — never this statistical screen.

---

## 3 · What changes in `portfolio_correlation.py` (design only — not implemented here)

Read-only task; no code was modified. Current behavior anchored by `file:line`:

1. **Do not silent-drop below the floor.** Replace the `value = None` branch
   (`portfolio_correlation.py:108-110`) with a structured per-pair record carrying an explicit
   verdict (`CERTIFY_ORTHOGONAL | REVIEW | ABSTAIN | UNTESTABLE`). A missing correlation must be a
   **fail-closed ABSTAIN**, never an omission that the book guard reads as "no constraint".
2. **Zeros-kept, common-support window.** Remove the both-nonzero subset
   (`portfolio_correlation.py:102-106`); for each pair compute Layer A on the Mon–Fri business-day
   grid over the **intersection** window, not the union grid produced by `align`
   (`portfolio_common.py:531-548`). This is a per-pair windowing pass on top of the existing
   loader, leaving `align` intact for the dense/legacy path.
3. **Add the occupancy series for Layer B.** Derive `o_s` from `entry_time..time`
   (`entry_time` already loaded, `portfolio_common.py:55`); keep `to_daily_pnl`
   (`portfolio_common.py:509`) for Layer A. Both series come from the same `Trade` list — no new
   data source.
4. **Emit both layers per pair:** `{co_active_exit_days, layer_a:{r_hat, ci_lo, ci_hi, b_block,
   verdict}, layer_b:{lambda, p_upper, bh_reject, psi|null, testable}, verdict}` — superseding the
   scalar `correlation|None` matrix (`portfolio_correlation.py:94`, `:115-116`).
5. **Thresholds parameterized + OWNER-tagged.** `α`, `λ*`, the caution band, `B`, and the seed
   are CLI/config parameters carrying `WORKING_DEFAULT_OPEN_OWNER_ITEM` status, mirroring
   `build_book_ftmo.py:70-71` and `:291` — never hard-coded as gate criteria.

Estimand-of-record note: Layer A **is** the current tool's estimand done correctly (daily-return
Pearson), so it can live inside `correlation_matrix`; Layer B is an additive diagnostic column.

---

## 4 · Decision rule as OWNER Vorlage V4 (options / recommendation / cost-of-wait)

**V4 — Correlation evidence standard for sparse D1 streams** (supersedes runbook V4, lines
209-213, which offered only (a)/(b)):

- **(a) Status quo** — accept the current sparse-stream Pearson as a screening prior.
  *Consequence:* `portfolio_correlation.py` returns a usable correlation for 0/46 book-relevant pairs (`None` for all 46) (dossier
  §3c); the |r|<0.5 control is **fail-open by omission**. **Reject.**
- **(b) Defer** — require fresh Q14-terminal streams with **≥ 60-day overlap** before any
  orthogonality claim (dossier §3c Rec (b)). *Consequence:* correct as a gold standard, but
  **structurally unsatisfiable for this cadence** — a pair that merely passes the ratified activity
  criterion (≥10 distinct entry days/scored year, CLAUDE.md) yields an expected *exit*-overlap of
  only ≈ n_a·n_b/T ≈ 80·80/3000 ≈ 2 days, never 60. Option (b) permanently defers the control for
  slow D1 sleeves.
- **(c) Adopt the two-layer sparse-D1 standard (§2)** — Layer A (ZK-SBB) certifies on the Q15
  estimand with fail-closed abstain; Layer B (COS) flags co-timing/redundancy; Pearson |r|<0.5
  remains decisive **above** 60 co-active exit-days. **RECOMMENDED.**

**Recommendation: (c), with (b) as the standing gold standard it supplements — not replaces.**
Option (c) is precisely what makes the *already-ratified* activity criterion produce a *testable*
orthogonality signal: the same activity that yields ≈2 expected co-active exit-days (killing
Pearson) yields ≈150 occupancy days ⇒ E_ab ≈ 150·150/3000 ≈ 7.5 co-occupied days (COS-testable),
and enough kept-zero business days for a Layer-A CI. (c) is the interim screen; (b) is the
decisive test whenever a Q14-terminal cohort finally yields ≥60-overlap bound streams.

**Ratify the *method* now; defer the *numbers* to first calibration.** The method (zeros-kept
common-support Pearson + block-bootstrap CI + circular-shift co-activity + fail-closed abstain) is
a design choice inside GRÜN/GELB. The numeric thresholds are ROT and should be set on the first
**SHA-frozen Q14-terminal cohort**, not on today's superseded streams. Proposed defaults for that
ratification (options, not decisions):

| threshold | proposed default | basis |
|---|---|---|
| Layer A gate | CI ⊂ (−0.5, +0.5) | Vault Q15 hard rule = `build_book_ftmo.py:70` |
| Layer A caution band | `|r|_upper` within 0.05 of 0.5 → PROVISIONAL | proposal-supplied; re-measure |
| Layer B `α` | 0.05 with BH-FDR | Benjamini–Hochberg 1995 |
| Layer B `λ*` | 1.5 (50% excess time-in-market) | proposal-supplied |
| COS testability floor | E_ab ≥ 5 and n_a,n_b ≥ 30 occupancy days | proposal-measured power boundary (§5) |
| Signed layer report floor | O_ab ≥ 20 same-instrument co-days | proposal-supplied |
| Bootstrap | B = 4000, seed reported | proposal-supplied (Politis–Romano 1994) |

**Cost of waiting.** **Low today** — the binding gate is the 25-floor (dossier §2:
`qualified_pairs = 5, allowed = false`, reasons `5 < 25` + `owner_order_missing`), so no book is
buildable and the correlation control is not yet on the critical path. **But** the cost is
front-loaded: if V4 is left at (a)/(b), then the moment the Q14 census reaches 25 the orthogonality
control is *still* fail-open-by-omission (option a) or *still* unsatisfiable (option b), and Q15
stalls on an unusable control at the worst possible time. Ratifying the method now (numbers later)
costs nothing today and removes that future stall.

---

## 5 · Refutation criterion (executable checks on the same streams)

The standard is **refuted** (proven useless or gamed) by any of the following. Each is a check on
the identical stream set; the parenthetical is the outcome the proposal authors report (self-
reported — see §7 provenance caveat).

1. **No discrimination (decisive).** If the screen cannot separate a *known-correlated* pair from
   a *known-independent* one it is useless. Built-in positive control: the **same EA on two
   symbols** (dossier §1f "count as ~1 edge"). Layer B must FLAG it and Layer A's daily-r may
   legitimately not. *(Reported: 11165:AUDCAD × 11165:EURUSD → COS Λ=1.90, p=0.0013, BH-reject;
   Pearson both-nonzero r=−0.015 / 0-filled r=+0.002 both miss it.)* **Refuted if the control comes
   back not-significant on both layers.**
2. **Benign-reparam sensitivity.** If a verdict flips under a change that alters no economic
   exposure (calendar-day vs weekday ring; ±1 day on the occupancy interval; enumeration
   granularity), the threshold sits on noise. **Refuted if the decision sign is not invariant.**
   *(Specified; the weekday-vs-calendar rerun is noted as not-yet-run — a prerequisite before
   ratification.)*
3. **Occupancy saturation.** If a sleeve occupies a large ring fraction, Λ→1 mechanically and COS
   loses power; such sleeves must be declared `UNTESTABLE_SATURATION` and routed to Layer A.
   **Refuted if a book is ever admitted on co-activity passes that are all saturation artifacts.**
   *(Reported occupancy fractions 1.8%–20%, max 12969:USDJPY 20% — far from saturation today.)*
4. **P&L / CI cross-check.** If two sleeves pass Layer B (temporally orthogonal) yet their
   realized P&L on shared days is strongly same-signed, or if a Layer-A CERTIFY later realizes
   |r| ≥ 0.5 out-of-sample on fresh SHA-bound Q14-terminal streams, the screen missed the risk.
   **Refuted for that pair; fall back to abstain-below-adequate-overlap.** This is why the whole
   thing is a *screening prior* (§7), not a certification.
5. **Layer-A honesty controls.** Negative control (circular-rotation null must not produce
   false positives above nominal) and positive control (identity r=1 must be rejected; a graded
   partial-clone must show monotone rising reject-rate). *(Reported: rotation-null worst
   |r|_97.5 = 0.0755, false-positive rate 0.000; identity rejected; power curve reject 0.00→0.56
   as shared days k = 2→50.)* **Refuted if the negative control is anti-conservative or the power
   curve is flat.**

---

## 6 · Minimum data (derived, not invented)

- **Layer A adequacy is self-calibrating**, tied to the single external number (Q15's 0.5): a pair
  is certifiable only when its block-bootstrap 95% CI clears ±0.5. Starvation → CI too wide →
  ABSTAIN automatically. Empirically (proposal-reported) adequacy sets in around **m ≥ 8–12
  co-active days** for near-zero pairs, but heavy-tailed pairs stay wide even at higher m
  (`1556/XAUUSD × 12710/XTIUSD`: m=50 yet |r|_upper≈0.274) — which is why the decision rides the
  CI, not a day count.
- **Layer B power boundary (proposal-measured):** every pair with **E_ab ≥ 5 and n_a, n_b ≥ 30
  occupancy days** was testable and detected Λ ≥ 1.5 at p < 0.05; the only underpowered pairs
  involved `1537/XAGUSD` (22 trades, occ-frac 1.8%). Proposed minimum: **E_ab ≥ 5 and n_a,n_b ≥ 30
  occupancy days**; below it mark `UNTESTABLE` and require a longer stream or fall back to Layer A.
- **Signed refinement:** report Ψ only when same-instrument co-occupied days **O_ab ≥ 20**.
- **Tie to the ratified activity criterion (key property):** a sleeve passing the criterion (≥10
  distinct entry days per scored year, entry-day basis, CLAUDE.md) accumulates ≈150–600 occupancy
  days over the ~8-year window, so against any similarly-qualified partner E_ab ≈ 7.5 ≥ 5 ⇒
  **Layer-B-testable**, while the same activity yields only ≈2 expected co-active *exit* days ⇒
  Pearson-on-exit-days **structurally empty**. The activity criterion therefore *guarantees*
  co-activity testability while leaving the exit-day floor unreachable — the quantitative case for
  adopting the sparse standard.

---

## 7 · Measured results on the real pool

**Two tiers of evidence, kept strictly separate.**

### 7a · Independently verifiable (from repo files at this HEAD)

Pipeline-failure facts, quoted from the dossier (`3d28b6…`, itself read-only-DB-sourced) and the
source files — these reproduce the G3/V4 premise and are the load-bearing part of the case:

| fact | value | source |
|---|---|---|
| min_overlap_days floor | 60 (default) | `portfolio_correlation.py:44` |
| both-nonzero subset before Pearson | present | `portfolio_correlation.py:102-106` |
| below-floor behavior | `value = None`, appended to `insufficient_overlap` | `portfolio_correlation.py:108-110` |
| exit-day bucketing | `trade.time` (close) | `portfolio_common.py:509-513` |
| union-window zero-fill | present | `portfolio_common.py:531-548` |
| Q15 pairwise default | `WORKING_DEFAULT_MAX_PAIRWISE_CORRELATION = 0.50` | `build_book_ftmo.py:70` |
| max co-active (exit) overlap, 9 audited streams | **50 days** (`1556/XAU × 12710/XTI`) | dossier §3c |
| max 0-filled |r|, audited | **0.102** (`11910/NZD × 1556/XAU`); no pair ≥ 0.3 | dossier §3c |
| pairs reaching the 60-day floor | **0** of all book-relevant pairs | dossier §3c |
| union window (9 streams) | 2017-10-10 … 2025-12-30 | dossier §3a |
| audited members with a stream | 9 of 16 | dossier §3b |
| streams binding to current binary | 3 of 9 (`1556, 11708, 12969`) | dossier §3b/§3c |
| qualified pool (book guard, this session) | `qualified_pairs=5, allowed=false` (`5<25` + `owner_order_missing`) | dossier §2 |
| qualified pair identities | `10706/GBPUSD, 11421/EURUSD, 11422/USDCAD, 13054/XTIUSD, 1537/XAGUSD` | dossier §2 |

Per-stream stats (dossier §3b, sha256[:16] of each `.jsonl`):

| member | trades | active days | first | last | net (USD) | binding | sha16 |
|---|---:|---:|---|---|---:|---|---|
| 1556/XAUUSD | 53 | 53 | 2019-02-01 | 2025-12-05 | 6619.1 | representative | b1e84c8a1e8c74f8 |
| 11132/SP500 | 73 | 73 | 2019-05-10 | 2025-12-23 | 6919.9 | superseded (set) | 35aef7994a5b8f57 |
| 11165/AUDCAD | 181 | 181 | 2017-10-19 | 2025-12-05 | 2143.1 | superseded (set) | 46354e14c7ce9a31 |
| 11165/EURUSD | 223 | 220 | 2017-11-20 | 2025-12-17 | 761.4 | superseded (set) | e30270fa71a427e5 |
| 11708/EURUSD | 173 | 166 | 2018-06-08 | 2025-12-05 | 2607.6 | representative | 0fbccdfed14837c8 |
| 11910/NZDUSD | 63 | 63 | 2018-03-23 | 2025-06-05 | 2509.5 | superseded (ex5+set) | 92c51571583c99de |
| 12710/XTIUSD | 82 | 82 | 2018-10-05 | 2025-12-05 | 7579.5 | superseded (unbound) | c09e9ea0bdeb4d88 |
| 12778/AUDUSD·EURJPY | 210 | 105 | 2018-05-04 | 2025-11-28 | 4502.8 | superseded (unbound) | 276adef910f3eca3 |
| 12969/USDJPY | 300 | 300 | 2017-10-10 | 2025-12-30 | 10848.6 | representative | 1788388f79e41977 |

### 7b · Proposal-reported estimator output — NOT independently reproduced

**Provenance caveat (binding).** Both proposals cite estimator scripts and result JSONs
(`docs/research/2026-09-03_sparse_coactivity_orthogonality_{probe.py,results.json}` for COS;
`docs/ops/evidence/2026-09-03_sparse_d1_orthogonality_{estimator.py,results.json}` for ZK-SBB).
**All four files are absent from the worktree** (verified `ls` 2026-09-03 at HEAD `d0367451a2`).
The numbers below are therefore **self-reported by the proposal authors and have not been
re-executed here.** They are recorded for the OWNER decision as *claimed* results; before
ratification (§4) the estimator must be re-run in-tree on SHA-frozen Q14-terminal streams and the
scripts committed. Do not treat 7b as measured evidence in the sense the Hard Rules require.

Layer B (COS) — audited set (9 sleeves / 36 pairs), proposal-reported:

| pair | Λ | O (co-days) | p_upper | note |
|---|---:|---:|---:|---|
| 11165:AUDCAD × 11165:EURUSD | 1.90 | 64 | 0.0013 | positive control (same EA); BH-reject; Pearson misses |
| 12710:XTIUSD × 1556:XAUUSD | 8.61 | 216 | 0.0003 | headline hidden concentration; Pearson r≈0.001 |
| 11165:EURUSD × 11708:EURUSD | 1.86 | (n=72) | 0.0013 | Ψ = −0.75 (75% net opposite = hedged) |
| audited summary | Λ 0.84–8.61 | — | 24/36 p<0.05 | 36/36 testable; 18 survive BH-FDR@0.05 |

Layer B (COS) — qualified pool (5 sleeves / 10 pairs), proposal-reported: 8/10 testable (2
underpowered, both involving `1537/XAGUSD`, 22 trades); Λ 0.79–1.82; 2 pairs p<0.05
(`13054:XTIUSD × 11422:USDCAD` Λ=1.67 p=0.008; `13054:XTIUSD × 11421:EURUSD` Λ=1.66 p=0.037);
**0 survive BH-FDR** → the current 5-pair census is acceptably co-orthogonal today, with one
economically-real watch-flag (oil sleeve 13054 co-times with USD-FX, strongest with oil-linked
USDCAD).

Layer A (ZK-SBB), proposal-reported: qualified pool 10/10 certify (point |r| 0.003–0.104); the one
fragile pair `11421:EURUSD × 1537:XAGUSD` (co-active=2, CI=[−0.46,+0.28], |r|_upper=0.465) falls
in the caution band → **ABSTAIN**. Audited 36/36 certify (max co-active 50). Negative control
(rotation null, 36 pairs) worst |r|_97.5 = 0.0755, false-positive 0.000; identity r=1 rejected;
power curve reject 0.00→0.56 for k=2..50; same-EA `11165` AUDCAD/EUR r=0.0039 (certifies — proving
daily-r ≠ family redundancy, the reason Layer B is mandatory).

**Headline:** the current tool returns 0 usable correlations for all book-relevant pairs; the
adopted standard returns a verdict for every one — certifying the co-orthogonal, abstaining on the
single data-starved pair, and flagging the same-EA / commodity-cluster co-timing that daily-r
alone certifies as orthogonal.

---

## 8 · Explicit provenance ledger — every number and where it comes from

**Verified in-tree (repo file / dossier at HEAD `d0367451a2`):**

- `60` (floor), both-nonzero subset, `None`-drop → `portfolio_correlation.py:44, 102-106, 108-110`.
- exit-time bucketing → `portfolio_common.py:509-513`; union zero-fill → `:531-548`; `entry_time`
  schema → `:55`; `notional` → `:51`; `to_monthly_pnl` existing partial fix → `:517-528`.
- `0.50` Q15 pairwise default + `WORKING_DEFAULT_OPEN_OWNER_ITEM` → `build_book_ftmo.py:70-71, 291`;
  `select_under_aggregate_control` → `:181`.
- `max overlap 50`, `max |r| 0.102`, `0 pairs ≥ 60`, `union 2017-10-10..2025-12-30`, `9/16 streams`,
  `3/9 bind`, per-stream table, `qualified_pairs=5 allowed=false`, 5-pair identities → dossier
  (`3d28b6927b0c0477`) §2, §3a, §3b, §3c.
- runbook G3 text, V4 options → `BOOK_CEREMONY_RUNBOOK_2026-09.md:209-213, 332-336`.
- merge SHAs `a92cda60fe → d0367451a2` → `git merge --ff-only` this session.
- absence of the four cited estimator/result files → `ls` this session.

**Published-method constants (cited, not invented):** Politis & Romano 1994 (stationary block
bootstrap); Politis & White 2004 + Patton–Politis–White 2009 (automatic block length); Phipson &
Smyth 2010 (add-one exact-permutation p-floor); Benjamini–Hochberg 1995 (FDR).

**Proposed defaults, marked OWNER-ratify (NOT decided here):** `α=0.05`, `λ*=1.5`, caution band
0.05, `E_ab≥5 & n_s≥30`, `O_ab≥20`, `B=4000` — all in the §4 table, sourced to the proposals.

**Self-reported by proposals, NOT re-executed (§7b):** all Λ, p_upper, Ψ, CI, |r|_upper,
false-positive-rate, power-curve, and ENB figures. Estimator scripts + result JSONs absent from
tree; must be re-run on SHA-frozen Q14-terminal streams before ratification.

---

## 9 · Limitations

1. **Screening prior, not book-grade proof.** Layer A on today's streams rests on ≤50 co-active
   days and 6/9 audited streams bind to superseded identities (dossier §3c); the qualified-pool
   streams live in the mutable `Common\Files` export, not a frozen bundle. All §7b numbers are a
   screening prior on streams-as-they-exist-today; adoption for a real book requires re-measuring
   on SHA-frozen Q14-terminal streams (which the Goodhart defense also requires).
2. **Construct gap of Layer A.** Daily-return r does not see signal-family redundancy (same-EA
   r≈0.004) or tail co-crash clustering — hence Layer B is mandatory and the family≤3/symbol≤2 and
   tail-concentration caps remain separate, non-statistical controls.
3. **Construct gap of Layer B.** Co-occupancy is a surrogate for drawdown-clustering, not the
   Q15 return-correlation object; its own headline (Λ=8.61 at Pearson r≈0.001) shows the gap. It
   is a flag, never a certifier.
4. **Cross-symbol sign undefined** without an FX/asset factor model; the signed layer fires only
   on same-instrument pairs. Cross-symbol economic correlation stays with the concentration caps +
   a currency-exposure overlay.
5. **Thresholds are ROT.** `α`, `λ*`, caution band and testability floors are proposed, not set;
   OWNER ratifies on the first calibration cohort.
6. **Not yet run:** the weekday-vs-calendar-ring robustness rerun (refutation #2) and the in-tree
   re-execution of both estimators. Both are prerequisites before this standard is treated as
   measured evidence rather than a synthesized design.

---
*Author: Claude (Orchestrator). Read-only synthesis; no code, gate, verdict, stream, queue, or
book state changed. Sidecar: `docs/research/SPARSE_D1_ORTHOGONALITY_STANDARD_2026-09-03.json`.*

## CEO verification notes (2026-09-03 16:50Z, workflow wf_18ea64f8-b1c)

Adversarial verifier: could not refute the standard; every Tier-1 number
recomputed exactly from the cited streams. Corrections applied above: the
option (a) sentence now reads "usable correlation for 0/46 pairs" (46 =
36 audited C(9,2) + 10 qualified C(5,2)); notional field cited at
portfolio_common.py:52; _load_one_stream at :550. The proposal artefacts
the synthesis cites (estimator scripts and result JSONs) are now in-tree:
docs/research/2026-09-03_sparse_coactivity_orthogonality_probe.py + _results.json
(COS), docs/ops/evidence/2026-09-03_sparse_d1_orthogonality_estimator.py +
_results.json (ZK-SBB), docs/research/2026-09-03_enb_orthogonality_estimator.py +
docs/ops/evidence/2026-09-03_sparse_d1_orthogonality_standard_enb.md (ENB).

**Goodhart vector "position sizing" (stated explicitly):** Layer B tests a
binary occupancy vector, so shrinking notional on co-active days cannot hide
co-exposure; Layer A Pearson is scale-invariant per series, so scaling a
sleeve does not move r; the notional-weighted Psi refinement is the only
size-sensitive statistic and is a flag, not a certifier. Sizing therefore
cannot game certification; it can only lower Psi, which never certifies.

Working-default thresholds (alpha, lambda-star, caution band, testability
floor, bootstrap B) remain WORKING_DEFAULT_OPEN_OWNER_ITEM until calibrated
on the first SHA-frozen Q14-terminal cohort; streams live in a mutable
Common/Files export (11910/NZDUSD sha changed 2026-09-03), so Tier-1 numbers
are dated, not frozen.
