# Registry Gap Retirement Evidence — 1001 / 1015 / 1016

- Date: 2026-08-26
- Router task: `780c7c37-3acb-4316-9c34-147dbf8dc5d1`
- Execution checkout: `C:/QM/repo`
- Execution branch: `agents/board-advisor`
- OWNER decision: `decisions/2026-08-26_owner_registry_gap_option_b.md`
- OWNER decision SHA-256: `DDF7ADCB837C4B1D28653DD9B8934D1EB0A15031440FC344A2F138F0A591AA29`

## Authorization and bounded change

The OWNER selected Option B: re-intake the three strategies through fresh Strategy
Cards and do not reanimate the legacy reservations. The decision explicitly makes
retirement of EA IDs 1001, 1015, and 1016 an inherent implementation step.

This operation is bounded to status-only retirement:

- change the three matching `ea_id_registry.csv` rows from `active` to `retired`,
  recording retirement metadata;
- change the 107 matching `magic_numbers.csv` rows from `active` to `retired`;
- preserve every magic value and every unrelated row;
- regenerate `QM_MagicResolver.mqh` in strict-default mode, without
  `--allow-dropped`;
- do not allocate a replacement identity and do not advance any pipeline verdict.

## Preflight evidence

At preflight, the three EA registry rows were active:

| ea_id | strategy_id | EA directory | work items | active magic rows |
|---:|---|---:|---:|---:|
| 1001 | TBD | 0 | 0 | 35 |
| 1015 | SRC04_S09 | 0 | 0 | 36 |
| 1016 | SRC04_S11 | 0 | 0 | 36 |
| **Total** | | **0** | **0** | **107** |

Strict-default resolver preflight refused generation with exit code 2 because
these exact three active EA IDs had no materialized directory. No recovery flag
was used.

Preflight SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| `framework/registry/ea_id_registry.csv` | `1C5D7102ABE02CD9975E214ABF1B4399B690990DE5EA96336C32A240BFAF9BF1` |
| `framework/registry/magic_numbers.csv` | `BF6B36DD6E27CC3FA241DE3285EB9CC5FF96F0F6451F5A387ED936F69D5C056C` |
| `framework/include/QM/QM_MagicResolver.mqh` | `37C11946495D2508B3CF62923A719F6550EF348181AF0C1A9F39B04C06DB920C` |

## Governed command guard

`farmctl retire-ea-ids` retains its default refusal when an EA ID owns magic
rows. Commit `f2d1134923769c4e94622c9fb896aa0af9f0f011` adds an explicit
`--retire-magic-rows` cascade that changes only active magic-row status under the
same registry lock, emits before/after hashes and row counts, and restores exact
pre-write bytes if either registry write fails.

Focused pre-apply verification:

```text
python -m pytest tools/strategy_farm/tests/test_ea_id_retirement.py tools/strategy_farm/tests/test_governed_magic_allocator.py framework/scripts/tests/test_magic_resolver_strict_default.py -q
19 passed
```

## Apply and verification

The guarded operation was run serially. Its dry-run reported `ok=true`,
`planned_count=3`, `planned_magic_row_count=107`, and `refused_count=0` before
the apply flag was supplied. The apply reported `applied_count=3`,
`applied_magic_row_count=107`, and `refused_count=0`.

Receipts:

| Mode | Receipt | SHA-256 |
|---|---|---|
| dry run | `docs/ops/evidence/2026-08-26_ea_id_retirement_dry_run_20260826T031129Z_22f4dac9.json` | `5A64DD710DD5EF2AF0CA400B7CBF0774772426B90A6D44C32D3D1F5AE7DD487C` |
| apply | `docs/ops/evidence/2026-08-26_ea_id_retirement_apply_20260826T031138Z_3cccefa9.json` | `FCAAE94A5FE6FB77D70EDE901BC01401A6A5F850926F9BA51944F5DD1F51B6CE` |

The apply timestamp recorded on all three EA rows is
`2026-08-26T03:11:38+00:00`. Post-apply counts are:

| ea_id | EA status | active magic rows | retired magic rows |
|---:|---|---:|---:|
| 1001 | retired | 0 | 35 |
| 1015 | retired | 0 | 36 |
| 1016 | retired | 0 | 36 |
| **Total** | | **0** | **107** |

