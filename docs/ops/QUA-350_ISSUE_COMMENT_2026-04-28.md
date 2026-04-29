# QUA-350 Status Update (DevOps)

`status`: ready for `in_review`

- Completed Darwinex bond-CFD inventory check for US10Y + Bund10Y via MT5-backed probe.
- Final result: both symbols missing (`US10Y`, `DE10Y/BUND` absent in broker/custom/staging/import evidence).
- Disposition gate: `both_missing_external_shim_or_defer` -> `_v2` needs FRED shim or defer per OWNER/CEO/CTO decision.

Artifacts:
- `infra/reports/darwinex_bond_inventory_latest.md`
- `docs/ops/QUA-350_BOND_CFD_INVENTORY_RESULT_2026-04-28.md`
- `docs/ops/QUA-350_BOND_CFD_INVENTORY_RESULT_2026-04-28.json`
