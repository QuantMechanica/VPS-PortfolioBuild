# Gate Manifest v4 — Linear Three-Phase Contract (PROPOSAL, not activated)

**Author:** Claude (Orchestrator) · **Branch:** `agents/board-advisor` · **Date:** 2026-08-23
**Status:** DESIGN PROPOSAL. No commit, no verdict/queue/factory/T_Live mutation. Renumbering IDs/windows is **ROT** and needs the OWNER template in §8 before any activation.
**Directive:** vault `03 Pipeline/Pipeline Rebaseline Directive 2026-08-23.md` (§2 three phases, §3 linear numbering, §4 census, §5 backfill, §6 book trigger, §7 acceptance).
**Draft contract:** `tools/strategy_farm/config/gate_manifest.v4.draft.json` (READ_INERT, `default_manifest_switch=false`).
**Inputs read:** `gate_manifest.v3.json`, `gate_manifest.py`, `phase_ids.py`, `q09_news_schema.py:191-196`, `decisions/2026-08-22_owner_pipeline_realignment_q09_q11.md`, DL-084, DL-089, and the sibling inventory artifacts (`FACTORY_AUTOMATION_INVENTORY_2026-08-23.md`, `DB_TEST_CENSUS_2026-08-23.md`, `GATE_NAME_CENSUS_2026-08-23.{md,json}`).

---

## 1 · The problem this fixes

The v3 active contract is numbered Q00..Q16 but its **operator path is not monotone**:

- the mandatory sequence is `Q10A → Q09 → Q10 → Q14 → Q15 → Q16 → Q11 → Q12 → Q13`
  (`gate_manifest.v3.json` `extension_topology.target_sequence`),
- so the operator jumps **Q16 → Q11** (backwards) and a `Q10A` baseline stage sits **before** `Q09`.

The directive forbids exactly these two shapes (§3: "darf … nicht von Q16 zu Q11 zurückspringen und Q10A darf nicht vor Q09 stehen"). v4 renumbers the **same gates, same ROT criteria** onto a strictly monotone `Q00 → Q17` line split into three visible macro phases. No gate is added or removed; nothing but the id and its ordinal position changes, plus the two topology edges that encode the back-jump.

---

## 2 · The three macro phases (linear)

| Macro phase | Gates | Meaning |
|---|---|---|
| **1 · Strategie beweist sich** | `Q00 … Q08` | Build, baseline, DEV stability/calibration, OOS, full-history/stress/statistics dossier → a **target-neutral frozen baseline**. IDs and criteria **unchanged** from v3. |
| **2 · Strategie wird optimiert / requalifiziert** | `Q09 … Q14` | Pre-news full run → news + FTMO recommendation → incumbent confirmation → pattern filter → parameter opt/freeze → sealed before/after head-to-head. Terminates in a requalification verdict; `KEEP_INCUMBENT` (no improvement) is valid. |
| **3 · Strategie wird zum Buch bewertet** | `Q15 … Q17` | Portfolio construction → operational readiness → live burn-in. Entered **only** by the fail-closed book trigger (§6). |

---

## 3 · Alt → Neu mapping table (the contract of the rebaseline)

`gate_contract_version` carries the discriminator: a historical row keeps its **v3 meaning**; a v4 row is a v4 gate. The equivalence column is the *explicit* translation used for display and for evidence reuse — never a silent reinterpretation of an old id.

