# Cockpit progress KPI repair — task f775b87f

Date: 2026-08-28

## Verdict

PASS_FOR_REVIEW. The Mission Control progress row now counts all governed
terminal `work_items_clean` rows directly from the canonical farm database.
It no longer treats a stale execution-phase allowlist as the definition of
completed work. A progress-query failure emits an explicit `STALE` contract
with unavailable values and the renderer shows dashes, never synthetic zeroes.

## Root cause

The renderer did not consume `pipeline_state.json`; it already called
`mission_control_v2_data.build_progress()` against
`D:/QM/strategy_farm/state/farm_state.sqlite` in read-only mode.

The defect was inside that DB query. Progress used `MT5_TESTER_PHASES`, a
narrow allowlist retained for queue-drain ETA arithmetic. The allowlist omitted
productive measurement/utility stages and newer Q-gates. At the OWNER-reported
render time all current-day terminal rows happened to be outside the allowlist,
so a fresh page truthfully rendered the wrong filtered result as zero.

## Repair

- Progress counting is exclusion-based across governed terminal clean rows;
  only the synthetic permission fixture is excluded.
- Queue-drain arithmetic keeps its narrower phase scope unchanged.
- Calendar-window selection uses the emitter's injected UTC clock, avoiding a
  separate SQLite wall-clock boundary in fixtures and replays.
- Operator-facing phase labels remain Q-only.
- Progress query errors are caught as `STALE`; KPI values are `null` and render
  as dashes. The existing atomic temp-file plus `os.replace` publication path
  is unchanged.

## Verification

Focused tests:

```text
python -m pytest tools/strategy_farm/tests/test_mission_control_v2_data.py tools/strategy_farm/tests/test_render_cockpit_v2.py tools/strategy_farm/tests/test_opt_census_dispatch.py -q
45 passed in 3.00s
```

The fixture independently queries `work_items_clean` and asserts that the
today completion tile equals the database count. It also covers productive
measurement and current Q-gate rows, confirms measurement outcomes do not
inflate Gate PASS, validates the stale/null contract, and proves the renderer
does not display a source error as zero.

Live read-only probe before publication:

```text
today.completed=40
today.distinct_ea_symbol=29
today.gate_pass=20
today.economic_fail=1
today.infra_transient=1
```

The normal renderer then completed successfully and atomically published both
aliases. Post-publish inspection showed:

```text
erledigte Work Items: today=40, yesterday=212, 7-day average=212.9, total=109244
Gate PASS: today=20, yesterday=67, 7-day average=40.4, total=26879
cockpit.html sha256=DAD07E88E3F3D4A19887F0298FE5FEE77F2EEA897A0A67A3A256549EF5595D9E
cockpit_v2.html sha256=DAD07E88E3F3D4A19887F0298FE5FEE77F2EEA897A0A67A3A256549EF5595D9E
```

No terminal process, Factory intent, T_Live, AutoTrading, work-item state, or
pipeline verdict was changed.
