# Stress-guard source-repair successor bindings — immutable authority evidence

Router task: `04f011a6-6b6a-4562-b2ee-f2cb6f641e5a`. Date: 2026-09-06.
Status: REVIEW; registration and dry-run only. No enqueue apply, compile, release or Q02 rerun is authorized by this artifact alone.

CEO task payload selects six source-only repairs integrated as `bb62d69619` from `1cf0b6d834`. The change replaces a zero-only stress rejection guard with a finite [0,1] check. The strategy equations and frozen strategy inputs are unchanged. QM5_41319 is excluded because its card is retired. Sources were hashed from canonical working-copy bytes; predecessor hashes are exact compile-row payload/column identities, verified equal. Each selected predecessor is latest, done / COMPILE_OK, and unclaimed. Older failed rows remain historical evidence and are not superseded or rewritten.

| EA | Old MQ5 SHA-256 | New MQ5 SHA-256 | Predecessor compile row | Rationale |
|---|---|---|---|---|
| QM5_41171_wti-mturnpoint-tr | `fbb3d7c70b1e6c16c2e09c1582ab3ab127ad34f35a33f7437d0bf72f23174ae6` | `8e255a1d5771ba55728038a6f1b030b3216c5645301e9517cd20ff6fbd1938dc` | `6a6bad94-24a9-4af6-810a-678471024f72` | Zero-only stress guard fix; no strategy change |
| QM5_41358_xtixng-wovershoot-rv | `3eb6bf7480baa24ae6525062ed2ed8e5cfcfe2daf645983e33cb2e9a5d875463` | `e17af3932822b85963edca0f0aeeed507f31e995e164ce2396dcabfb41cb5ee2` | `a3f0b993-f76a-41ff-80d3-79abc126f011` | Zero-only stress guard fix; no strategy change |
| QM5_41359_xtixng-waccel-rv | `d3538877ce2d1432ee10c19ef9b85b3616582cd8fc3deeaefabf6f12ea65ed1c` | `c1d77d11242cdf6c327705b1c91dfde0b41ad56c37af597a6ade0cdf6a5f337a` | `72fb26b3-2612-40a0-86a7-cdc3e7b38a63` | Zero-only stress guard fix; no strategy change |
| QM5_41360_xtixng-wretr-rv | `06439f8e8704564010135fe9c07c28ffeea703e9a871627035d6b0f6e56d9573` | `ca56d8fa78cf927e79696edbe510d372d7f503e95797edb7e8afefd177b3777e` | `be3fdc9a-6ba3-48ae-8b23-68db2fece85f` | Zero-only stress guard fix; no strategy change |
| QM5_41361_xtixng-commonshock-rv | `86b52bb43f6ec7f1625d53b2ca58ac606485dbec92ffac37da39a9b51051836b` | `e5e870501d852aca64fe2e6e30d7bc27b9a1c8d8874a3da11bdc945e0c25f99a` | `c5bf5069-ecfb-40a2-a0d7-2e282d8a7df1` | Zero-only stress guard fix; no strategy change |
| QM5_41362_xtixng-wdecel-cont | `19d28486b56ffe748a1aefe65665b9b601ee2ce22961e06860b5048ed5ec6f23` | `300debf2886b6dddbd5d8ec4aab5c45ef28d6ffcebd394b3985c5cc405c1de95` | `acfa4f4e-8e78-474d-a9da-fbb2b5dd128c` | Zero-only stress guard fix; no strategy change |

The registry binds this document's SHA-256 per registration. Do not append run results here: the separate `2026-09-06_stress_guard_source_repair_successors_review.md` records verification, preserving this authority hash. An unknown authority, wrong EA/source, missing or changed predecessor, claimed predecessor, changed evidence or unrelated in-flight compile is refused. Successors must retain these exact predecessor and evidence bindings during worker recheck. No completed predecessor is placed in the superseded-predecessor mutation list.

## CEO-only apply plan after code/evidence integration and acceptance

Each label file contains one exact label. Removing `--apply` runs the batch dry-run. These commands are recorded, **not executed**:

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-06_stress_guard_source_repair_successors/QM5_41171.txt --source-repair-authority router_ops_issue:04f011a6-6b6a-4562-b2ee-f2cb6f641e5a:QM5_41171 --apply
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-06_stress_guard_source_repair_successors/QM5_41358.txt --source-repair-authority router_ops_issue:04f011a6-6b6a-4562-b2ee-f2cb6f641e5a:QM5_41358 --apply
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-06_stress_guard_source_repair_successors/QM5_41359.txt --source-repair-authority router_ops_issue:04f011a6-6b6a-4562-b2ee-f2cb6f641e5a:QM5_41359 --apply
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-06_stress_guard_source_repair_successors/QM5_41360.txt --source-repair-authority router_ops_issue:04f011a6-6b6a-4562-b2ee-f2cb6f641e5a:QM5_41360 --apply
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-06_stress_guard_source_repair_successors/QM5_41361.txt --source-repair-authority router_ops_issue:04f011a6-6b6a-4562-b2ee-f2cb6f641e5a:QM5_41361 --apply
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-06_stress_guard_source_repair_successors/QM5_41362.txt --source-repair-authority router_ops_issue:04f011a6-6b6a-4562-b2ee-f2cb6f641e5a:QM5_41362 --apply
```

After applying through canonical code, CEO releases the governed compile wave and seeds append-only Q02 reruns against the new binary identity. Previous pipeline evidence remains bound to the old identity; this document gives no pipeline verdict. No T1–T10 test interruption, manual terminal start, T_Live action, AutoTrading change or set-file mutation is part of this registration task.
