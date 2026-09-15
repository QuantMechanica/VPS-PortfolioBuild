# Slice i2_lineage_map — report

**Directive:** follow-up §9 (duplicate / edge-lineage map) + master §56 (new-edge vs better-implementation).
**Date:** 2026-09-15. **Branch:** agents/board-advisor (worktree). **Author:** implementation subagent (read-only inputs; no gate/verdict/DB writes).

Summary line: built `tools/strategy_farm/lineage_map.py`, a deterministic, idempotent, read-only lineage/duplicate-map builder + config `config/strategy_families.v1.json` + 23 contract tests; ran it for real over 4,097 EAs (4,080 with a mechanism signature) and 115 sealed Q08 trade streams, producing **768 relationship edges** (264 exact_clone, 390 close_implementation_clone, 37 parameter_variant, 60 same_edge_different_implementation, 1 child_challenger, 4 superseded, 12 materially_different) into `D:/QM/reports/state/lineage_map.json` (schema `qm.lineage-map/v1`), the repo report and a generated Vault page.

## Files changed (in the patch)

- `tools/strategy_farm/lineage_map.py` (new) — the builder.
- `tools/strategy_farm/config/strategy_families.v1.json` (new) — coarse family classifier (reuses the whitespace-audit slug derivation), §9 named-family definitions, relationship-class thresholds (audit-proposed, with rationale), §56 class map, hand-seeded Gold-Reaper edge + seed node.
- `tools/strategy_farm/tests/test_lineage_map.py` (new) — 23 tests.
- `docs/research/STRATEGY_LINEAGE_MAP_2026-09.md` (new, generated) — Markdown summary with per-family evidence tables, §9 answers, §56 census cross-check.

## Runtime / Vault artifacts written (outside the repo)

- `D:/QM/reports/state/lineage_map.json` — read-model, schema `qm.lineage-map/v1`, `inputs_sha256=1778bc7e74e5…`. 4,098 nodes, 768 edges, 12 coarse families. Carries `schema` + `generated_at_utc` per the read-model convention.
- `G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/Lineage Map.md` — generated Vault page (frontmatter marker `qm_generated: lineage_map.py`, `qm_generated_marker: true`; "do not hand-edit"). The I1 wiki-sync slice reads the JSON and renders per-node relationships.

## Shared contract

`D:/QM/reports/state/lineage_map.json` (schema `qm.lineage-map/v1`): `{schema, generated_at_utc, inputs_sha256, thresholds, nodes:{<ea_id>:{family, named_families, mechanism_signature, has_trade_stream, symbols, signature_status, card_lineage:{parent_id, variant_of, rerun_of}}}, edges:[{from, to, relation, basis, evidence:{rule_signature_equal, rule_sim, param_distance, trade_overlap_jaccard, return_correlation, n_overlap_days, symbol}, confidence, note}], families:{<family>:[ea_ids]}}`. `relation` ∈ {exact_clone, close_implementation_clone, parameter_variant, same_edge_different_implementation, child_challenger, superseded, materially_different}. This matches the task-stated I1 contract; the earlier audit `lineage_map.schema.json` was a proposal and is superseded by this shape.

## Method (deterministic; documented)

- **Mechanism signature** = SHA256 over the normalized `Strategy_*` hook region of the `.mq5`: strip block/line comments → extract every `Strategy_*` function body (brace-matched; framework OnInit/OnTick boilerplate discarded) → canonicalize hook names to `FN`, blank string-literal contents → tokenize + rejoin without whitespace → sort per-function token-strings → join → SHA256. Input defaults live in `input` declarations outside the hooks so a retune never moves the hash (→ becomes a `parameter_variant`, not a new signature). 99.8% of EAs carry `Strategy_*` hooks; the 18 that do not (governors, masters, backtest-only sims) get `mechanism_signature=null` / `signature_status=EVIDENCE_MISSING` and never form clone edges.
- **rule_sim** = token-multiset Jaccard (O(n), order-independent) — chosen over an O(n·m) alignment so the corpus-wide pairwise sweep over the large named families stays bounded.
- **param_distance** = normalized L1 over shared `strategy_*` inputs from the `.set` (backtest set preferred), in [0,1]; `null` if no shared input.
- **trade-overlap Jaccard** on entry-day sets and **daily-PnL Pearson** on exit-day-bucketed `net`, from the sealed Q08 streams at `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/<numid>_<SYMBOL>_DWX.jsonl` (134 files; 115 map to a built EA). Behaviour is required with `n_overlap_days ≥ 10`.
- **Classes** evaluated top-down (config thresholds: rule_sim clone ≥0.90 / variant ≥0.98, jaccard clone ≥0.80 / variant ≥0.50 / same-edge ≥0.40, rho clone ≥0.95 / same-edge ≥0.70). Identical-signature groups emit **star edges** from a canonical member (min ea_id) — exact_clone when params also equal, else parameter_variant (superseded if the head carries a terminal RETIRE/SUPERSEDED/OPT_REJECTED verdict, read-only from the farm DB). `materially_different` is asserted only for a **measured** same-symbol pair inside a **mechanism-scoped** named family (balke/gold_reaper/orb/session_breakout/breakout) — the symbol-scoped `xau_systems` family emits only positive relationships, so "both trade gold but differently" is not counted as a same-label finding.

## Compute bounds

Signatures for all 4,112 mq5 (single pass, ~14 s). Behaviour only for streamed pairs; rule_sim/behaviour scoped to named-family pairs (done in full: balke 55, orb 1,891, session 136, breakout 38,503, xau 25,425 candidate pairs, all cheap set ops), the 115 streamed pairs cross-family, and declared card pairs. Full build ≈ 26 s, no per-file subprocess, no terminal. Idempotent: byte-identical JSON on rerun (verified; `generated_at_utc` reused while `inputs_sha256` unchanged).

