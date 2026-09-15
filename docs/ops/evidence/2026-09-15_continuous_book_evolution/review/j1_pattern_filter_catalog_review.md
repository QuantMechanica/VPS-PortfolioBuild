# Adversarial review — slice `j1_pattern_filter_catalog`

**Reviewer:** Claude (adversarial review subagent), 2026-09-15
**Branch/base:** `agents/board-advisor` @ `1617cb22be` (HEAD == patch base; exact match)
**Patch:** `scratchpad/patches_d3/j1_pattern_filter_catalog.patch`
**Verdict:** ACCEPT_WITH_FIXES — no blocking issues, no RED boundary crossed; one MAJOR descriptive-data correctness defect.

---

## What was verified (independently, read-only)

### Apply / scope
- `git apply --check` against HEAD → **clean** (`APPLY_OK`).
- `git apply --numstat` → **4 new files, additive-only** (0 deletions, no modifications, no renames, no mode changes):
  `tools/strategy_farm/research/pattern_filter_catalog.py` (+1051), its test (+197),
  `docs/research/PATTERN_FILTER_CATALOG.md` (+141), the design report (+64).

### Real / deterministic / idempotent artifacts
- `D:/QM/reports/state/pattern_filter_catalog.json` exists (104 KB, 2026-09-15 19:56) and the Vault node
  `G:/…/09 Strategy Wiki/Pattern & Filter Catalog.md` exists with the `generated: true` frontmatter marker.
- Extracted the generator from the patch and ran it **twice** into scratchpad against the live DB + real
  census artifacts with `--now` fixed: both runs **byte-identical** (JSON and MD). Determinism confirmed.
- The fresh run's `inputs_sha256` = `d050a69bc7e2…c3efa` **matches the committed artifact byte-for-byte**, and
  `counts`, `historical_census.measured_cells_total`, and `historical_selection.verdict_distribution` all match.
  → The committed numbers are real and reproducible, not invented.
- Ran the patch's test suite in an isolated temp tree → **10 passed**.

### Numbers cross-checked against ground truth
- **77 predicates**: `QM_PatternId` enum has 78 members incl. `QM_PP_NONE`(0) → 77 non-zero. ✔
- **6 filter modules + QM_FilterLibrary**: all `.mqh` files present. ✔
- **Cap = 3** at `gate_manifest.v4.json` Q12 `pattern_filter_cap_per_direction: 3`; `QM_Common.mqh` has exactly
  `opt_pp_buy1..3`/`opt_pp_sell1..3` (6 inputs); `QM_PP_MAX_PREDICATES 8`; `decisions/DL-089_pattern_filter_wf_census_v3.md` exists. All "where it lives" claims accurate. ✔
