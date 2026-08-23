# Strategy Archive Matrix — Build-Hash Coverage Measurement (2026-08-23)

**Task:** router `2ee6427d-3c95-4504-a006-d21ca38c87f4` (`QM-TODO-20260823-501`), step 1 of
`docs/ops/STRATEGY_ARCHIVE_MATRIX_SPEC_2026-08-23.md` §14: "Messung vor dem Prototyp:
Build-Hash-Abdeckung je Zelle (entscheidet F4 (b) gegen (a))".

**Method:** `tools/strategy_farm/measure_archive_matrix_hash_coverage.py` (read-only, uses
`work_item_clean_view.open_clean_view_connection`, `PRAGMA query_only=ON`). Latest row per
(ea_id, symbol, base-Qxx-phase) triple for Q02–Q13, same population the matrix will render.
For each latest row, read `expected_current_ex5_sha256` / `expected_ex5_sha256` from
`payload_json`; compare against the EA's current on-disk `.ex5` hash
(`framework/EAs/<ea_dir>/<ea_dir>.ex5`, sha256).

## Result

| Metric | Value |
|---|---:|
| Cells measured (latest per ea/symbol/gate, Q02–Q13) | 25,067 |
| Cells carrying an expected-build-hash field | 4,292 |
| **Coverage** | **17.12 %** |
| EAs with a resolvable current `.ex5` hash | 3,502 (all referenced EAs resolved) |
| Covered cells matching current build | 3,870 |
| Covered cells stale (verdict ran against a since-rebuilt `.ex5`) | 422 |

Full stale-cell list: `docs/ops/evidence/archive_matrix_stale_cells_2026-08-23.csv` (422 rows,
ea_id/symbol/gate/verdict/updated_at + 16-char hash prefixes for both sides).

## Decision — F4 resolved to (a), not (b)

Spec §11a F4 conditioned the choice on this exact measurement: *"Abdeckung vor dem Prototyp
messen — reicht sie nicht, wird es (a) mit sichtbarem Warnhinweis."* 17.1 % coverage means
**82.9 % of cells have no expected-hash field at all** — those older rows predate the
`expected_ex5_sha256` payload convention. A per-cell hollow/stale marker built on this field
would render as a solid, confident PASS for the vast majority of the matrix regardless of
whether the underlying EA was rebuilt since, which is worse than not attempting staleness at
all (false confidence, not honest absence).

**F4 → (a): show the latest verdict, identity ignored, with a page-level warning banner** (not
a per-cell chip) stating build-hash staleness cannot be measured for the majority of cells and
citing this coverage number. The 422 rows that *do* carry a hash and *are* stale are known —
worth surfacing as a footnote/filter ("422 of 4,292 hash-checked cells are stale-pass"), but not
as a general seven-state feature since 83 % of cells can't be evaluated.

This changes spec §4/§11a: state 2 ("PASS bedingt", stale-pass-hollow) as originally scoped
(build-hash-driven) does not ship in the prototype. `PASS_SOFT`/`PASS_LOWFREQ` still render as
grey-hollow (that part of state 2 was never hash-dependent). Six effective states ship, not
seven; VOID, hole, and PASS-conditional-by-verdict-name remain as specified.

## Next step

Per §14: prototype on real data (Q02–Q13 triple aggregation is now proven cheap — the same
query above ran in a few seconds over the full DB), page-size + sort-latency measurement, then
OWNER acceptance, then full build in `render_dashboards.py` (Codex candidate per the routed
task's own `next_step_after_answers`). Left for a subsequent cycle — this cycle closes the
hash-coverage prerequisite only.
