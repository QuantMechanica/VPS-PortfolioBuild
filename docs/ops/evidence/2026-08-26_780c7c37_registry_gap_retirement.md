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

Pending governed serial apply. This section will be completed from emitted
receipts and post-apply checks before task handoff.