- **Sealed selection = 30 programs, all NO_FILTER_CHANGE**: independently counted 30 `q12_selection_receipt.json`
  on disk, all verdict `NO_FILTER_CHANGE`. ✔ The headline finding ("no historical EA has ever selected a
  filter; the cap of 3 has never bound") rests on the sealed receipts and is **correct**.
- **EVIDENCE_MISSING**: code emits explicit tokens when DB/receipts absent (tests cover both paths). ✔
- **Unger provenance** (16 ids): the three cited provenance docs exist
  (`LIBRARY_MINING_unger-forex-strategies_2026-06.md`, `CODEX_UNGER_REFERENCE_PORTABILITY_2026-08-12.md`,
  `UNGER_PATTERN_CENSUS_FINDING_2026-09-12.md`); the 16-id set is a defensible, source-traceable curation
  pinned by test. ✔

### RED boundary scan — none crossed
- **DB reads only**: `file:…?mode=ro` + `PRAGMA query_only = ON`. The only `INSERT`/`commit` in the patch are
  in the **test fixture** (`tmp_path` SQLite), never the real farm DB.
- No gate/verdict semantics changed; Q12 / DL-089 selection contract **untouched**. `gate_manifest.v4.json`
  only referenced as text, never edited.
- No economic threshold changed: `DL089_REL_IMPROVEMENT=0.05` reproduced **only to label the descriptive
  census**; the disposition recommends KEEP cap=3 and explicitly defers any change to §30.
- No T_Live / FTMO / AutoTrading / purchase / live-deployment touch.
- No sealed artifact or dated decision edited in place (receipts read, never re-derived).
- No scheduler registration (explicitly left as instructions — RED respected); no starvation/double-claim risk.
- No secrets in doc or Vault node (counts, hashes, policy text only). No provider grants.

---

## MAJOR (fix before these figures are cited; NOT blocking)

**Descriptive census baseline is contaminated by non-null arms → per-predicate trade-reduction / expectancy /
DD / improved-cell figures are computed against the wrong reference for ~59% of program-years.**

`load_census_join` classifies a cell as the null baseline when
`arm == 'baseline' OR predicate_id in (None, 0)`, and stores one baseline per `(program, year)` in a dict with
**last-wins** and **no `ORDER BY`**. But the `OPT_CENSUS` phase is a grab-bag: within the DL089 pattern
programs the baseline-classified rows include not just the true `baseline` arm (217 rows) but also
`wf1_combo…wf4_combo` (multi-predicate combos), `strategy_entry_range_mult:*`, `strategy_sl_range_mult:*`,
`strategy_min_range_pips:*` (parameter-optimization arms) and `final:selected`/`final:incumbent` — none carry a
`predicate_id`, so all fall into the baseline bucket. **123 of 210 DL089 `(program, year)` groups have >1
baseline-classified row** (max 90), so an arbitrary non-null optimization/combo arm can win the baseline slot.

Proof it distorts the published table: a pattern-permission filter can only *remove* trades, so trade-reduction
vs a true null baseline is always ≥ 0. Checked `DL089_QM5_41097_USDJPY 2020`: true `baseline` = 204 trades,
**0 of 77 buy arms exceed it**. Yet the committed doc shows pervasive **negative** trade-reductions (Doji −8.25%,
Dragonfly Doji −11.52%, …), i.e. "arm has more trades than baseline" — impossible against the null arm, and a
direct symptom of comparing against a lower-trade optimization arm. The design report rationalizes this as
"permission arms often barely restrict the counted direction" — **that explanation is incorrect**; the cause is
the join, not the filters.

Why not blocking: the census block is labeled DESCRIPTIVE/observational everywhere, feeds **no** gate, verdict,
DB, or Q12 decision, and the authoritative finding (sealed receipts: 0 filters ever selected) is independent and
verified correct. But the figures appear in `docs/research/PATTERN_FILTER_CATALOG.md` and the Vault node framed
as "vs same-year no-filter baseline," so they are materially misleading as published.

**Fix (confined to `load_census_join`):** restrict the baseline strictly to `arm == 'baseline'` (drop the
`predicate_id in (None,0)` OR-clause), add a deterministic `ORDER BY`, and assert/dedupe exactly one baseline per
`(program, year)` (skip the group as EVIDENCE_MISSING if none). Then the negative-reduction artifact disappears
and the descriptive figures become trustworthy. Re-run and re-commit the JSON/doc/Vault snapshot.

---

## MINOR

1. **No `ORDER BY` in the census query.** Output is deterministic for a fixed DB (verified byte-identical), but
   baseline last-wins selection relies on SQLite's implicit row order — fragile across DB rewrites / engine
   versions. Add explicit ordering (also part of the MAJOR fix).
2. **"231 baseline cells" wording.** `baseline_cells_total` is the count of distinct `(program, year)` groups
   with a baseline (231), not baseline *rows* (1641 baseline-classified rows). The JSON field/code is
   transparent, but the doc/report prose reads as a raw cell count. Clarify the label.
3. **Report `not_done` note misattributes the negative trade-reductions** to filter behavior rather than the
   join bug (see MAJOR). Correct the note when fixing the join so the evidence trail is honest.

---

## Bottom line
The generator is a clean, additive, read-only, deterministic, idempotent read-model that reproduces its
committed artifact exactly; the inventory, cap classification, §22 ablation programme, and the authoritative
sealed-receipt finding are all correct and well-reasoned; no RED boundary is crossed and Q12's contract is
untouched. The one substantive defect is a contaminated null-baseline in the *descriptive* census that produces
misleading (impossible-signed) per-predicate figures — real enough to fix, but non-authoritative and non-blocking.
**ACCEPT_WITH_FIXES.**
