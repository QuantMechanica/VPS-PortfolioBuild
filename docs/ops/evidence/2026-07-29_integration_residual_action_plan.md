# Integration residual action plan — 2026-07-29

## Scope

The first Strategy-Farm integration run had 31 failing tests. The expanded
Strategy-Farm plus framework/scripts run exposed four additional stale/source
failures. Contract-preserving source and fixture corrections removed 30 of the
35 distinct findings. Five fail-closed acceptance checks remain because their
bound external or historical inputs are genuinely stale.
They are retained as plan items rather than weakened, skipped, or mechanically
rebound.

Factory remains intentionally OFF. No file below `D:\QM`, T_Live preset,
AutoTrading state, live task, or live terminal was changed during this triage.

## Safe integration corrections completed

- Agent-router and P2 fixtures were brought onto the current card, verdict,
  root-scope, and DWX contracts; 63 focused plus 38 adjacent tests passed.
- Phase-runner/cascade fixtures now carry the immutable process identity and
  permitted T1–T4/T6/T7 scope; 12 focused and 22 lineage tests passed.
- The synthetic QM5_10939 repair bundle now emits the exact period of each of
  its four segments instead of repeating the full eight-year period.
- The QM5_13207 setfile test hashes the Git-canonical LF source, so a Windows
  CRLF checkout cannot invalidate the bound repository content.
- The QM5_20007 rekey test now binds the deliberately committed post-rekey
  binary (`07ecef35...`) and proves it differs from the archived QM5_12784
  binary instead of requiring the newer binary to be absent.
- The P1.9 registry test no longer requires four transitional directories
  after the documented rename/archive pass completed.
- Repo-internal, Git-tracked text dependencies in the execution-contract
  linter now accept their exact raw hash first and their Git-LF hash second.
  External files, untracked inputs, and runtime setfiles remain byte-exact.
- FTMO M15 array/session caches now bind a weak reference to the actual
  DataFrame, reject recycled Python object IDs, and evict entries on GC; the
  former order-dependent IndexError has deterministic regression coverage.
- The P2 evidence-floor tests now distinguish the retained optional DL-082
  curve from the operative OWNER-selected flat 1.10 floor.
- Phase-orchestrator producer success fixtures use one unambiguous EA slug and
  an explicit successful build-verifier result. The separate Ghost-Build test
  still proves the production guard blocks fail-closed.

## Residual A — dated DXZ repair packets

### QM5_10939

`dxz_10939_gbpusd_h4_repair_spec_20260716.json` remains fail-closed with three
binding errors:

- repo EX5 expected `8fb85437bd67a51c2a0b050246632fc316b938b4992653479a83a573cb691e77`,
  current `0c1278f5d44d0c88db90f632d0cefacda79b6c8853bde9540676c4c95296edd0`,
  with a size mismatch;
- the historically bound live-preset locator is absent from the active
  Presets directory;
- the exact archived preset exists read-only below
  `_archiv_alte_setfiles`, 1,733 bytes, SHA-256
  `8cbed5104814da856484317e7f06add7d0e17aeb033cebe424b457b43c683206`.

### QM5_12567

`dxz_12567_xauusd_d1_repair_spec_20260716.json` remains fail-closed with eight
binding errors:

- repo EX5 expected `17e7faa9ef1800b204344b349e57024e3afb74d2cde494f07e63175ae9a7b870`,
  current `353dddbb93c393dc4135d03f84ba203b6f8ab657ce5ebb5b14cb9f6d44893c85`;
- live preset expected `28fb3b1ee3a15c2b0c625703dbddcd94115ac05407eebff7e7232f50fb6e0ce1`,
  current `9c86a54d8b160e08b9e38e9996079dd389917943d4d458f9a7c52dc6f7a9b759`;
- backtest preset expected `0d6da981da6d4a6060232109bd8cad975af81824329092d05a3a7580766ccc3a`,
  current `5e826eb3aa6d585f81dd36e6706f39131d0931b9e1963164c251ef5ed424dd97`;
- RiskSizer expected `e75d7aaa48f3eae0d298ac67ba0db4404089f9b1abc7ea361fee7662c342fbed`,
  current `5c25bb670d1226ae1c88391bff9b55b0551e7cc9704e06ce09a64f40bb779f71`;
- the active live-preset locator is absent; the exact archived file is 1,425
  bytes with SHA-256
  `2936790068d32b8a930cb4a0402b1ee084ee5135155c8ef3089d65cc733b94ec`.

Disposition: MNT-021 and MNT-043 must produce versioned packet amendments,
provenance-backed rebuild/requalification evidence, and an explicit OWNER/Ops
decision for the archived deployment locator. Historical hashes must not be
silently replaced and archived presets must not be restored into T_Live by an
agent.

## Residual B — execution contracts

The safe newline correction reduced the full registry from 76 to 49 issues and
the density cohort from 52 to 25. The remaining findings are real:

- 25 `runtime_setfile_hash_mismatch` findings whose declarations match neither
  current LF bytes, current CRLF bytes, nor any tracked historical form;
- 24 QM5_20009 calendar findings: eight source-hash, eight coverage, and eight
  copy-drift errors. Shared `D:\QM` inputs have advanced through 2026-07-31,
  while the bound QMDev1 Common copies remain at 2026-07-24.

The exact paths, row counts, hashes, and per-EA SET counts are recorded in
`2026-07-29_execution_contract_residual_triage.md`.

Disposition: MNT-021/MNT-043 must provenance-qualify the 25 setfiles before any
registry rebind. MNT-045 must validate the new calendar snapshot, publish the
shared/Common pair atomically, and obtain the required authorized contract
rebind. Until then, the three cleanliness tests remain intentionally failing.

## Acceptance and exit ordering

The exact retained checks are:

- `test_dxz_10939_repair_packet.py::test_real_spec_hash_bindings_pass`;
- `test_dxz_12567_xau_repair_packet.py::test_spec_is_hash_bound_blocked_and_xau_not_xng`;
- `test_execution_contract_lint.py::test_dxz23_registry_is_source_bound_and_structurally_clean`;
- `test_execution_contract_lint.py::test_density_execution_contracts_are_source_and_runtime_binding_clean`;
- `test_execution_contract_lint.py::test_20009_ftmo_news_calendar_is_exact_and_evidence_bound`.

The versioned machine-readable lane manifest is
`tools/strategy_farm/config/test_lanes.v1.json`. It does not mark any check as
skip or xfail. The explicit commands are:

```powershell
python tools/strategy_farm/test_lanes.py green
python tools/strategy_farm/test_lanes.py external-residual
```

The first command deselects only the five exact node IDs from the broad merge
lane; the second executes those five unchanged fail-closed assertions. A plain
repository-wide `pytest` remains intentionally red until the external bindings
are reconciled.

1. Keep Factory OFF and preserve the current five fail-closed checks.
2. Obtain the versioned DXZ packet amendments and setfile provenance decisions.
3. Complete the MNT-045 calendar validation/publish contract.
4. Rerun the five exact checks; require 5/5 PASS without skips or loosened
   assertions.
5. Only then use their result as input to the broader MNT-052 exit decision.

These residuals do not authorize Factory_ON, a canary, T_Live mutation, or
AutoTrading changes.

## Final integration result

`python -m pytest -q tools/strategy_farm/tests framework/scripts/tests`:

- 2,635 passed;
- 1 skipped;
- 25 subtests passed;
- exactly the five retained checks above failed;
- duration 340.82 seconds.
