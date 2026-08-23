# Strategy Archive × Gate-Manifest v4 — Reconciliation

**Author:** Claude (Orchestrator, IA/Dashboard lane) · **Branch:** `agents/board-advisor` · **Date:** 2026-08-23
**Status:** ANALYSIS + TICKET LIST. Read-only against `farm_state.sqlite` (`mode=ro`); no verdict/queue/factory/T_Live mutation.
**Scope:** what of the Strategy Archive (`tools/strategy_farm/dashboards/archive_matrix.py`, `strategy_archive.html`, EA detail pages) must be rebuilt or adapted now that the pipeline contract is **v4-linear** (`decisions/2026-08-23_owner_gate_manifest_v4_linear.md`, `docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md`).
**Runtime reality:** gate manifest **v4 is merged as a draft** (`config/gate_manifest.v4.draft.json`, READ_INERT, `default_manifest_switch=false`); the **active runtime is still v3** until `activate_gate_manifest_v4.py` flips it. Every finding below is measured against that split.
**Reconciliation tool:** `docs/ops/rebaseline/reconcile_archive_backfill.py` (read-only; re-runnable).

---

## 1 · Headline

The Strategy Archive is **not manifest-aware where it must be and manifest-aware where it doesn't matter.** It imports one display table (`PHASE_NAME`) from `phase_ids`, but the **column set, column order, the ordinary chain that drives the gap test, the three colour bands, and the `Q09`/`P2` folding are all hardcoded literals** (`archive_matrix.py:47-60,108-115`). None of that reads the manifest loader, `PHASE_ORDER`, `ORDINARY_PHASE_ORDER`, `OPTIMIZATION_PHASE_ORDER`, `extension_topology`, or the version-aware `phase_qid`/`phase_label` helpers that `phase_ids.py` already exposes.

**Consequence at the v4 flip: silent column collisions and a dropped gate.** Because the page reads `work_items.phase` raw and ignores `gate_contract_version`, a v3 row and a v4 row that share a *string* are counted in the same column even though the contract renumber gave that string a **different meaning**. This is exactly the failure mode `gate_contract_version` + `phase_qid(phase, contract_version)` were built to prevent — the archive is the one surface that bypasses them.

The hole definition is otherwise **substantially the same set** as the backfill planner's `FILL_MISSING` (4,661 pairs agree exactly), and the differences are explained and mostly intentional (§3).

---

## 2 · Part (1) — Are gate columns manifest-derived? What breaks at the v4 flip?

### 2.1 Where the archive gets its gates today (all literals)

| Element | Source in `archive_matrix.py` | Manifest-derived? |
|---|---|---|
| Column set + order (`Q02…Q10, Q14/Q15/Q16, Q11/Q12/Q13`) | `COLUMNS` literal, lines **47-55** | **No** |
| Sub-labels `Q10.1/Q10.2/Q10.3` for Q14/Q15/Q16 | hardcoded strings in `COLUMNS`, line 51-53 | **No** — pre-empts a renumber that v4 did **differently** |
| Macro-phase bands (`eval`/`opt`/`port` → "Evaluation/Optimization/Portfolio build") | 3rd tuple field in `COLUMNS` + `render_matrix_page` literal, lines 47-55 / ~1140 | **No** |
| Ordinary chain that drives the gap test | `ORDINARY` literal `Q02…Q13`, lines **59-60** | **No** |
| Phase folding (`P2→Q02`, `Q09*→Q09`) | `gate_of()`, lines **108-115** | **No** — duplicates `normalize_phase_id`/`advancement_table` |
| Gate tooltip name only | `PHASE_NAME.get(tok)` from `phase_ids`, line ~1148 | Yes (the only one) |
| Column index / gap ordinal | `GATE_IDX` from the `COLUMNS` literal, line 56 | No |
| EA detail run table gate column | `render_backtests_section`, raw `it["phase"]`, line **930** | **No** — no `phase_label`, no provenance |
| Card "highest PASS" ranking | `hp` = max index with a PASS (`collect`, lines 409-411) | Not contiguity — see §3.4 |

