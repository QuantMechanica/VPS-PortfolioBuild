# rb-surfaces evidence — operator surfaces rebaseline

Date: 2026-08-23

Ticket: `rb-surfaces` / proposal ticket 7

Scope: read-only operator surfaces and additive public snapshot contract

## Result

Implemented a shared, read-only operator-surface model that reports, for every
`(EA, Symbol)`, the highest observed gate beside
`highest_contiguous_valid_gate`. It renders three manifest-derived macro-phase
bands, retains the `gate_contract_version` provenance of historical rows, and
reports the existing book-build guard measurements without changing its
minimum, criteria, orders, work items, or verdicts.

The active manifest remains v3 and the v4 proposal remains READ_INERT. When the
active manifest has no `macro_phase` fields, the UI derives the three bands via
the v4 manifest's explicit `contract_equivalence` table; it does not infer a
renumbering by ordinal.

## Code evidence

- Shared operator model and HTML: `tools/strategy_farm/operator_surfaces.py:40`
  (`macro_phase_bands`), `:156` (`build_operator_snapshot`), and `:231`
  (`render_operator_surface_html`). The census and guard are imported rather
  than reimplemented.
- Version-aware census reads: `tools/strategy_farm/rebaseline_census.py:125`
  translates stamped phases with `phase_qid`; `:191` and `:220` tolerate an
  unmigrated DB by selecting `NULL` when `gate_contract_version` is absent;
  `:382-384` expose observed and contiguous-valid provenance labels.
- Book guard reuse: `tools/strategy_farm/book_build_guard.py:174-197` accepts an
  already-computed qualified-pair census while preserving the original default
  path and `MIN_QUALIFIED_PAIRS` value (25).
- Mission control contract: `tools/strategy_farm/mission_control_v2_data.py:218`
  uses version-aware labels, `:248-253` and `:561-569` join historical row
  stamps, and `:989-1004` publishes `operator_surface`; schema coverage starts
  at `:1240`.
- Cockpits: `tools/strategy_farm/render_cockpit_v2.py:868` renders the shared
  block; the legacy cockpit builds and renders the same block at
  `tools/strategy_farm/render_cockpit.py:2141` and `:4058`.
- Dashboard: `tools/strategy_farm/dashboards/render_dashboards.py:2348` performs
  version-aware phase normalization, `:2491-2505` retains row provenance, and
  `:3022` inserts the shared surface. Scratch-safe `--output-dir` and
  `--read-only` are defined at `:5154-5162`; the read-only path skips derived
  DB/cache refreshes and redirects the optional live-preset reader.
- Heartbeat: `tools/strategy_farm/heartbeat_snapshot.py:191-193` obtains the
  shared snapshot, and `:435-468` reports the three manifest-derived bands and
  book guard instead of a hardcoded gate funnel.
- Pipeline/public state: `scripts/build_pipeline_state.py:591` builds the
  additive Q00..Q17 v4 block through explicit manifest equivalence; `:633-661`
  adds the operator surface and separately labels both contracts. The legacy
  P-key list remains the deliberately frozen compatibility list at `:69`.
  `scripts/export_public_snapshot.ps1:279-301` emits the labeled frozen
  `by_phase` block and additive `by_gate_v4` block.
- Public schema: `public-data/public-snapshot.schema.json:39-91` requires the
  `legacy-p-frozen/v1` label on the compatibility block and the `v4` label plus
  Q00..Q17 on the additive block. The checked snapshot carries those labels at
  `public-data/public-snapshot.json:13` and `:30`.
- Tests: `tools/strategy_farm/tests/test_operator_surfaces_rebaseline.py:57`
  renders a mixed-v3/v4 fixture and asserts provenance, all three phase bands,
  the 1/25 book-guard state, and no raw legacy-P HTML; `:92` checks versioned v4
  funnel translation; `:108` validates the checked snapshot against its schema.

No hardcoded gate-name table was added to a renderer: gate names are supplied
by `phase_label(..., include_name=True)` / the manifest loader. Storage-phase
SQL literals remain storage selectors as allowed by the ticket.

## Verification evidence

Focused touched-module and contract suite:

