# Guarded public-data publisher — prepare-only verification

**Router task:** `94cad0f7-5fe8-43cf-b077-b056cdd83ee2`

## Result

The hourly snapshot runner now has two explicit modes:

- default: exporter retains `-NoGit`; the canonical five JSON files are
  schema-validated, then the allowlisted bundle is synchronized into the local
  deploy repository and committed there without a push;
- publish: `-Publish` or exact `QM_PUBLIC_PUBLISH=1` drops exporter `-NoGit`,
  permits the canonical source commit/push, and adds deploy-repository push.

The incident guard must pass before generation in either mode. The runner
releases the exact factory-mutation lock, validates all five positive and
negative public contracts, and only then reaches any Git or network command.
An alternate exporter `-OutputDir` can never invoke Git, even if `-NoGit` was
omitted.

## Deterministic deploy sync

`scripts/sync_public_data_to_website.ps1` has a closed mapping for five JSON
files, their five schemas, and the versioned stats loader. It validates before
copy, skips byte-identical files, verifies SHA-256 after each atomic copy, and
uses explicit Git pathspecs. `-Commit` requires `-Apply`; `-Push` requires both.
`netlify.toml` is outside the mapping and remains unchanged with publish root
`Website`.

The versioned loader uses `/public-data/public-snapshot.json` as its primary
contract, overlays `/public-data/stats.json` when available, and retains
`/data/stats.json` only as the compatibility fallback. Snapshot normalization
derives compiled EAs, cards, work items, and the 18 Q-gate count without exposing
terminal or infrastructure data.

## Local verification

- focused snapshot, incident-guard, archive, and publisher suite:
  `78 passed, 1 skipped` (optional Python jsonschema);
- PowerShell AST parse: four publisher/validator scripts PASS;
- public validator: all five positive/negative schema pairs PASS;
- exporter with a fresh alternate output directory and without `-NoGit`:
  five files written, `Git publication skipped for non-canonical OutputDir`,
  source HEAD unchanged;
- canonical and deploy-preview stats loaders have identical SHA-256
  `9a306f6eaef1b05d7bdbc4ce0bff02d024403eee1925d7e96a4649c0c0b32438`;
- both loaders pass `node --check`; and
- `git diff --check` PASS on scoped canonical changes.

The machine receipt
`docs/ops/evidence/2026-09-02_public_data_publish_dry_run_receipt.json` records
validation success, 11 allowlisted targets and the exact validation, copy,
deploy `git add`, explicit-path `git commit`, and `git push` commands. Its
executed list contains validation only: `apply=false`, `commit=false`, and
`push=false`.

## Stop boundary

This cycle did not run the guarded publisher, create a deploy-repository commit,
push either repository, call a Netlify hook, or deploy the site. The deploy
preview remains local. Existing deploy-repository commits from other work are
not claimed by this task. Public release still requires an explicit OWNER go.
