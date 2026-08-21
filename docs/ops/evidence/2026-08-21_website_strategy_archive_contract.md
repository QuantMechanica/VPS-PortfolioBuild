# Evidence — Website Strategy-Archive Contract (staging)

**Date:** 2026-08-21
**Task:** QM-TODO-20260820-003 · router `ee42fad4`
**Author:** Claude (board-advisor worktree)

## What landed

| File | Purpose |
|---|---|
| `tools/strategy_farm/website_archive_contract.py` | Read-only generator + fail-closed redaction |
| `tools/strategy_farm/tests/test_website_archive_contract.py` | 38 redaction + contract-shape tests |
| `docs/ops/WEBSITE_STRATEGY_ARCHIVE_CONTRACT.md` | Contract spec v1 |
| `D:\QM\exports\website_contract_preview\*.json` | STAGING output (not committed, not published) |

## Measured facts

### Generator run on the live farm DB (read-only)

Command: `python tools/strategy_farm/website_archive_contract.py`

```
counts: {
  "eas": 3737,
  "cards": 3271,
  "gate_results": 24811,
  "reports_referenced": 23506
}
wrote:
  strategy_summaries.json     D:\QM\exports\website_contract_preview\strategy_summaries.json
  strategy_cards_public.json  D:\QM\exports\website_contract_preview\strategy_cards_public.json
  gate_results.json           D:\QM\exports\website_contract_preview\gate_results.json
  report_manifest.json        D:\QM\exports\website_contract_preview\report_manifest.json
  index.json                  D:\QM\exports\website_contract_preview\index.json
```

gate_contract_version = `qm.gate-manifest/v2#721b9b8821ff`

### Tests

```
python -m pytest tools/strategy_farm/tests/test_website_archive_contract.py -q
38 passed in 0.52s
```

Coverage: absolute Windows/UNC/`file://`/POSIX paths, IPv4, labelled
account/login/magic numbers, credential assignments, benign-number preservation,
allowlist drop-by-default, forbidden-key refusal even when allowlisted, nested
dict/list scrubbing, card projection + grading + ML-violation block, id
reconciliation, opaque report ids, legacy-era labelling, full build+write shape
on a synthetic DB, and the public-data-dir write refusal.

### Redaction leak scan on the real staged output

Applied the generator's own forbidden patterns (`_FREE_TEXT_PATTERNS`) to every
parsed string value in all five output files:

```
gate_results.json:        0 real leaks
index.json:               0 real leaks
report_manifest.json:     0 real leaks
strategy_cards_public.json: 0 real leaks
strategy_summaries.json:  0 real leaks
TOTAL REAL LEAKS: 0
```

(A naive byte-grep for `[A-Za-z]:\` reported hits in the cards file; each was a
JSON-escaped newline `setup:\n` in card markdown, not a path — confirmed by
re-scanning parsed string values with the actual path regex, which requires a
literal backslash after the colon.)

### Cross-file join integrity (real output)

```
dangling card refs (summary.card_id not in cards):      0
dangling report refs (gate.report_id not in manifest):  0
gate EAs missing a summary row:                          0
reconciled-id cards (bare frontmatter id -> filename):  16
non-QM5 summary ids:                                     1  (bare '20022', upstream artifact)
```

## Safety boundary (verified)

- Generator writes only to `D:\QM\exports\website_contract_preview\`.
- `_assert_staging_only` raises `SystemExit` for any path inside `public-data/`
  (test `test_write_refuses_public_data_dir`).
- No call to `scripts/export_public_snapshot.ps1` or
  `tools/strategy_farm/public_snapshot_incident_guard.py`.
- Farm DB opened read-only via `work_item_clean_view.open_clean_view_connection`
  (TEMP view, `query_only` asserted); zero writes to `farm_state.sqlite`.
- No scheduled task, terminal, T_Live, or live-account surface touched.

## Rollback

Delete the three repo files above + the staging tree. No DB / public-data /
exporter / task state was mutated, so removal is complete rollback.

## Open follow-ups (see spec §7)

1. Full staleness engine (BUILD/CARD/DATA/COST_MODEL_CHANGED).
2. JSON Schema files + `validate_public_snapshot.ps1` wiring.
3. Q04 fold sub-rows / hierarchical sub-tests.
4. Upstream fix of 16 card-frontmatter id defects + bare `20022` work-item id.
