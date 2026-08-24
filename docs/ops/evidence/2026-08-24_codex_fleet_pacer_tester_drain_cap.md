# Codex-Host-Contention: FleetPacer coupled to tester-drain saturation

- Router task: `32c7b01f-01c4-4bda-8c14-4b356635783a` (ops_issue, claude)
- Executed: 2026-08-24, from canonical checkout `C:/QM/repo` on `agents/board-advisor`
- Source: `docs/ops/evidence/2026-08-24_throughput_forensics.md` (branch
  `rb-throughput-forensics`), §4 and §7 recommendation 4: "Move Codex/review
  burn off peak. With 22 Codex hosts observed, schedule broad build/review
  batches outside backtest drain windows or cap active Codex sessions during
  a saturated tester drain. A practical experiment is <=8 active Codex hosts
  while the long-run cap is exercised, comparing CPU-pause rate and median
  cell wall time before making the cap permanent."

## Scope

Spawn-pacing only. No running, task-claimed Codex session is killed or
paused by this change — `tools/strategy_farm/codex_fleet_pacer.py` only
controls whether it spawns a *new* `fleet_pacer`-purpose agent on its own
~15-minute cycle. No gate criterion, verdict, or registry row was touched.

## What changed

- `tools/strategy_farm/codex_fleet_pacer.py`:
  - `read_tester_drain_active_count()` — the tester-drain signal. Deterministic:
    `SELECT COUNT(*) FROM work_items WHERE status='active'` against
    `D:/QM/strategy_farm/state/farm_state.sqlite` opened `mode=ro` (same
    reproducibility convention the forensics report used). Fails open
    (returns `None`, never blocks pacing) if the DB is unreadable.
  - `tester_drain_saturated()` — `active_count >= TESTER_DRAIN_ACTIVE_THRESHOLD`
    (7). Threshold source: the forensics report's own active-count
    reconstruction found 7-9 busy rows for most of the confirmed collapse
    window (2026-08-24T02:30-12:30Z), §2 and §Method.
  - `should_hold_for_tester_drain_cap()` — true only when the drain is
    saturated **and** the fleet-wide count of live managed Codex hosts
    (`list_live_managed_codex_processes(FARM_ROOT)`, no purpose filter, i.e.
    across `fleet_pacer` + `codex_orchestration` + build/review purposes) is
    already `>= SATURATED_MAX_TOTAL_CODEX_HOSTS` (8 — the forensics report's
    named experiment number).
  - Wired into `main()`: after the existing pace-rate decision computes a
    `target` agent count, if the tester drain is saturated and the total
    Codex host ceiling is already met, `target` is clamped down to the
    current running count (`target = running`) so no new agent is spawned;
    action is tagged `<prior_action>+tester_drain_saturated_no_spawn`. This
    check is skipped when the pacer is already in `HARD_CEIL_kill` (quota
    emergency takes priority and already targets 0).
  - New state fields persisted every cycle to
    `D:/QM/reports/state/codex_fleet_pacer_state.json`:
    `tester_drain_active`, `tester_drain_threshold`, `total_codex_hosts`,
    `saturated_max_total_codex_hosts`, `tester_drain_cap_applied`,
    `tester_drain_cap_enabled` — this is the ongoing telemetry an
    OWNER/operator reads to compute the promised before/after comparison
    once the pacer has run through a saturated window.
  - Rollback: `QM_DISABLE_TESTER_DRAIN_CODEX_CAP=1` in the pacer's
    environment disables the cap and restores the pre-existing pace-only
    behaviour; same convention as `QM_DISABLE_LONGRUN_SCHEDULING_CAP`. No
    code revert or restart-time migration required — `tester_drain_cap_enabled()`
    is read fresh every cycle.
- `tools/strategy_farm/tests/test_codex_fleet_pacer_tester_drain_cap.py`
  (new): 13 tests — pure `tester_drain_saturated` / `should_hold_for_tester_drain_cap`
  decision coverage (below/at/above threshold, saturated-but-under-host-ceiling,
  fail-open on an unreadable signal, rollback flag on/off), plus one real-SQLite
  test for `read_tester_drain_active_count()` and one missing-DB fail-open test.