`phase_ids.py` already exports everything needed for a manifest-driven rewrite: `PHASE_ORDER`, `PHASE_NAME`, `PHASE_NEXT`, `ORDINARY_PHASE_ORDER`, `OPTIMIZATION_PHASE_ORDER`, `ORDINARY_STORAGE_PHASE_ORDER`, `advancement_table()` (with `storage_lane` handling for `Q09_NEWS`/`Q09_PORTFOLIO`), and the **version-aware** `phase_qid(phase, contract_version)` / `phase_label(...)` / `normalize_phase_id(...)`. The archive uses none of them for structure.

### 2.2 The v3→v4 renumber (what the strings mean before/after)

Per `decisions/2026-08-23_owner_gate_manifest_v4_linear.md` §"Alt→Neu":

| String | v3 meaning (active today) | v4 meaning (after flip) |
|---|---|---|
| `Q09` | News Impact + FTMO Recommendation | **Baseline Full Run** (promoted from v3 `Q10A`) |
| `Q10` | Incumbent Full-History Confirmation | **News Impact + FTMO Recommendation** |
| `Q11` | Final Portfolio Construction | **Incumbent Full-History Confirmation** |
| `Q12` | Operational Readiness | **Pattern Filter Selection (DL-089)** |
| `Q13` | Live Burn-In DXZ | **Parameter Optimization & Freeze** |
| `Q14` | Pattern Filter Selection | **Best-Settings Head-to-Head** (terminal Phase-2) |
| `Q15` | Parameter Optimization & Freeze | **Final Portfolio Construction** |
| `Q16` | Best-Settings Head-to-Head | **Operational Readiness** |
| `Q17` | *(does not exist in v3)* | **Live Burn-In DXZ** |

### 2.3 What breaks at the flip (concrete, per column)

After the flip the DB carries **mixed** rows: historical `gate_contract_version='v3'` and new `'v4'`. The archive reads the raw string into the literal `COLUMNS`/`GATE_IDX`, so:

- **`Q09` column** (labelled "News"): now also accumulates v4 `Q09` = Baseline Full Run. Two different gates, one column.
- **`Q10` column** (labelled "Incumbent"): a v3 `Q10` (incumbent) and a v4 `Q10` (**news**) land together. The single most damaging collision — the page shows "incumbent" cells that are actually news runs.
- **`Q11/Q12/Q13` columns** (purple "Portfolio build"): v4 puts **Incumbent / Pattern / ParamOpt** on those strings — i.e. *Phase-2 optimization* content rendered under the *Phase-3 book* band. Wrong band, wrong colour, wrong meaning.
- **`Q14/Q15/Q16` columns** (orange, labelled `Q10.1/Q10.2/Q10.3`): v4 puts H2H / Portfolio / Ops there. The invented `Q10.x` sub-labels become simply false.
- **`Q17` (v4 Live Burn-In):** **not in `COLUMNS`/`GATE_IDX`** → `gate_of()` returns `None` → the row is silently counted into `skipped_phase` and **the terminal live-burn-in gate disappears from the archive entirely.**
- **Gap test** (`ORDINARY` literal `Q02…Q13`): computes contiguity across the *v3* chain. Under v4 the ordinary chain is `Q02…Q08, Q09(baseline), Q10(news), Q11(incumbent), Q12, Q13, Q14`; the literal produces nonsense "reachable gaps" (e.g. treating v4 `Q10`=news as the predecessor of `Q11`=incumbent under v3 portfolio semantics).
- **AC#3 (no `P[0-9]` token in HTML):** the footer prints `skipped_phase.most_common(6)`; out-of-chain legacy `P9`/`P10` rows can surface a `P`-token there. Pre-existing, worsened by more skipped strings under v4.

**None of this throws — it renders wrong.** That is the danger: a page whose entire purpose is "identify the holes yourself" will mislabel and miscount silently the moment the contract flips.

### 2.4 The fix (what "manifest-derived" must mean here)