| Old id (v3) | Old contract role | → New id (v4) | Macro phase | Evidence role (v4) | Reuse / rerun / supersession rule |
|---|---|---|---|---|---|
| `Q00` | Research Intake | `Q00` | 1 | HYPOTHESIS_AND_AUTHORIZATION | **REUSE, id unchanged.** |
| `Q01` | Build & Spec | `Q01` | 1 | BUILD_CONFORMANCE | REUSE, id unchanged. |
| `Q02` | Baseline Screening | `Q02` | 1 | CHEAP_PROMOTION_SCREEN | REUSE, id unchanged, hash-bound. Economic FAIL stays terminal (directive §1). |
| `Q03` | Parameter Sweep | `Q03` | 1 | PREREGISTERED_PARAMETER_STABILITY | REUSE, id unchanged, hash-bound. |
| `Q04` | Walk-Forward + Commission | `Q04` | 1 | LOCKED_PARAMETER_SEQUENTIAL_OOS | REUSE, id unchanged, hash-bound. |
| `Q05` | Gross Full-History Robustness | `Q05` | 1 | FULL_HISTORY_REPRODUCIBILITY | REUSE, id unchanged, hash-bound. |
| `Q06` | Stress HARSH | `Q06` | 1 | EXECUTION_STRESS | REUSE, id unchanged, hash-bound. |
| `Q07` | Multi-Seed | `Q07` | 1 | DISTRIBUTIONAL_ROBUSTNESS | REUSE, id unchanged, hash-bound. |
| `Q08` | Davey Statistical Validation | `Q08` | 1 | TARGET_NEUTRAL_EVIDENCE_DOSSIER | REUSE, id unchanged, hash-bound. Frozen baseline. |
| `Q10A` (non-top-level evidence stage) | Baseline Full Run (source_phase Q08) | **`Q09`** | 2 | PRE_NEWS_FULL_HISTORY_BASELINE | **RENUMBER + PROMOTE.** v3 `Q10A` was a display-only evidence binding; v4 makes it a real linear gate. Reuse only the hash-bound full-history Q08 baseline. Fixes "Q10A before Q09". |
| `Q09` (`Q09_NEWS`/`Q09_PORTFOLIO`) | News Impact + FTMO Recommendation | **`Q10`** (`Q10_NEWS`/`Q10_PORTFOLIO`) | 2 | NEWS_MODE_SELECTION_AND_FTMO_RECOMMENDATION | RENUMBER. Storage split preserved. `Q10_PORTFOLIO` is **informational only** (feeds Q15), never a pre-confirmation abort (OWNER E1 2026-08-22). Reuse when contract-equal + hash-bound. |
| `Q10` | Incumbent Full-History Confirmation | **`Q11`** | 2 | LOCKED_CONFIGURATION_REPRODUCIBILITY | RENUMBER. This is the current per-(EA,symbol) closing confirmation. Reuse when contract-equal + hash-bound. |
| `Q14` | Pattern Filter Selection (DL-089) | **`Q12`** | 2 | DL089_PREREGISTERED_PATTERN_FILTER_SELECTION | RENUMBER. Was `EXPLICIT_Q14_ADMISSION` fork entry; now a **mandatory linear step**, cap 3 filters/direction, **zero filters is a valid pass-through**. DL-089 selection contract unchanged (ROT). |
| `Q15` | Parameter Optimization & Freeze | **`Q13`** | 2 | DEV_ONLY_PARAMETER_SWEEP_AND_FREEZE | RENUMBER. DEV sweep + freeze. |
| `Q16` | Best-Settings Head-to-Head | **`Q14`** | 2 | SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT | RENUMBER. **Terminal Phase-2 gate: `next=null`.** Reference baseline = `Q09` (pre-news full run). Outcomes `CHALLENGER_PROMOTED` / `KEEP_INCUMBENT`. Removes the `Q16→Q11` back-edge. |
| `Q11` (`Q11_DXZ`/`Q11_FTMO`) | Final Portfolio Construction | **`Q15`** (`Q15_DXZ`/`Q15_FTMO`) | 3 | TARGET_SPECIFIC_PORTFOLIO_ADMISSION | RENUMBER. **Entry policy = book-trigger only** (§6). Portfolio-level metrics recomputed, not per-EA reused. |
| `Q12` | Operational Readiness | **`Q16`** | 3 | DEPLOYMENT_READINESS | RENUMBER. |
| `Q13` | Live Burn-In DXZ | **`Q17`** | 3 | PROSPECTIVE_BURN_IN | RENUMBER. `next=null`. |

