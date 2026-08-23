# Evidence — rb-owner-report-path25

Date: 2026-08-23
Scope: OWNER-facing progress instrumentation for `>=25` `(EA, Symbol)` candidates through
the v4 terminal optimization gate `Q14`.

## Outcome

- Added the single shared, read-only model `path_to_25_metrics(db)` at
  `tools/strategy_farm/path_to_25.py:249`. SQLite is opened with a `mode=ro` URI and
  `PRAGMA query_only=ON` at `tools/strategy_farm/path_to_25.py:44`.
- The model reports qualified pairs, distinct EAs, strategy families, exact v4 contiguous
  frontier histogram, Q10 news outcomes/queue/holds, Q12/Q13/Q14 fork status and terminal
  verdicts, planner-tagged backfill activity, and a 10-terminal median-duration ETA. The
  classification-preserving fast frontier aggregation is at
  `tools/strategy_farm/path_to_25.py:119`.
- Mission Control v2 carries the shared model in its contract at
  `tools/strategy_farm/mission_control_v2_data.py:990` and renders the dark-theme
  `Weg zu 25` tile at `tools/strategy_farm/render_cockpit_v2.py:505`, with the required
  steel-blue `#2954d4` accent at `tools/strategy_farm/render_cockpit_v2.py:780`.
- The 15-minute heartbeat stores the shared payload at
  `tools/strategy_farm/heartbeat_snapshot.py:195` and renders the vault-mirrored German
  lines at `tools/strategy_farm/heartbeat_snapshot.py:472`.
- The existing 06:00 mail collects the shared model at
  `tools/strategy_farm/morning_brief.py:972` and renders its German section at
  `tools/strategy_farm/morning_brief.py:1240`. No send path or mail channel was added.
- Cached the pure phase/version resolution in the historical census and observed-frontier
  read paths (`tools/strategy_farm/rebaseline_census.py:294`,
  `tools/strategy_farm/operator_surfaces.py:164`). This reduced a live census measurement
  to 18.122 s and allowed the complete fresh cockpit render to finish in 27.6 s.
- Fixed a v4-column ambiguity found by the fresh render: the queue query now groups by the
  same qualified contract expression it selects
  (`tools/strategy_farm/mission_control_v2_data.py:569`).

No factory toggle, enqueue/delete action, verdict overwrite, gate threshold/criterion change,
mail send, live dashboard write, or `C:/QM/mt5/T_Live` write occurred.

## Live read-only measurement

Command (worktree cwd):

```powershell
python -c "import json; from tools.strategy_farm.path_to_25 import path_to_25_metrics; print(json.dumps(path_to_25_metrics(r'D:/QM/strategy_farm/state/farm_state.sqlite'), indent=2))"
```

Observed result: `qualified_pairs=0`, `distinct_eas=0`, `families=0`;
frontier `Q08=26`; Q10 news `conclusive_verdicts_7d=11`, `pass_7d=0`,
`pending=83`, `holds=50`; opt fork `Q12 pending=3/done=14`,
`Q13 pending=0/done=1`, `Q14 pending=0/done=0`; backfill
`enqueued_today=10`, `rerun_infra_open=6`; `eta_days=null` because no completed Q14
duration median exists. Elapsed time: 2.975 s. The null ETA is deliberate fail-closed
reporting, not a zero-duration claim.

## Tests

Fixture/read-only and renderer tests are at
`tools/strategy_farm/tests/test_path_to_25_metrics.py:88` and `:140`. The fixture asserts the
database SHA-256 is unchanged, exercises all requested fields, and writes the cockpit only to
pytest's scratch directory. Mission Control's fixture now includes the live
`gate_contract_version` shape at `tools/strategy_farm/tests/test_mission_control_v2_data.py:39`.

Final command:

```powershell
python -m pytest -q tools/strategy_farm/tests/test_rebaseline_census.py tools/strategy_farm/tests/test_backfill_planner.py tools/strategy_farm/tests/test_mnt003_heartbeat_ignorenew_benign.py tools/strategy_farm/tests/test_morning_brief_live_status.py tools/strategy_farm/tests/test_morning_safety_check.py tools/strategy_farm/tests/test_live_observability_contract.py tools/strategy_farm/tests/test_path_to_25_metrics.py tools/strategy_farm/tests/test_operator_surfaces_rebaseline.py tools/strategy_farm/tests/test_mission_control_v2_data.py tools/strategy_farm/tests/test_render_cockpit_v2.py
```

Output:

```text
........................................................................ [ 56%]
...............................................s........                 [100%]
127 passed, 1 skipped in 6.26s
```

The skip is the existing conditional live-preview validation when its prerequisite preview is
not suitable/present; all selected fixture and touched-module tests passed.

## Scratch render

Fresh production-path render, explicitly outside live dashboards:

```text
C:\Users\Administrator\AppData\Local\Temp\3\rb-owner-report-path25-live-b2fd395db2c949bc8d84f29e31ac9e30\cockpit.html
2,194,381 bytes
```

Renderer output: `factory=DEGRADED terminals_running=10 owner_open=31`; content checks found
`Weg zu 25`, `#2954d4`, and `Q14 terminal`. The command used `--output` with the scratch path,
so neither `D:/QM/strategy_farm/dashboards/cockpit.html` nor its alias was overwritten.

## Risks and open questions

- ETA is intentionally `null` until every gate needed by the nearest remaining candidate paths
  has a completed phase-duration median. In current state Q14 has no terminal row, so any numeric
  ETA would be fabricated.
- `backfill.enqueued_today` counts rows carrying the governed
  `rb-backfill-planner:*` rerun reason. Current `FILL_MISSING` commands have no durable planner
  tag, so they cannot be attributed to this planner from SQLite alone; none is inferred.
- News `REVIEW_REQUIRED` is a conclusive measured news outcome but not a PASS. `INVALID_EVIDENCE`,
  `PENDING_RUNNER`, and INFRA outcomes are excluded from `conclusive_verdicts_7d`.

## Rollback

Revert the ticket commit containing this evidence file with `git revert <commit>`. This removes
the shared read model, the three presentation integrations, their tests, and the two pure
resolution caches. The rollback does not require a DB migration or data repair because the
implementation is read-only and created no state rows. If reverting manually, restore only the
explicit files listed by `git show --stat <commit>`; do not alter the farm DB or dashboard files.
