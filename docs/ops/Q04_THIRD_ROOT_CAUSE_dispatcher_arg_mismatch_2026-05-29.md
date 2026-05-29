# Q04 INFRA_FAIL — third root cause: dispatcher↔Q-runner CLI arg mismatch

**Found:** 2026-05-29T06:00Z (claude-orchestration-2 cycle)
**Status:** Diagnosed with reproducible pipeline evidence. **Fix is Codex's** (dispatcher
code in `farmctl.py`); not implemented here — Claude does not self-author/approve runner
or dispatcher code, and no router task is assigned for it.

## TL;DR

Q04 is still **100% INFRA_FAIL, 0 PASS ever** — but the cause is now different from the
two recorded in `project_qm_q04_infra_fail_scaled_2026-05-28`. The sys.path fix
(`9c1427eb`, `parents[1]`→`parents[2]`) **IS live and working** — it peeled back the
`ModuleNotFoundError` import crash and exposed the next layer: the dispatcher spawns the
new Qxx runners with the **old P-runner CLI** (`--out-prefix`, `--period`), which the
rewritten Q-runners reject at argparse. No `summary.json` is written →
`summary_missing_retries_exhausted` → INFRA_FAIL on every retry.

## Evidence (pipeline logs, this cycle)

Three distinct EAs, all symbols/periods, all within minutes of 06:00Z, identical error:

```
# work_item_434f544c… (QM5_10569 EURJPY.DWX H4), 06:04:49Z
spawning: …\python.exe …\q04_walkforward.py --ea QM5_10569 --out-prefix …\434f544c… \
  --symbol EURJPY.DWX --period H4 --setfile …grid_001.set --terminal T4
q04_walkforward.py: error: unrecognized arguments: --out-prefix …\434f544c… --period H4

# work_item_6cf927d5… (QM5_10513 USDJPY.DWX D1), 06:04:47Z — same error, --period D1
# work_item_a134a7a5… (QM5_10559 EURUSD.DWX H6), 06:03:57Z — same error, --period H6
```

`run_smoke_exit_code: 0`, `final_failure: summary_missing_retries_exhausted`,
`prior_failure: summary_missing`, `evidence_path: None`.

That the live failure is an **argparse** error and not `ModuleNotFoundError: framework`
proves the import bootstrap now succeeds — i.e. `9c1427eb` is the code the daemons run.
Daemons spawn from the `C:/QM/repo` working tree (checked out on `agents/board-advisor`
@ `9c1427eb`), read fresh per work-item, so the on-disk fix is effective regardless of
`origin/main` still lacking the commit.

> Reconciliation note: the 0600Z correction in the memory file assumed daemons run
> `origin/main` (which lacks `9c1427eb`) and therefore still crash on import. The live
> argparse-not-ImportError signature shows that assumption is wrong — the working-tree
> checkout, not `origin/main`, is what executes.

## Root cause (code)

`tools/strategy_farm/farmctl.py :: _phase_runner_cmd_for_work_item` (≈ line 2314).

The generic base command (lines 2327–2335) always injects:

```python
cmd = [python, script, "--ea", ea_id,
       "--out-prefix", str(report_root),   # line 2331
       "--symbol", symbol,
       "--period", period,                 # line 2333
       "--setfile", item_row["setfile_path"]]
```

The per-phase bridge branches below were meant to reconcile each new Q-runner's CLI
(comment at 2408–2410: *"Each new runner has a slightly different CLI; bridge from the
generic worker args here"*). But the Q04 branch is incomplete:

```python
elif phase == "Q04":
    cmd.extend(["--terminal", terminal or "T1"])   # adds --terminal only
```

It never **renames** `--out-prefix` → `--report-root` nor **removes** `--period`.
`q04_walkforward.py`'s argparse accepts only:
`--ea --symbol --setfile --terminal --report-root --latest-full-year --timeout-sec`
— no `--out-prefix`, no `--period`. argparse aborts (exit 2), nothing runs.

## Scope — latent in Q05/Q06/Q07/Q09/Q10 too

Audited every Q-runner CLI: **none** of q04/q05/q06/q07/q09 accept `--out-prefix` or
`--period`; all use `--report-root`.

| Qxx branch | strips `--out-prefix`? | strips `--period`? | verdict |
|------------|------------------------|--------------------|---------|
| Q04 (2411) | no | no | **fails now** (front line) |
| Q05/Q06/Q10 (2413) | no | no | latent — same failure when reached |
| Q07 (2420) | no | no | latent |
| Q09 (2440) | no | no | latent |
| Q08 (2426) | n/a — rebuilds `cmd` from scratch | n/a | OK |

Only Q08 escapes because it fully reconstructs `cmd`. The front line is pinned at Q04,
so only Q04 surfaces today; advancing it merely moves the wall one gate forward unless
all branches are fixed together.

## Recommended fix (for Codex)

Two clean options; **Option A** is lowest-risk and localized:

**A. Translate in the base command / Q-branches.** Rename `--out-prefix`→`--report-root`
and drop `--period` for the Qxx phases. Cleanest is to stop injecting the P-era args for
Q-phases at the top of the function, or add to each Qxx branch:
```python
_remove_cmd_arg(cmd, "--period")
# replace --out-prefix with --report-root
idx = cmd.index("--out-prefix"); cmd[idx] = "--report-root"
```
(`_remove_cmd_arg` already exists at line ~2299 and is used by the P5/P6/P7 branches.)
Note `--report-root` defaults to `D:/QM/reports/pipeline`, so the value must be carried
over — do not merely delete `--out-prefix`, or per-work-item output lands in the shared
default tree.

**B. Widen the runners.** Add `--out-prefix` as an alias of `--report-root` and accept
(ignore) `--period` in q04–q10. Touches more files; only do if the generic worker
contract is meant to be authoritative.

Whichever path: add a regression test mirroring `tests/test_cascade_chain_p2_to_p8.py`
that asserts each Qxx spawn argv is a subset of the target runner's accepted args.

## Verification after fix

```sql
-- expect non-zero done within ~1h of the fix going live
SELECT status,COUNT(*) FROM work_items WHERE phase='Q04'
  AND updated_at > datetime('now','-1 hour') GROUP BY status;
```
And confirm the first-ever Q04 `done`/PASS rows appear (currently 0 lifetime).

## Cross-refs
- `project_qm_q04_infra_fail_scaled_2026-05-28` (causes 1 & 2)
- `project_qm_pipeline_rewrite_2026-05-23` (Qxx runners are the rewrite)
- `feedback_qxx_only_in_user_surfaces`
