# Strategy Archive v2 — PASS/FAIL gate coverage preview

**Router task:** `1aed20ca-2824-434e-a8da-0970b913944a`
**OWNER decision:** `OWNER-DEC-ARCHIVE-PUBLIC`, Variant (b) — PASS/FAIL per
gate without numbers
**State:** prepared locally; not pushed or deployed

## Result

The standalone `strategy-archive.json` now has a closed v2 contract generated
from the same fail-closed `website_archive_contract.py` projection as
`public-snapshot.public_archive`.

Each item contains:

- opaque `public_id` (`card_<hash>`);
- `gate_coverage`, whose keys are Q00–Q17 and whose only permitted values are
  `PASS` or `FAIL`; and
- an optional mechanism-class sentence only when the approved card contains a
  redaction-safe public summary.

`UNTESTED` and `IN_PROGRESS` gates are omitted rather than falsely reported as
failures. The v2 schema has `additionalProperties:false` and has no place for
metrics, parameters, symbols, EA IDs, work-item IDs, paths, host/VPS data,
credentials, accounts, positions, or book state.

## Dry-run diff

Machine-readable diff:
`docs/ops/evidence/2026-09-02_strategy_archive_v2_dry_run_diff.json`.

- v1: 3,953 filename-derived rows with `slug/source/visibility/last_updated`.
- v2: 3,378 approved-card projections with 10,022 PASS and 1,298 FAIL terminal
  gate outcomes; every forbidden-field scan count is zero.
- v2 output SHA-256:
  `6d6749326413ea210161c1f7727464704f152a95d246f68a509aa51a58da062e`.
- schema SHA-256:
  `cd729be9525acfd5a4c9fb5eb55ca076f3c60ee77128862e0c3d9e07bee02aba`.

## Producer and validator

`website_archive_contract.py --public-bundle` emits the existing redacted
snapshot blocks plus `strategy_archive_v2` in one read-only DB pass. The
PowerShell exporter uses that projection directly; it no longer scans public
filenames to construct the standalone archive. Both native schema validation
and the Windows PowerShell fallback enforce Variant (b).

Verification:

- focused contract/snapshot suite: `73 passed, 1 skipped` (optional Python
  jsonschema only);
- PowerShell validator: all five positive and negative contract pairs PASS,
  including the v2 negative fixture containing a forbidden `metrics` object;
- exporter preview completed with `-NoGit` into
  `D:\QM\exports\public_archive_v2_task80_20260902\`;
- loopback site preview returned HTTP 200 for the page, loader, stats and
  snapshot routes; and
- Python compile, PowerShell AST parse, and `git diff --check` passed.

## Publication and unblock boundary

Generated v2 JSON is present only in the export directory and the uncommitted
local website preview. No deploy-repository commit, push, Netlify hook, or
public deploy occurred. The prior router task `2b95f500-...` can leave BLOCKED
for RECYCLE because the OWNER disclosure decision is now on record and its v2
artifact exists; it still requires normal review before publication.
