# Evidence — rb-archive-public-website

Date: 2026-08-23

Decision: `OWNER-DEC-ARCHIVE-PUBLIC` (variant b)

Scope: public Strategy Archive gate states and public v4 pipeline-gates copy

## Outcome

The public snapshot now carries a fail-closed, number-free `public_archive` matrix and
an ACTIVE-v4-only `pipeline_gates` copy contract. The implementation reads the farm
database read-only, resolves each stored phase using its `gate_contract_version`, and
projects only the highest contiguous valid gate frontier. It does not publish, enqueue,
delete, or mutate farm state.

The OWNER decision is recorded at
`decisions/2026-08-23_owner_decisions_evening_batch_2.md:9`. The active topology and
three public macro phases are documented at
`docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md:27` and
`docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md:64`.

## Changes and code evidence

- `tools/strategy_farm/website_archive_contract.py:55` defines the four-value public
  state vocabulary and the ordered Q00..Q17 public gate sequence.
- `tools/strategy_farm/website_archive_contract.py:80` contains one-sentence,
  mechanism-level gate purposes paraphrased from the first Purpose/Zweck paragraphs
  of the corresponding vault `03 Pipeline/Qxx` pages. No criteria or thresholds are
  included.
- `tools/strategy_farm/website_archive_contract.py:302` resolves storage phases through
  `phase_ids.phase_qid(raw_phase, gate_contract_version)`, including collapsed storage
  lanes.
- `tools/strategy_farm/website_archive_contract.py:565` refuses to build website copy
  unless the loaded manifest is ACTIVE v4 with the exact Q00..Q17 sequence.
- `tools/strategy_farm/website_archive_contract.py:608` projects Q02..Q14 from
  `highest_contiguous_valid_gate`; isolated later evidence remains `UNTESTED`.
- `tools/strategy_farm/website_archive_contract.py:706` applies the same contiguous
  rule to Q15..Q17 and requires a valid Q14 frontier before phase three can appear.
- `tools/strategy_farm/website_archive_contract.py:779` reads the SQLite database via
  the repository's read-only `open_ro` helper, aggregates pair state to each approved
  card, emits an opaque public ID, and includes `public_summary` only when present.
- `tools/strategy_farm/website_archive_contract.py:845` strictly allowlists both block
  shapes and rejects numeric values, numeric copy, forbidden key classes, paths,
  emails, and identity tokens.
- `scripts/export_public_snapshot.ps1:170` invokes the public projection and applies
  an independent grep-style incident guard before the public snapshot is assembled
  at `scripts/export_public_snapshot.ps1:399`.
- `scripts/run_public_snapshot_task.ps1:133` passes the same database and Python
  inputs through the existing guarded scheduled-task path.
- `public-data/public-snapshot.schema.json:118` and
  `public-data/public-snapshot.schema.json:186` define strict schema contracts for the
  archive matrix and gate-page copy.
- `public-data/public-snapshot.json:53` contains the rendered archive block;
  `public-data/public-snapshot.json:75312` contains the rendered gate-page block.
- `docs/ops/PUBLIC_PIPELINE_GATES_V4_COPY_2026-08-23.md:1` is the website-consumable
  Markdown copy deck for an external website repository.
- `tools/strategy_farm/tests/test_website_archive_contract.py:468` covers version-aware
  mapping, contiguous-frontier behavior, aggregation, and the optional mechanism
  sentence. Lines 522, 536, 547, and 563 cover fail-closed redaction, active-v4 copy,
  schema pinning, and exporter wiring respectively.

## Scratch render evidence

Command (no publish and no push):

```powershell
pwsh -NoProfile -File scripts/export_public_snapshot.ps1 `
  -RepoRoot (Get-Location).Path `
  -PublicDataDir D:\QM\exports\rb-archive-public-website_20260823T175500Z `
  -PipelineStatePath D:\QM\reports\state\pipeline_state.json `
  -FarmDbPath D:\QM\strategy_farm\state\farm_state.sqlite `
  -FarmRoot D:\QM\strategy_farm `
  -PythonExe C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe `
  -NoGit -NoNetlifyFallback
```

Artifact:
`D:\QM\exports\rb-archive-public-website_20260823T175500Z\public-snapshot.json`
(5,626,901 bytes; `generated_at` is visible at artifact line 3, `public_archive` at
line 53, and `pipeline_gates` at line 75,312). Its SHA-256 is
`D018BB398E9393C18F1EAE04174BEFAE4EAB9BFC67C0A9D6E43E96078D36E972`, identical to
the checked-in `public-data/public-snapshot.json`.

Read-only inspection of that exact artifact returned:

```text
schema_valid=True
cards=3271 gates=18 macro_phases=3
states: FAIL=1243 IN_PROGRESS=410 PASS=9696 UNTESTED=47529
mechanism_sentences=0
windows_path=False email=False work_item_id=False threshold_key=False
assert_public_snapshot_blocks_safe=PASS
```

`mechanism_sentences=0` means none of the current approved cards has the exact optional
`public_summary` frontmatter field. The contract intentionally omits the sentence in
that case instead of inferring copy from private card content.

## Test evidence

Focused touched-module and safety suite:

```powershell
python -m pytest tools/strategy_farm/tests/test_website_archive_contract.py `
  tools/strategy_farm/tests/test_public_snapshot_incident_guard.py `
  tools/strategy_farm/tests/test_operator_surfaces_rebaseline.py `
  tools/strategy_farm/tests/test_factory_quiescence.py `
  tools/strategy_farm/tests/test_factory_mutation_lock.py `
  tools/strategy_farm/tests/test_factory_runtime_activation.py -q
```

```text
119 passed in 38.58s
```

Schema positive and negative fixtures:

```powershell
pwsh -NoProfile -File scripts/validate_public_snapshot.ps1 -RepoRoot (Get-Location).Path
```

```text
PASS public-snapshot
PASS process-roadmap
PASS strategy-archive
PASS company-operating-model
All public snapshot schemas validated (positive + negative).
```

Repository-wide farm suite attempted:

```powershell
python -m pytest tools/strategy_farm/tests -q
```

It was stopped after 429.20 seconds when it remained at 6% after producing 70 failures;
the partial result was `70 failed, 267 passed, 14 subtests passed, 2 warnings`. The
failures are outside this ticket and reproduce alone. For example:

```powershell
python -m pytest tools/strategy_farm/tests/test_agent_router.py -q --maxfail=1
```

```text
FAILED test_agent_router.py::AgentRouterTests::test_claude_disabled_flag_removes_claude_from_routing
StopIteration at tools/strategy_farm/tests/test_agent_router.py:137
1 failed in 2.08s
```

Other failures in that attempt were confined to the canonical agent-router writer and
agent-selection contract modules, which reject or omit writer state in this linked
worktree. No ticket-touched test failed.

## Risks and open questions

- Public card state is intentionally an `any symbol pair` aggregation. A PASS pair wins
  over a failing or in-progress pair, as documented in the contract code. This is a
  public competence view, not an operator diagnosis view.
- The current card corpus supplies no `public_summary` values, so mechanism sentences
  will begin appearing only when approved cards adopt that explicit public field.
- The unrelated agent-router failures prevent a clean repository-wide test-suite claim;
  the touched modules and all relevant incident guards are green.

## Rollback

Revert this ticket's commit with `git revert <commit>` from the current branch. This
removes the two public blocks, schema additions, exporter integration, generated
snapshot, copy deck, tests, and this evidence record without touching runtime farm
state. The scratch directory is outside the repository and may be retained as immutable
review evidence or removed separately.
