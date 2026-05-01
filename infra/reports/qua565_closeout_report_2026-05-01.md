# QUA-565 Closeout Report

Date (UTC): 2026-05-01
Issue: QUA-565
Status Recommendation: done

## Delivery Commits

- `0d3e3ead` - Wire company operating model payload + schema + export validation + stale data docs.
- `730666bf` - Add public payload validator (`Test-PublicCompanyOperatingModel.ps1`).
- `d682c972` - Document validator in infra operator README.

## Acceptance Evidence

1. Menu/dashboard discovers Company Operating Model from JSON.
- `public-data/company-operating-model.json` includes:
  - `menu`
  - `dashboard.control_tower`
  - `dashboard.capability_cells`
  - `dashboard.process_loop`
  - `dashboard.sections`
  - `dashboard.first_48h_actions`

2. Stale-data behavior documented.
- `public-data/company-operating-model.json` includes `updated_at`, `cache_ttl_minutes`, and `dashboard.stale_data_behavior`.
- `public-data/README.md` documents UI behavior: render `As of <updated_at>` and stale warning when TTL is exceeded.

3. Schema validation passes.
- Export script validates against `public-data/company-operating-model.schema.json`.
- Verified with:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\export_public_snapshot.ps1 -RepoRoot C:\QM\repo -PublicDataDir C:\QM\repo\public-data -NoGit`

4. Public-safety boundary enforced.
- Validator script `infra/monitoring/Test-PublicCompanyOperatingModel.ps1` asserts:
  - required sections present
  - non-empty menu
  - no private/internal issue URLs
  - no credential-like tokens
  - no GUID-like internal IDs

## Policy Note

Main branch pre-commit guard blocks QUA artifacts under `docs/ops/QUA-*` and `artifacts/qua-*` (`main_artifact_policy_violation`).
This report is stored under `infra/reports/` per repo policy guidance in `infra/README.md`.
