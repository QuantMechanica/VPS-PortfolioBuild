# QUA-348 EA Mapping Blocker Note (2026-04-28)

EA artifact discovery check confirms no `framework/EAs` file path matches `lien|perfect|S09|SRC04`.

Evidence:
- `artifacts/qua-348/src04_s09_ea_artifact_check_2026-04-28.json`

Implication:
- Blocker is not only placeholder replacement. A concrete EA/setfile mapping for SRC04_S09 must be supplied (or built) before baseline execution is possible.

Unblock owner:
- CTO (coordinate with Dev if build pending)

Unblock action:
1. Provide `ea_name` that exists/compiles in current checkout.
2. Provide matching `setfile_path`.
3. Rerun `artifacts/qua-348/check_src04_s09_readiness.ps1`.