1. Build `COLUMNS`, order, bands and labels from the **active manifest** via `phase_ids` (`ORDINARY_PHASE_ORDER` + `OPTIMIZATION_PHASE_ORDER` for order; `PHASE_NAME` for labels; the manifest's three macro phases for the bands). Delete the `COLUMNS`/`ORDINARY`/`GATE_IDX` literals and the `Q10.1-Q10.3` strings.
2. Read `gate_contract_version` per row (guard for column-absent exactly like `rebaseline_census._has_column`) and resolve every stored phase through `phase_qid(phase, contract_version)` before bucketing, so a v3 and a v4 string are placed by **meaning**, not spelling. Surface provenance with `phase_label(...)` (e.g. `Q11 Incumbent … (v3:Q10)`).
3. Replace `gate_of()`'s hand-rolled folding with `normalize_phase_id` / `advancement_table()` (which already models the `Q09_NEWS`/`Q09_PORTFOLIO` storage lanes — see §3.3).
4. Apply the same treatment to the EA-detail run table (`render_backtests_section`, line 930) and `runs_for_ea` — those print raw `phase` with no translation and will show bare, provenance-less v3 ids after the flip.

---

## 3 · Part (2) — Archive holes vs backfill planner actions (reconciled, with counts)

Measured 2026-08-23 by `reconcile_archive_backfill.py` against the live DB and the committed dry-run plan `D:/QM/reports/rebaseline/backfill_plan_2026-08-23.csv` (14,513 PAIR rows).

### 3.1 The two definitions are not the same object

- **Archive "reachable gap"** = a *display* signal: for each non-retired `(EA, symbol)`, the **first** gate on the ordinary chain whose predecessor PASSed and that carries no row — **one cell per pair**. Also adds a **second source**: card-frontmatter target symbols that never ran, as synthetic `Q02` gaps.
- **Backfill `FILL_MISSING`** = one *action* in a full per-pair plan (`FILL_MISSING`, `RERUN_INFRA`, `REBIND_STALE`, `SKIP_REUSABLE`, `STOP_ECONOMIC_FAIL`, `STOP_NOT_APPLICABLE`, `UNKNOWN`) — the earliest-missing-prerequisite gate with **no evidence**, on the census chain `Q02…Q10, Q14, Q15, Q16` (no OWNER/manual Q11–Q13), work_items only, behind terminal economic FAIL suppressed.

### 3.2 Measured overlap

| Set | Count |
|---|---:|
| Archive reachable-gap pairs (one gap each) | **5,358** (Q03 4,658 · Q02 658 · Q11 30 · Q10 8 · Q04 3 · Q07 1) |
| Backfill `FILL_MISSING` pairs | **5,019** (Q03 5,014 · Q02 3 · Q14 1 · Q07 1) |
| **In both, gate agrees** | **4,661** (all Q03 — the "Q02 PASS, no Q03 row" backlog) |
| In both, gate differs | 1 (`archive Q11 → backfill Q14`) |
| **Archive-only** | **696** |
| **Backfill-only** | **357** |

The **4,661** exact agreements are the same number the spec/prototype reported as "Q02 PASS without Q03" — the two tools independently land on the identical core backlog. That is the reassuring result.

### 3.3 The differences, explained (this is the reconciliation)

| # | Delta | Count | Cause | Intentional? |
|---|---|---:|---|---|
| A | Archive-only `Q02` gaps | **656** | Card-frontmatter target symbols with no work_items row at all (`untested_targets`). Backfill operates on work_items only, so it has **no pair row** for these. | **Yes** — spec F8 "second source, kept separate". Keep, but label as not-in-backfill. |
| B | Archive-only `Q11` gaps | **29** (+1 the `Q11→Q14` mismatch) | Archive's `ORDINARY` includes the **OWNER/manual** gates `Q11/Q12/Q13`; the backfill chain stops at `Q10` + the optimization fork and **never fills manual gates**. Archive marks a "gap" the pipeline will never auto-work. | **No** — a hole the operator cannot action reads as work that doesn't exist. Decide (§4 T5). |
| C | Archive-only `Q10` gaps | **8** | Archive `gate_of` folds `Q09_NEWS`+`Q09_PORTFOLIO`→`Q09` and accepts the **informational** `PASS_PORTFOLIO` arm as "Q09 passed", so it draws a `Q10` gap. The rebaseline contract is explicit: the **news gate produces zero economic PASS** (`census_2026-08-23.json`: `pairs_valid_at_least_Q10 = 3`), so these gaps are false. | **No — defect.** The informational portfolio lane must not license a successor gap. |
| D | Archive-only `Q04`/misc | 3 | Predecessor-PASS classification drift: archive uses `verdict.startswith("PASS")` (incl. `PASS_SOFT`/`PASS_PORTFOLIO`); census `PASS_ECON` is an explicit set. Edge rows classify differently. | Minor — align the PASS set. |
| E | Backfill-only `FILL_MISSING Q03` | **356** (+1 Q02) | Archive **suppresses** a hole for any pair carrying a `RETIRE`/`OBSOLETE`/`SUPERSEDED` token on *any* row, and requires the **latest** predecessor row to be PASS (a later VOID hides an earlier PASS). Backfill classifies by **contiguous-valid frontier** and only STOPs on terminal **economic** FAIL at the frontier, so it still wants the Q03 fill. | Partly — the retired-suppression is defensible; the "latest row hides an earlier PASS" case is a divergence worth aligning. |

### 3.4 Volume/semantics mismatch (the archive has no vocabulary for most of the plan)

The archive represents **one** of the backfill's action classes (`FILL_MISSING` ≈ the hole chip). It has **no distinct rendering** for the rest of the 14,513-pair plan:

| Backfill action | Rows | Archive representation |
|---|---:|---|
| `STOP_ECONOMIC_FAIL` | 7,439 | a FAIL chip somewhere upstream — not shown as "terminal, do not rerun" |
| `FILL_MISSING` | 5,019 | the reachable-gap chip (the one it does model) |
| `RERUN_INFRA` | 1,028 | a VOID chip — but VOID ≠ "this is the work" |
| `UNKNOWN` | 931 | invisible |
| `REBIND_STALE` | 84 | **invisible** — needs per-cell build identity the DB lacks (F4 / SH-2) |
| `STOP_NOT_APPLICABLE` | 12 | empty cell |

The archive's `hp` ("highest PASS") is also **not** `highest_contiguous_valid_gate` — it is the max gate index with a PASS, ignoring holes below it. The census/backfill and the v4 operator surfaces (OPEN_ITEMS §0d item 12, `rb-surfaces`) standardised on `highest_contiguous_valid_gate`. The archive should adopt the shared definition so its ranking agrees with the rest of the rebaseline.

---

## 4 · Part (3) — Spec §11a items & OPEN_ITEMS §0d, classified

### 4.1 Spec §11a (F1–F8) build status

| Decision | Status | Note |
|---|---|---|
| **F1** row = card, expandable | **done** | model A + expand JS built |
| **F2** `Q10.1–Q10.3` sublevels | **superseded by v4** | v4 renumbers linearly `Q00…Q17` (`decisions/2026-08-23_owner_gate_manifest_v4_linear.md`); the `Q10.x` literals in `COLUMNS` are now wrong. OWNER parked the separate `Q10.1-Q10.3` wave (`74e72403`, OPEN_ITEMS `-502`). |
| **F3** seven states, loud hole chip | **done, one gap** | 7 states rendered; `governance`(114)/`review`(73) "thin frame" (spec §4) **not** implemented — folded into VOID. Minor. |
| **F4** stale-pass hollow | **not built (fallback a)** | blocked on per-cell build identity → **SH-2** (`-512`). Correct pre-registered fallback in place (warning banner). |
| **F5** every empty cell names its reason in tooltip | **not built** | only stored chips + the reachable-gap chip carry tooltips; truly empty (NONE) cells carry **no reason**. Gap. |
| **F6** default sort = highest gate passed | **done** | (but "highest gate" = `hp`, not contiguous — see §3.4) |
| **F7** DWX + legacy + BASKET chips | **done** | relics dropped rather than bucketed as "legacy"; acceptable |
| **F8** matrix begins at Q02 | **done** | footer states the pre-factory queue is out of scope |
| **§11 AC#4** every chip tooltip names verdict + date + work-item id | **partial** | chip `title` shows only `{sym} {gate} {STATE}` — **no date, no work-item id** |
| **§11 AC#3** no `P[0-9]` token in HTML | **at risk** | footer can print skipped legacy `P9`/`P10` strings |

### 4.2 OPEN_ITEMS §0d items

| Item | What | Classification |
|---|---|---|
| **-512** | SH-2 artifact identity per run (`ex5_sha256` mandatory on gate write) | **to build (Codex)** — needs Factory-OFF window + review. **Codex ticket `rb-sh2-sh3` is in flight — do NOT duplicate.** OWNER owns scheduling the OFF window. Unblocks archive **F4**. |
| **-502** | Gate numbering `Q10.1–Q10.3` | **superseded by v4** — close it against `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`. Owner confirms closure. |
| **-513** | Play `QM5_13036` on XAUUSD | **to decide (OWNER)** — candidate set = ROT. Not archive work. |
| **-511** | Strategy Archive online (coverage layer) | **to decide (OWNER)** — public-exposure degree (`cc61dbf2`, blocked). Not archive-internal. |
| **-514** | EA showcase pages triggering MQL5 purchase | **to decide/build (OWNER)** — blocked only on the MQL5 product EA; rights cleared. Separate from the archive matrix. |
| **-509** | SH-3 successor (typed FK columns) | **to build (Codex)** — OFF window; part of the schema-hardening lane, not the matrix. |
| **-505 / -508 / -510** | detail-page full build · DL-090 job · English card intake | **done / in-flight** — per OPEN_ITEMS §0c the detail pages, DL-090 job and SH-1 already shipped. |

---

## 5 · Part (4) — SH-2 (F4 stale-pass)

The archive's F4 (render a build-superseded PASS as hollow, not a page-wide warning banner) is **structurally blocked** on per-cell build identity: `expected_ex5_sha256` covers **0.3%** of payloads and the `.ex5` timestamp would false-flag **73.6%** of PASS rows (`FARM_DB_SCHEMA_HARDENING_2026-08-23.md` §SH-2). **SH-2** makes `ex5_sha256` mandatory on every gate write; only then is F4 buildable. **Codex ticket `rb-sh2-sh3` is in flight — this reconciliation does not create a duplicate.** The archive change is downstream of SH-2 and is captured as a **follow-on** (T6), not started now.

---

## 6 · Ticket list

Ordering: fix the flip-safety breakage first (it is silent and lands the moment v4 activates), then the semantic alignments, then the F5/AC polish, then the OWNER gates.

| # | Agent | Title | Scope | Size | Acceptance |
|---|---|---|---|---|---|
| **T1** | codex | Archive columns/order/bands from the manifest, not literals | Replace `COLUMNS`/`ORDINARY`/`GATE_IDX` literals and the `Q10.1-Q10.3` strings (`archive_matrix.py:47-60`) with structure derived from `phase_ids` (`ORDINARY_PHASE_ORDER`, `OPTIMIZATION_PHASE_ORDER`, `PHASE_NAME`, manifest macro-phase bands). Replace `gate_of()` folding (108-115) with `normalize_phase_id`/`advancement_table`. | M | Under the active v3 manifest the page is byte-equivalent in gate set/order; a unit test builds the columns from a loaded manifest object; no `COLUMNS`/`ORDINARY` literal remains. |
| **T2** | codex | Contract-version-aware phase resolution (matrix + detail pages) | Read `gate_contract_version` per row from `work_items_clean` (guard column-absent like `rebaseline_census._has_column`); bucket every phase via `phase_qid(phase, contract_version)`; render provenance via `phase_label(...)`. Apply to the matrix **and** `render_backtests_section`/`runs_for_ea` (raw `phase`, line 930). | M | Fixture with mixed v3+v4 rows: v3 `Q10`(incumbent) and v4 `Q10`(news) never share a column; v4 `Q17` renders (not dropped); every rendered gate cell carries active-numbering + provenance; depends on T1. |
| **T3** | codex | Fix Q09 news/portfolio lane conflation in the gap test | Use `advancement_table()` storage-lane handling so the informational `Q09_PORTFOLIO`/`Q10_PORTFOLIO` arm never licenses a successor gap; align the predecessor-PASS test with the census `PASS_ECON` set. | S | The 8 false `Q10` archive-only gaps (§3.3-C) and the Q04 drift (§3.3-D) disappear; `reconcile_archive_backfill.py` shows 0 news-lane-caused archive-only gaps; test with a `PASS_PORTFOLIO`-only pair asserts no successor hole. |
| **T4** | codex | Align the hole/frontier definition with the rebaseline census | Adopt `highest_contiguous_valid_gate` for card ranking (replace `hp`); confine the reachable-gap test to the automated census chain (exclude OWNER/manual gates) per the T5 decision; reconcile the retired/latest-row suppression with backfill STOP semantics. | M | Archive-only `Q11` gaps (§3.3-B) resolved per T5; backfill-only delta (§3.3-E) reduced to the intended retired-suppression set and documented; ranking matches census frontier; depends on T5. |
| **T5** | claude | Decide the archive hole-semantics contract | IA decision (not delegated): (a) should the archive draw reachable gaps for OWNER/manual gates (v3 Q11–Q13 / v4 Q15–Q17) at all, or mark them a distinct non-auto band; (b) keep the frontmatter second-source Q02 gaps labelled separately (§3.3-A); (c) define archive "gap" ≡ backfill `FILL_MISSING` where they should agree. Produces the spec T4 implements. | S | A short decision note in `docs/ops/rebaseline/` fixing (a)/(b)/(c); referenced by T4. |
| **T6** | codex | F4 stale-pass hollow chip (follow-on to SH-2) | Once SH-2 (`-512`, `rb-sh2-sh3`) lands per-cell `ex5_sha256`, replace the F4 warning banner with the hollow stale-pass state; **blocked until SH-2 active — do not start now, do not duplicate rb-sh2-sh3**. | S | A PASS whose `ex5_sha256` ≠ the EA's current build renders hollow with provenance; banner removed; gated on SH-2. |
| **T7** | codex | F5 empty-cell reasons + AC#4 chip tooltips | Every empty (NONE) cell names its reason (target-universe / retired / bucket / hold — spec F5); every chip `title` adds verdict + date + work-item id (AC#4); ensure no `P[0-9]` token reaches the HTML (AC#3, footer skipped-phase). | S | AC#3/AC#4/F5 assertions pass in a render test. |
| **T8** | owner | Schedule the Factory-OFF window for SH-2 (`-512`) | SH-2 needs an OFF window + Claude review; it unblocks archive F4 (T6). Codex `rb-sh2-sh3` is ready. | — | OWNER names the OFF window; no AI seat toggles the factory. |
| **T9** | owner | Confirm v4 numbering for the archive; close `-502` as superseded | Confirm the archive adopts v4 `Q00…Q17` at the flip (T1/T2) and formally close the parked `Q10.1-Q10.3` wave (`-502`, `74e72403`) as superseded by `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`. | — | `-502` marked superseded; archive numbering decision recorded. |

Pre-existing OWNER items `-511` (public exposure), `-513` (13036/XAUUSD), `-514` (product EA) are **not archive-blocking** and stay on their existing router rows.

---

## 7 · Evidence

- Reconciliation tool + numbers: `docs/ops/rebaseline/reconcile_archive_backfill.py` (read-only, re-runnable).
- Archive code of record: `tools/strategy_farm/dashboards/archive_matrix.py` (`COLUMNS` 47-55, `ORDINARY` 59-60, `gate_of` 108-115, `collect` hole logic 419-433, `render_backtests_section` 909-947).
- Manifest-aware helpers already available: `tools/strategy_farm/phase_ids.py` (`PHASE_ORDER`/`ORDINARY_PHASE_ORDER`/`OPTIMIZATION_PHASE_ORDER`/`advancement_table`/`phase_qid`/`phase_label`).
- Contract: `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`, `docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md`, `config/gate_manifest.v4.draft.json` (READ_INERT).
- Backfill/census: `D:/QM/reports/rebaseline/backfill_plan_2026-08-23.csv`, `census_2026-08-23.json`, `docs/ops/rebaseline/{BACKFILL_PLAN,DB_TEST_CENSUS}_2026-08-23.md`.
- Spec + prototype: `docs/ops/STRATEGY_ARCHIVE_MATRIX_SPEC_2026-08-23.md` §11/§11a, `docs/ops/evidence/2026-08-23_strategy_archive_matrix_prototype.md`.
- SH-2: `docs/ops/FARM_DB_SCHEMA_HARDENING_2026-08-23.md` §SH-2; OPEN_ITEMS `docs/ops/OPEN_ITEMS_STATUS.md` §0/§0b/§0c/§0d.
