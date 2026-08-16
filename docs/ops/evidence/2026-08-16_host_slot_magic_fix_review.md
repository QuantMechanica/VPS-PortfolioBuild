# Host-slot magic fix — implementation and runtime review evidence (2026-08-16)

Task: `18954866-6166-4529-8ec6-8485ef25c023`

Verdict: **implementation verified; leave in REVIEW**. The framework identity
defect is fixed and the required QM5_11424/GBPUSD real-MT5 proof now emits
economic evidence. The corrected Q04 result is a strategy `FAIL`, not an
infrastructure failure or a promotion authorization.

## Root cause and fix

`QM_EntryRequest.symbol_slot == 0` is a relative host-slot default. Before the
fix, the entry path treated it as absolute registry slot 0, even when framework
initialization had already resolved a non-zero host offset. For QM5_11424 on
GBPUSD this changed order ownership from registry magic `114240001` to foreign
magic `114240000`, disconnecting Q04/Q08 accounting and the kill switch.

The implementation now:

1. binds `g_qm_fw_magic` into the entry subsystem during framework
   initialization, scoped to the exact EA id and host symbol;
2. resolves `explicit_magic == 0 && symbol_slot == 0` to that bound host magic
   in `QM_Entry` and the host leg of `QM_BasketOrder`;
3. preserves explicit magic and continues to resolve non-host slots through
   the registry;
4. fails closed in `QM_MagicChecked` when `(ea_id, slot)` is registered to a
   symbol other than `expected_symbol`, before collision acceptance.

The resolver defense was already durably committed in `2d00fd67e30d1b53cd12ecede0618068d9d3e3f3`.
The entry/common/basket changes, detector, tests, and affected-set artifact were
captured on `agents/board-advisor` in `bddb7600d125631911081911ec5d73c2d7e03805`;
a concurrent board-advisor commit included unrelated QM5_11388 files, so review
must use the explicit paths listed below. Test cleanup is
`24d66ff20acdaca35ace0456337920ef1bdaedc5`. Stage-A binaries are isolated in
`4af5419f7842762a1d4f3a87fdbf88f68dabba63`.

Scoped implementation paths:

- `framework/include/QM/QM_Entry.mqh`
- `framework/include/QM/QM_Common.mqh`
- `framework/include/QM/QM_BasketOrder.mqh`
- `framework/include/QM/QM_MagicResolver.mqh`
- `framework/tests/unit/entry_execution_identity_smoke.mq5`
- `tools/strategy_farm/scan_host_slot_magic.py`
- `tools/strategy_farm/tests/test_host_slot_magic_resolution_static.py`
- `tools/strategy_farm/tests/test_scan_host_slot_magic.py`

## Why QM5_10571 was immune

The proposed V3 explanation is disproved. QM5_10571 uses legacy
`QM_FrameworkInit`, not `QM_FrameworkInitV3`. Its EA-local reachable include
`framework/EAs/_mql5_codebase_rebuild_common.mqh` assigns
`req.symbol_slot = Strategy_SymbolSlot()`, and `Strategy_SymbolSlot()` returns
`qm_magic_slot_offset`. It therefore submitted the correct absolute slot 3 and
magic `105710003` before this framework fix. No scanned EA source invoked
`QM_FrameworkInitV3`; V3 validation would reject identity drift but was not the
source of the correct identity here.

## Corrected affected set

The corrected scanner strips comments and literals, resolves reachable
EA-local includes, inspects actual framework entry boundaries, distinguishes an
untouched default from an explicit literal zero, and joins registry rows by
exact EA slug. Its machine-readable output is
`docs/ops/evidence/2026-08-16_host_slot_magic_affected_set.json`.

| Measure | Result |
|---|---:|
| EA sources scanned | 3,579 |
| pre-fix affected source paths | 706 |
| immune explicit-identity sources | 2,855 |
| affected EAs with active non-zero slots | 175 |
| true affected `(EA, symbol)` pairs | 858 |
| default-relative-host exposures | 790 |
| literal-zero-relative-host exposures | 68 |
| include-resolved false-positive source paths removed | 11 |