A row-by-row comparison of `magic_numbers.csv` against the pre-apply Git object
found 107 changed rows and zero invalid rows: every changed row belonged to one
of the three authorized IDs, and the sole changed field was `status` from
`active` to `retired`. Row order, symbols, slots, and magic values are unchanged.
The EA registry diff contains exactly three changed rows and only the authorized
status plus retirement metadata. Registry and generated-include changes are
committed as `85a9336f11dc795ed5ddb065351a67c9a7840a08`.

Post-apply SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| `framework/registry/ea_id_registry.csv` | `CB41AD10883DBD4A173124E2BEA1EB8F536754959D902E1F1F4BD497155164B9` |
| `framework/registry/magic_numbers.csv` | `A6681BE458CF9B0C4B24571277987741882BD49A665E7BDC26E372560D207373` |
| `framework/include/QM/QM_MagicResolver.mqh` | `C8D751396D15AF42C38A89A8D7373A5658BE5C17946755C8B156FD2D8C461E0C` |

## Strict resolver result

`update_magic_resolver.py` was run without `--allow-dropped`. The real
regeneration and a repeat strict dry-run both returned success:

```text
[OK] wrote framework\include\QM\QM_MagicResolver.mqh — 17898 rows kept, 0 dropped, sha=A6681BE458CF9B0C...
[dry-run] 17898 rows kept, 0 dropped, sha=A6681BE458CF9B0C...
```

The generated include declares 17,898 rows and embeds the full post-apply magic
registry hash. Parsing the EA-ID array confirmed that exact IDs 1001, 1015, and
1016 are absent. The prior strict-default refusal class is therefore gone; no
exception or recovery flag was used.

## Focused test and compile evidence

The post-regeneration resolver, retirement, and allocator suite passed:

```text
python -m pytest -q framework/scripts/tests/test_magic_resolver_binary_search.py framework/scripts/tests/test_magic_resolver_symbol_fail_closed.py framework/scripts/tests/test_magic_resolver_strict_default.py framework/scripts/tests/test_magic_resolver_hash_newlines.py tools/strategy_farm/tests/test_host_slot_magic_resolution_static.py tools/strategy_farm/tests/test_magic_resolver_reconcile_newlines.py tools/strategy_farm/tests/test_ea_id_retirement.py tools/strategy_farm/tests/test_governed_magic_allocator.py
35 passed in 6.27s
```

An isolated minimal EA compiled the newly generated include through MetaEditor;
no terminal was started and no canonical EA binary was rebound. The compiler
reported `0 errors, 0 warnings`.

| Compile artifact | SHA-256 |
|---|---|
| `D:/QM/build/resolver_compile_probe_780c7c37/QM_MagicResolver_CompileProbe.mq5` | `AB61B7BB5934AF75574608B0F6B3EF9099C6D8DFA32A1073B7E80A90B330887D` |
| `D:/QM/build/resolver_compile_probe_780c7c37/QM_MagicResolver_CompileProbe.compile.log` | `E15FCD71D89C90D59A8EA9D298CCD39ABBA0C1C81DEC00489F92E027BFEE1A44` |
| `D:/QM/build/resolver_compile_probe_780c7c37/QM_MagicResolver_CompileProbe.ex5` | `12092A8A58B06059B5E82DE52FF8405AFFF5B48C50ACFD8D605A945BE0376733` |

## Allocator refusal regression

With the committed registries and strict resolver clean, a bounded dry-run for
the exact approved card
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41140_nzdjpy-carry-unwind-crisis-momentum.md`
returned exit code 0, `finding_count=0`, and an `eligible` allocation plan for
one EA and one magic row. It requested no deletion of retired rows. This is the
same path that had aborted while the strict resolver could not reconcile the
three active, unmaterialized reservations.

Durable allocator proof:
`docs/ops/evidence/2026-08-26_780c7c37_allocator_refusal_clear.json`
(`D29B001211B2B3838A23F467129054E858E4C333BC0499E3634417A79BB5C798`).
The allocator was dry-run only; no identity or magic row was allocated.

## Verdict

`PASS_FOR_REVIEW`: the OWNER-authorized legacy reservations and all 107 bound
magic rows are retired without deletion or formula changes; strict resolver
regeneration, focused tests, an isolated compile, and allocator dry-run are all
green. No pipeline or deployment state was changed.