## §9 headline counts (run for real)

- Edges 768: **exact_clone 264 · close_implementation_clone 390 · parameter_variant 37 · same_edge_different_implementation 60 · child_challenger 1 · superseded 4 · materially_different 12**.
- 59 exact-clone (identical-signature) clusters covering 364 EAs; largest cluster = 221 EAs ("other" family — the undeclared seasonal/rotation cohort the whitespace audit flagged).
- Nodes 4,098 (4,080 with a signature + 18 seed/boilerplate-only, incl. the Gold-Reaper seed node QM5_31008).

## §9 answers for the named families

- **René Balke** (11 built EAs): the census/opt siblings QM5_21501/41097/41324/41398 are an **exact-clone cluster** (identical signature); QM5_13213 is a **close_implementation_clone** of them (rule_sim 0.959, identical backtest set) and **21501 behaviourally identical on USDJPY (jaccard 1.0, rho 1.0)** — confirming 21501 is 13213's measurement mirror. 13213↔9936 (its declared source) = **same_edge_different_implementation** (rule_sim 0.989 but USDJPY jaccard 0.785 / rho 0.903 — near-identical code, behaviour diverges on the range-start-hour change). 41398→41405 = **child_challenger** (declared, rule_sim 0.768, param_distance 0.143).
- **Gold Reaper**: no built EA (seed card QM5_31008 REJECTED). Encoded as one **hand-seeded same_edge_different_implementation** edge to Balke XAU (QM5_13213) per `docs/research/GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md`; behaviour cannot confirm (Balke XAU is Q02 RETIRE, no XAU stream survives). GAP recorded, not guessed.
- **ORB** (62 EAs, 0 with a Q08 stream): 2 edges (1 close_impl, 1 parameter_variant) — the cohort largely died Q02–Q04 so behaviour is unavailable (source-signature edges only).
- **session breakouts** (17 EAs, 0 streams): 1 exact_clone.
- **breakout families** (278 EAs, 11 streamed): 59 edges (16 exact, 26 close, 2 param, 3 same_edge, 12 materially_different).
- **XAU systems** (226 EAs, 48 streamed): 384 edges (8 exact, 359 close, 5 same_edge, 12 materially_different). The dense close-impl block is the `xauxag-*-clv` relative-value template cohort (genuine close implementations of a shared template, verified by slug).

## §56 classes for the robust-rebuild census rows

Cross-checked against computed edges (full table in the report): QM5_13213 = **B** (existing edge, better implementation of QM5_9936); QM5_13301 = **E**; QM5_13036 = **E**; QM5_21501 = **D** (duplicate-by-construction; computed exact_clone + jaccard/rho 1.0); QM5_41097/41324/41398/41405 = **C** (config/parameter variants; computed exact_clone/child_challenger confirm the shared code + declared chain); Gold Reaper QM5_31008 = **B/D** (existing-edge / clone of the already-killed Balke XAU death signature).

## Contracts changed

None broken. New config `qm.strategy-families/v1` and new read-model `qm.lineage-map/v1` introduced. Reuses the whitespace-audit family derivation (externalized into config).

## Tests

`python -X utf8 -m pytest tools/strategy_farm/tests/test_lineage_map.py -q` → **23 passed** (~61 s). Covers: signature stability under comment/whitespace/input-default/hook-rename+string-tag edits, signature changes on real logic change, `None` without hooks; param distance; jaccard/pearson/stream-load; all seven relationship classes from fixture pairs; family + named-family classification; read-model schema shape (contract fields on every node/edge, valid relation enum, families→node consistency); byte-identical idempotency; deterministic edge ordering.

## Rollback

Delete the four new repo files (`tools/strategy_farm/lineage_map.py`, `tools/strategy_farm/config/strategy_families.v1.json`, `tools/strategy_farm/tests/test_lineage_map.py`, `docs/research/STRATEGY_LINEAGE_MAP_2026-09.md`) and the two generated artifacts (`D:/QM/reports/state/lineage_map.json`, Vault `09 Strategy Wiki/Lineage Map.md`). No DB/gate/verdict state is touched, so rollback is file-deletion only.

## NOT done (with reasons)

- **runtime IDENTICAL equivalence** (`qm5_35005_equivalence.py`) not wired into the class inputs — it is single-pair and terminal64-bound; running it corpus-wide would consume factory compute. The signature/behaviour classifier already resolves the same cases; the equivalence tool remains the manual confirmatory check for a disputed exact-clone claim.
- **DL-089 / OPT_CENSUS parameter space** is not folded into `param_distance` — the census/opt variation lives outside the backtest `.set`, so 13213↔opt-siblings show param_distance 0 and classify as close_implementation_clone rather than the census's §56 "C". The §56 table is reported from `robust_rebuild_census.md` evidence and cross-checked, not overridden; a future lever could add an opt-profile distance.
- **rerun_of** card-lineage field is always `null`: no card carries it and `work_item_supersedes` never crosses ea_id (verified 0 cross-EA rows), so EA-node rerun lineage is within-EA hygiene, not a strategy relationship. Recorded as `null`, not invented.
- **Scheduled health line / task** (`STRATEGY_LINEAGE`) not registered — per RED boundary (installers only, no task registration). The builder is CLI-runnable and ready to wire.

## Commands for the orchestrator

```powershell
cd C:/QM/repo
python -X utf8 tools/strategy_farm/lineage_map.py --summary        # rebuild all outputs
python -X utf8 -m pytest tools/strategy_farm/tests/test_lineage_map.py -q
```

Patch: `scratchpad/patches_i/i2_lineage_map.patch` (4 repo files; the JSON + Vault page are regenerated by running the builder).
