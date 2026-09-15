# Adversarial review — slice `i2_lineage_map`

**Reviewer:** Claude (adversarial, read-only). **Date:** 2026-09-15.
**Verdict: ACCEPT** (no blocking, no major; two minor items).
**Patch:** `scratchpad/patches_i/i2_lineage_map.patch`
**Task:** follow-up directive §9 (duplicate / edge-lineage map) + master §56 (new-edge vs better-implementation).

## Scope checked

Full patch read in full (2103 lines: builder, config, tests, generated report, slice report).
Runtime + Vault artifacts opened and cross-checked. `git apply --check` run. RED grep.
Generator re-run twice for idempotency. Test suite executed.

## Verification results

### git apply --check — PASS (non-blocking)
`git apply --check` against `C:/QM/repo` HEAD returned exit 0. No conflicts. The patch
stages 5 new repo files only (all `new file mode 100644`): `tools/strategy_farm/lineage_map.py`,
`tools/strategy_farm/config/strategy_families.v1.json`, `tools/strategy_farm/tests/test_lineage_map.py`,
`docs/research/STRATEGY_LINEAGE_MAP_2026-09.md`, and the slice report under
`.../design/`. No in-place edits of any existing file. `git status --short` for the two
key repo files is clean (patch not yet applied; no stray orphans).

### Deterministic + idempotent — PASS
- Ran the builder (from the implementer worktree) against a temp JSON path twice with
  `--no-vault --no-md`; output was **byte-identical** on rerun (`generated_at_utc` reuse
  path works as documented).
- The freshly recomputed `inputs_sha256` = `1778bc7e74e5…` **matches the committed live
  artifact exactly** (`D:/QM/reports/state/lineage_map.json`). This is dispositive proof
  the shipped artifact was genuinely computed from the real EA corpus + real Q08 streams,
  not hand-authored.
- Node/edge counts reproduced exactly: nodes=4098, edges=768,
  exact_clone=264, close_implementation_clone=390, parameter_variant=37,
  same_edge_different_implementation=60, child_challenger=1, superseded=4,
  materially_different=12. Sum = 768. Consistent across JSON, repo MD, slice report and
  Vault page.

### Honest — no invented values, explicit EVIDENCE_MISSING — PASS
- `signature_status=EVIDENCE_MISSING` on the 18 nodes without `Strategy_*` hooks
  (17 boilerplate/governor EAs + 1 seed). Verified only the deliberately **HAND_SEEDED**
  seed node `QM5_31008` appears in any edge; the 17 boilerplate-only nodes form **no**
  clone edges — the guard against collapsing boilerplate into one false clone bucket holds.
- The Gold-Reaper edge (`QM5_31008 → QM5_13213`) is `basis=HAND_SEEDED` with **blank**
  rule_sim/jaccard/rho/param and an explicit note that behaviour cannot confirm it
  (Balke XAU is Q02 RETIRE). GAP recorded, not guessed. The seed card
  `strategy-seeds/cards/QM5_31008_gold-reaper-order-block-mitigation.md` genuinely exists.
- All 12 `materially_different` edges are `basis=BEHAVIOUR` with n_overlap_days ≥ 10
  (measured), consistent with the code guard that only asserts "materially different" for
  a measured same-label pair. Notably several carry high rho (0.91–0.93) but jaccard 0.0,
  correctly falling to `materially_different` because same-edge requires BOTH jaccard and
  rho above threshold — a defensible, honestly-recorded classification.
- Master §56 classes A–E in the config `master_directive_classes_56` match the master
  directive verbatim (lines 1383–1388).

### RED boundary grep — CLEAN (red_boundary_crossed = false)
- **Farm DB:** opened **read-only** (`file:…?mode=ro`, `uri=True`), single SELECT on
  `work_items.verdict`; no writes, no schema touch.
- **Gate thresholds / qualification:** none touched. The new thresholds in
  `strategy_families.v1.json` are **lineage-classification** cutoffs (rule_sim / jaccard /
  rho for clone-vs-variant labelling), explicitly documented as GELB levers with raw
  evidence emitted on every edge for recalibration — they are NOT Q02–Q17 gate/qualification
  criteria and do not weaken any gate.
- **T_Live / AutoTrading / FTMO purchase / live deployment:** untouched.
- **Sealed artifacts / dated decisions:** no in-place edits; all 5 repo files are new.
- **Secrets:** none. No terminal64 launch. No network.
- **Vault page:** `09 Strategy Wiki/Lineage Map.md` is a generated projection carrying the
  `qm_generated`/`qm_generated_marker: true`/"do not hand-edit" frontmatter and is written
  only-if-changed; content matches the JSON counts. See minor note 2 on prior-version
  confirmability.

### Tests — PASS
`python -X utf8 -m pytest tools/strategy_farm/tests/test_lineage_map.py -q` →
**23 passed in 79s** (re-run by reviewer). Covers signature stability under
comment/whitespace/input-default/hook-rename+string-tag edits, signature change on real
logic change, None-without-hooks, param distance, jaccard/pearson/stream-load, all seven
relationship classes from fixture pairs, family + named-family classification, read-model
schema shape, byte-identical idempotency, deterministic edge ordering.

## §9 / §56 spot-check
Balke headline (13213↔21501 jaccard 1.0 / rho 1.0 n=1596 USDJPY; 13213↔9936 jaccard 0.785
same_edge_different_implementation) reproduced from real streams via the idempotent
recompute. §56 census rows (13213=B, 13301/13036=E, 21501=D, 41097/41324/41398/41405=C,
31008=B/D) are cross-checked against computed edges in the report and consistent.

## Findings

### Minor
1. **Coarse-family count typo in the slice report.** `.../design/i2_lineage_map_report.md`
   line 23 states "12 coarse families"; the JSON and the implementer summary correctly say
   **14** (breakout, carry, fomc, gap, mean_reversion, momentum, news, other, pairs,
   pattern, seasonal, trend, unclassified, volatility). Cosmetic; does not affect the
   read-model. Fix the number in the report.
2. **Vault page prior-version not confirmable.** `09 Strategy Wiki/Lineage Map.md` is a new
   generated page (mtime = run time) carrying do-not-hand-edit markers and living in the
   generated Strategy-Wiki projection directory; a hand-written predecessor at that exact
   path could not be positively ruled out (G: has no repo history). Low risk given the path
   and markers; no action required unless OWNER knows of a prior manual page there.

### Notes (not defects; disclosed by the implementer)
- Per-family edge tables count edges *touching* the family, so an EA tagged in two named
  families (e.g. a Balke XAU breakout is balke+breakout+xau_systems) has its edges shown in
  each table — the same 12 `materially_different` appear under both breakout and xau_systems.
  By design and disclosed; the global 768 is not double-counted.
- `card_lineage.rerun_of` always null, runtime IDENTICAL equivalence not wired, DL-089/
  OPT_CENSUS param space not folded into param_distance — all recorded as NOT-done with
  reasons, none of which are invented values; acceptable within the slice bounds.

## Conclusion
Real, deterministic, idempotent and honest. Clean apply, no RED boundary crossed, tests
green. Accept. The one substantive fix is the cosmetic family-count typo (minor 1).