**Legacy P-key remap (for historical UNION reads):** `P9 → Q15` (was `Q11`), `P9B → Q16` (was `Q12`), `P10 → Q17` (was `Q13`). `G0/P1..P8` and `P3.5/P5B/P5C/P6/P7/P8` targets are all inside the unchanged `Q00..Q08` band and are unaffected.

**Dependency-role remap** (enforced DB CHECK, see §5): `Q09_NEWS → Q10_NEWS`, `Q09_PORTFOLIO → Q10_PORTFOLIO`, `CHALLENGER_Q10 → CHALLENGER_Q11`, `Q14_ADMISSION → Q12_ADMISSION`. `Q08_INPUT`/`PARENT_LINEAGE` unchanged.

### 3.1 Why this specific numbering

The directive's own hint ("Q00-Q08 | Q09..Q14 | Q15..Q17 or similar") is adopted verbatim: Phase 1 keeps `Q00..Q08` (9 gates, ROT, no reuse loss), Phase 2 is the 6-gate optimization/requalification band `Q09..Q14`, Phase 3 is the 3-gate book band `Q15..Q17`. Every `next` edge is either `null` or the immediate ordinal successor (validated: draft `linearity_invariant`). There is exactly one place each where the chain terminates without a successor: `Q14` (Phase-2 terminal → book trigger, not an edge) and `Q17` (pipeline terminal).

---

## 4 · Census under the v4 numbering (reuse / rerun / supersession)

The DB census (`DB_TEST_CENSUS_2026-08-23.md`, 14,513 pairs, read-only) was run against the strictly-linear chain and translates 1:1 onto v4 because Q00-Q08 are unchanged and the Phase-2 renumber is a pure relabel:

| Disposition | Pairs | v4 handling |
|---|---:|---|
| REUSABLE | 5,424 | Continue from the frontier; Q00-Q08 evidence reused directly, Phase-2 evidence via `contract_equivalence` when hash+contract-equal. |
| ECONOMIC_FAIL | 7,460 | **No backfill** (terminal on merit) unless an authorized rebuild changes identity. |
| INVALID (infra/invalid, no valid gate) | 1,409 | Repairable + rerunnable (not a strategy verdict). |
| STALE | 85 | Superseded build → rerun on current build hash. |
| MISSING | 123 | Enqueue from earliest gap. |
| NOT_APPLICABLE | 12 | Structurally untestable/untradeable. |

Contiguous-valid frontier (this is the v4 backfill worklist, earliest-gap-first): NONE 7,531 · Q02 5,154 · Q03 1,456 · Q04 126 · Q05 17 · Q06 59 · Q07 144 · Q08 21 · **Q09 (v3, = v4 Q11 incumbent) 2 · Q10 (v3, = v4 Q11) 3**. Pairs valid ≥ v3 Q08 = 26; ≥ v3 Q10 = 3; ≥ v3 Q16 = 0.

**Key rebaseline finding, unchanged by renumbering:** the discontinuity is the **news gate** (v3 Q09 → v4 Q10). It produces **zero economic PASS** (only REVIEW_REQUIRED/INFRA/PENDING), so almost no pair is contiguously qualified past v4 Q09 (baseline full run). Under the linear contract, **0 pairs are book-eligible today** (v3 Q16 valid = 0). This is why the book trigger (§6) will not fire and why the Q09-autoseal/bind-plan bug (`FACTORY_AUTOMATION_INVENTORY_2026-08-23.md` §3, `q09_autoseal_hold_census`) is the frontier-blocking defect to fix first.

---

## 5 · Storage strategy (given the DB constraints found in the census)

**Policy: STAMP, DON'T RENAME.**