- `tools/strategy_farm/tests/test_factory_quiescence.py`: the existing
  `test_pacer_rechecks_interlock_before_spawn` fixture asserted its fake
  `list_live_managed_codex_processes` was always called with
  `purpose="fleet_pacer"`. The new saturation check adds a second,
  unfiltered (`purpose=None`) call to get the fleet-wide total, so the
  fixture now accepts both — the async-FACTORY_OFF-appears-mid-cycle
  behaviour under test is unchanged (both call sites observe the flag and
  the pacer still aborts the spawn with `action=factory_off_no_spawn`,
  `spawned=0`).

## Test results

```text
> python -m pytest -q tools/strategy_farm/tests/test_codex_fleet_pacer_tester_drain_cap.py
13 passed in 0.97s

> python -m pytest -q \
    tools/strategy_farm/tests/test_codex_kill_safety_audit.py \
    tools/strategy_farm/tests/test_factory_mutation_lock.py \
    tools/strategy_farm/tests/test_factory_quiescence.py \
    tools/strategy_farm/tests/test_mnt003_installer_alignment.py \
    tools/strategy_farm/tests/test_codex_fleet_pacer_tester_drain_cap.py
51 passed in 15.41s
```

`--dry-run` smoke test against the live farm DB (2026-08-24T16:48:57Z):

```json
{
  "used": 100.0, "action": "HARD_CEIL_kill",
  "tester_drain_active": 8, "tester_drain_threshold": 7,
  "total_codex_hosts": 0, "saturated_max_total_codex_hosts": 8,
  "tester_drain_cap_applied": false, "tester_drain_cap_enabled": true
}
```

`total_codex_hosts=0` here reflects that the Codex weekly quota is currently
at 100% used (`HARD_CEIL_kill`, a pre-existing, unrelated condition — see
`agent_router.py status` quota_headroom at the time of this task), so no
`fleet_pacer` agents are running to be counted; `tester_drain_active=8`
independently confirms the tester-drain signal itself reads correctly
against the live, currently-saturated fleet (matches `farmctl health`'s
`mt5_dispatch_idle: 8 active` at the same timestamp).

## Before/after (honesty note)

**Before** (already measured, from the forensics report, not re-derived
here): `cpu_high_pause` rate 64.2/hour on 2026-08-23 vs. 102.7/hour on
2026-08-24 through the 13:31Z snapshot; 22 concurrent
`codex-code-mode-host.exe` processes observed on 16 logical CPUs during the
collapse window; reconstructed active-row occupancy 7-9 for most of
02:30-12:30Z.

**After**: not yet measurable. This cap was deployed at 2026-08-24T16:4x
UTC; recommendation 4 explicitly frames it as "a practical experiment...
comparing CPU-pause rate and median cell wall time before making the cap
permanent" — that comparison requires the pacer to run through an actual
saturated window under the new logic. This report does not claim an
after-rate it has not observed (evidence-over-claims). Next step for
whoever picks this up: after >=6h of pacer operation with
`tester_drain_cap_enabled=true`, recompute the `cpu_high_pause`/hour rate
using the same bracketed-lower-bound method as
`2026-08-24_throughput_forensics.md` §4, and compare `tester_drain_cap_applied`
occurrences in `codex_fleet_pacer.log` against realized `cpu_high_pause`
counts in the same window.

## Files changed and rollback

- `tools/strategy_farm/codex_fleet_pacer.py`
- `tools/strategy_farm/tests/test_codex_fleet_pacer_tester_drain_cap.py` (new)
- `tools/strategy_farm/tests/test_factory_quiescence.py`

Rollback: set `QM_DISABLE_TESTER_DRAIN_CODEX_CAP=1` in the pacer's
scheduled-task environment (no restart-time migration), or `git revert` this
commit. No production database, registry, gate criterion, or live terminal
was touched.