```text
python -m pytest tools/strategy_farm/tests/test_gate_manifest.py tools/strategy_farm/tests/test_gate_contract_version.py tools/strategy_farm/tests/test_rebaseline_census.py tools/strategy_farm/tests/test_book_build_guard.py tools/strategy_farm/tests/test_operator_surfaces_rebaseline.py tools/strategy_farm/tests/test_render_cockpit_v2.py tools/strategy_farm/tests/test_mission_control_v2_data.py tools/strategy_farm/tests/test_dashboard_pipeline_books_programme.py tools/strategy_farm/tests/test_render_cockpit_cohorts.py tools/strategy_farm/tests/test_health_agent_lane_heartbeat.py tools/strategy_farm/tests/test_mnt003_heartbeat_ignorenew_benign.py tools/strategy_farm/tests/test_pipeline_state_installer.py tools/strategy_farm/tests/test_public_snapshot_incident_guard.py -q -ra
108 passed, 3 skipped in 6.61s
```

The skips are two optional-`jsonschema` tests (module unavailable) and one
documented live-preview fixture predating the risk-freeze field. Independent
PowerShell schema validation passed:

```text
Get-Content -Raw public-data/public-snapshot.json |
  Test-Json -SchemaFile public-data/public-snapshot.schema.json -ErrorAction Stop
public_schema=PASS
```

Syntax and whitespace verification:

```text
python -m py_compile <all touched Python modules>
PASS
git diff --check
PASS (Git only reported expected LF/CRLF checkout warnings)
```

Real DB, read-only census result:

```text
build_operator_snapshot(D:/QM/strategy_farm/state/farm_state.sqlite)
pairs=14489 bands=3 qualified=0
```

All DB opens used `file:...?...mode=ro` plus `PRAGMA query_only=ON` where a
derived clean view is installed. No queue, verdict, factory flag, threshold, or
live-terminal mutation was performed.

Real scratch renders (never the live dashboard output directory):

- `C:/QM/worktrees/rb-surfaces/scratch/rb-surfaces/rendered/cockpit.html`
  — 2,164,566 bytes.
- `C:/QM/worktrees/rb-surfaces/scratch/rb-surfaces/rendered/dashboards/strategies.html`
  — 3,538,254 bytes; generated with `--strategies-only --read-only`.
- `C:/QM/worktrees/rb-surfaces/scratch/rb-surfaces/rendered/mission_control_v2.json`
  — 5,410,439 bytes; mission-control contract validation passed.
- `C:/QM/worktrees/rb-surfaces/scratch/rb-surfaces/pipeline_state.json`
  — 6,648,758 bytes; generated via the new scratch `--output` path.

Raw legacy-P grep guard over both rendered HTML files:

```text
pattern: \b(?:G0|P(?:1|2|3(?:[._]5)?|4|5[bc]?|6|7|8|9b?|10))\b
legacy_html_hits=0
```

The full `tools/strategy_farm/tests` run was attempted. It reached 6% and then
stalled for several minutes in a long integration section, so it was
interrupted rather than misreported as complete. All ticket/touched-module
tests above completed.

## Pre-existing dashboard-suite blocker

The pipeline-books tests were red before this ticket's edits and remain red:

```text
python -m pytest tools/strategy_farm/tests/test_pipeline_books_dashboard_status.py tools/strategy_farm/tests/test_render_cockpit_pipeline_books.py -q -ra
30 failed, 20 passed in 5.06s
```

All 30 failures fail closed from the same sealed FTMO source mismatch before
the changed operator renderer is evaluated:

```text
$.official_sources.snapshot_sha256 mismatch
expected=60f94e0d1d3ff5f64582c6274ef1cffe25383806b9a718104f3a34ad89384b72
actual=5c0763bb4213208f2bf71ee45f13e38eab675c13508569d8a092fe6e97b81bad
```

Changing that hash binding is outside `rb-surfaces` and would violate the
ticket's prohibition on changing gate criteria/contracts. The renderer-specific
programme test included in the 108-test suite passes; no pipeline-books source,
binding, rulepack, threshold, or test was changed here.

## Rollback

Revert the single `rb-surfaces` commit with `git revert <commit-sha>`. This
removes the shared surface, renderer insertions, scratch CLI options, and
additive public contract together. The scratch files are ignored, disposable
artifacts and can be removed separately; rollback requires no database action
because this ticket made no database writes or migrations.