1. **`work_items.phase`** is `TEXT` with **no CHECK** (census `farmctl.py:1589`, stale `'P2','P3'` comment). New v4 ids can be written **without a table migration**.
2. **Add `gate_contract_version` (TEXT) to `work_items`.** Every read is scoped to the row's own contract: a v3 `Q10` (Incumbent Confirmation) is **never** read as a v4 `Q10` (News). Backfill existing rows: on/after 2026-08-23 → `'v3'`; earlier → per `pipeline_version` else `'legacy'`. This satisfies directive §3 ("alte IDs werden niemals stillschweigend mit neuer Semantik gelesen").
3. **`work_item_dependencies.dependency_role`** has an **enforced CHECK** (`q09_news_schema.py:191-196`, `IN ('Q08_INPUT','Q09_NEWS','Q09_PORTFOLIO','PARENT_LINEAGE','CHALLENGER_Q10','Q14_ADMISSION')`). Renumbering the four role tokens needs a **table-rebuild migration** (SQLite cannot `ALTER` a CHECK): recreate with the **UNION** of v3 and v4 tokens (append-only; old tokens kept for historical reads), copy rows, swap. New writes emit v4 tokens under the v4 contract.
4. **Reuse equivalence.** Q00-Q08 ids unchanged → historical rows reuse directly. Phase-2/3 evidence reuses via `contract_equivalence.v3_to_v4` **only** when criteria are contract-equal (ROT: thresholds unchanged) **and** build/setfile/window hashes match. Note hashes live in `payload_json` (`expected_ex5_sha256`/`expected_setfile_sha256`/…, `farmctl.py:6127-6130`); coverage ~11% → the finer key is populated only for hash-bearing rows.

### 5.1 How `phase_label()` / the loader expose both