Against the prior 797-pair artifact, 30 false-positive pairs were removed and
91 missed pairs were added. The older file was therefore not a true upper
bound: it over-counted reachable helper wiring while missing literal-zero calls.

## Verification

- Focused Python/reference suite:
  `25 passed, 2 subtests passed in 83.81s`.
- Build guardrails passed for all Stage-A sets with a stale-news ceiling of
  336 hours; each set has `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Fresh builds, each with zero warnings:

| EA / Stage-A reason | EX5 SHA-256 |
|---|---|
| QM5_11424 / required first proof | `4e2448aae80a1f9af301373374bb55dbdf7e31c530de7859bc0578d4326c13b4` |
| QM5_10649 / open Q04 row | `1f00b414484b67e01fc66ded8606e7818ae336585a9c8890f946ff2ce33d7d9c` |
| QM5_2002 / open Q04 row | `22e4d414a9ece321df02f5fdbce35568269e05fc0bf3127b8821e19deec517ec` |

## Real Q04 proof

The governed append-only rerun is work item
`93dbb878-fa90-4546-840d-fd5c4db9d35d`, preserving the earlier terminal row
`536bb9c7-4c86-4676-a762-83573513012a`. T3 copied and verified the rebuilt EX5
before launch. All three folds completed with exit code 0 and
`commission_basis=venue_dxz_stream`:

| Fold | OOS | Trades | PF-net | Fold status |
|---|---:|---:|---:|---|
| F1 | 2023 | 14 | 0.8108956503 | OK |
| F2 | 2024 | 17 | 0.8476205293 | OK |
| F3 | 2025 | 20 | 0.6960393170 | OK |

Aggregate Q04 verdict: `FAIL`, reason
`F1:pf_net=0.811;F2:pf_net=0.848;F3:pf_net=0.696`. This is the required
economic verdict and is pipeline evidence only; it does not support promotion.

Both previously absent Common-Files outputs now exist. The final-fold stream
contains 20 rows, all for `GBPUSD.DWX` and magic `114240001`; the EA-side
`q04_sim` file also exists. The final-fold logger proves:

| Event | Count | Unique magic | Relative slot |
|---|---:|---:|---:|
| `KILL_SWITCH_INIT` | 1 | 114240001 | — |
| `INIT` | 1 | 114240001 | — |
| `ENTRY_ACCEPTED` | 33 | 114240001 | 0 |

Thus `ENTRY_ACCEPTED magic == INIT magic == KILL_SWITCH_INIT magic` while the
strategy continues to use the documented relative host slot. The canonical
machine-readable snapshot is
`docs/ops/evidence/2026-08-16_host_slot_magic_runtime_proof.json`; the source
pipeline aggregate SHA-256 is
`88a19ffc687c2316f207e4cd24252ddfdf6438265cea6dc1c7a05a3b2a47e5a0`.

A preliminary direct attempt was rejected by the custom-history admission gate
before MT5 launch because it lacked a worker-bound work item. Its misleading
canonical failure summary was removed; only the governed append-only rerun is
used as runtime evidence.

## Rebuild staging and review boundary

Stage A is built: QM5_11424 plus the two affected EAs with currently open Q04+
rows, QM5_10649 and QM5_2002. At the final queue snapshot, those two Q04 rows
remain pending. QM5_10649 is still hash-bound to its prior binary
`9761025c...`; it must fail closed and receive a new append-only row bound to
`1f00b414...` after the current row terminalizes. QM5_2002 has no frozen EX5
binding and will bind the canonical rebuilt binary at dispatch.

Stage B is mechanically and exactly defined as the 172 EAs in the affected-set
artifact's `affected_eas` list after excluding the three Stage-A EAs. Mass
rebuild/requalification is intentionally not self-approved from this REVIEW
task. After OWNER/Claude acceptance, scheduling must consume that deterministic
set, preserve magic-registry order of operations, and use append-only
requalification where terminal evidence already exists.

No T_Live or AutoTrading setting was changed, no terminal was launched
manually, and no active T1-T10 job was interrupted.