- `gate_manifest.py`: add `SCHEMA_VERSION_V4`, `V4_PHASE_IDS = Q00..Q17`, `canonical_id_pattern = ^Q(?:0[0-9]|1[0-7])$`, a `_validate_v4_topology`, and expose `GateManifest.contract_equivalence` + `equivalent_gate(id, from_version, to_version)`. Draft loads as **READ_INERT** and (like v3's guard) **cannot become the default** while `default_manifest_switch=false`.
- `phase_ids.py`: make `phase_qid`/`phase_label`/`normalize_phase_id` **version-aware** — signature gains an optional `contract_version`. A historical row `(phase='Q10', contract_version='v3')` renders under the active v4 numbering as **`Q11 Incumbent Full-History Confirmation`** *with provenance* ("recorded as v3 Q10"), never a silent string swap. Rows with no version stamp fall back to the legacy alias map exactly as today.
- The active default stays **v3** until the OWNER ratifies §8. Both manifests remain valid fixtures (v1/v2 already are).

---

## 6 · Fail-closed book trigger (Phase 3 entry)

Q15 (portfolio) is reachable **only** through an explicit guard — never a per-EA `next` edge (`Q14.next=null`). The guard **refuses** (raises), it does not silently skip:

```
BOOK BUILD PERMITTED  ⇔  (qualified_candidates >= 25)  AND  (owner_order_artifact present & verified)
```

- **qualified_candidates**: pairs whose `highest_contiguous_valid_gate == Q14` with a terminal requalification verdict (`CHALLENGER_PROMOTED` or `KEEP_INCUMBENT`). **Canonical unit = `(EA, Symbol)`**; the guard must **also** report distinct EAs and distinct strategy families (directive §6 — the canonical unit stays explicit until ratification).
- **owner_order_artifact**: a present, signed `decisions/YYYY-MM-DD_owner_book_order_<venue>.md`, `venue ∈ {dxz, ftmo}`. The book is built only for the ordered venue(s).
- The old **Q11 auto-trigger at 5 Q10 pairs is void** — already absent in code (`FACTORY_AUTOMATION_INVENTORY_2026-08-23.md` §1.9), now explicitly forbidden. Under 25 the pool may only be **measured/completed**; no probe book.
- Implementation home: a `book_build_guard` in front of `deploy_tlive_book.py` and any Q15 analytic entry; the `portfolio_candidates_eligible` view (`q09_news_schema.py:733`) repoints to the v4 terminal gate. Builder / challenge-purchase / Q16+/deploy/live remain separate OWNER authorities.

---

## 7 · Backfill planner contract (dry-run before any apply)

- **Global ordering: frontier-first** — rank pairs by `highest_contiguous_valid_gate` **descending** so shortest-remaining candidates finish first.
- **Per-pair ordering: earliest-missing-prerequisite-first** — walk the shallowest missing/invalid gate; a later gate may **never** skip a hole. Progress is reported as `highest_contiguous_valid_gate`, not the largest observed Qxx string.
- **Append-only** — never overwrite an existing verdict or report; new rows only.
- **Dedup** — skip evidence whose build+setfile+window+contract hash is unchanged and contract-equal; globally dedup identical economic runs.
- **No backfill behind a terminal economic FAIL** unless a separately authorized rebuild/new experiment changes the tested identity. `INFRA`/`STALE`/contract-gap rows are repairable and rerunnable.
- **Every enqueue binds** `gate_contract_version` + build hash + setfile hash + data window + parent evidence sha256.
- Built on `evidence_cascade_driver.py` (add the omitted Q09/news gate) + `rebaseline_census.py`; emits a **governed dry-run plan artifact** (CSV+JSON) and enqueues nothing. Factory mutation happens only later, through the reviewed backfill contract — out of scope here.

---

## 8 · OWNER ratification template (ROT — required before activation)

Renumbering gate IDs, changing the optimization step from opt-in to mandatory, and the storage/CHECK migration are all ROT (thresholds/criteria stay unchanged, but IDs, windows and the topology edges are contract). The following need explicit OWNER sign-off, ideally as `decisions/2026-08-XX_owner_gate_manifest_v4_ratification.md`:

1. **Final IDs** — confirm the `Q00..Q17` numbering and the Alt→Neu table of §3.
2. **Optimization becomes mandatory** — v3 entered the fork via `EXPLICIT_Q14_ADMISSION`; v4 makes pattern-filter/param-opt/head-to-head a **linear mandatory Phase-2 segment** with `KEEP_INCUMBENT` as a valid no-improvement outcome. Confirm this is intended (directive §2 reads this way).
3. **`Q10_PORTFOLIO` demoted to informational** — confirm (already OWNER E1 2026-08-22, restated for the renumber).
4. **Book trigger** — confirm `>=25 (EA,Symbol)` + OWNER order artifact path convention `decisions/YYYY-MM-DD_owner_book_order_<venue>.md`.
5. **Storage migration** — approve adding `gate_contract_version` to `work_items` and the append-only widening of the `dependency_role` CHECK.
6. **Windows** — confirm no data-window change (the directive fixes IS 2017–2022 for Q02; v4 changes no window).

No gate threshold, gate window, or DL-089/DL-084 selection criterion is changed by this proposal.

---

## 9 · Deliverables & references

- This proposal: `docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md`
- Draft contract (READ_INERT, `default_manifest_switch=false`): `tools/strategy_farm/config/gate_manifest.v4.draft.json`
- Inventory inputs: `docs/ops/rebaseline/FACTORY_AUTOMATION_INVENTORY_2026-08-23.md`, `DB_TEST_CENSUS_2026-08-23.md`, `GATE_NAME_CENSUS_2026-08-23.{md,json}`, `VAULT_PIPELINE_DOC_INVENTORY_2026-08-23.md`, `BACKTEST_MONITOR_2026-08-23.md`
- Contract of record: `tools/strategy_farm/{gate_manifest.py,phase_ids.py}`, `config/gate_manifest.v3.json`
- DB CHECK: `tools/strategy_farm/q09_news_schema.py:191-196`
- Decisions: `decisions/2026-08-22_owner_pipeline_realignment_q09_q11.md`, `DL-084`, `DL-089`

The implementation work breakdown (router-enqueueable tickets) is in the structured result accompanying this proposal.
