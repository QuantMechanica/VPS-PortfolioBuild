# Q10 news runner spawn silent-abort diagnosis — 2026-08-29

## Scope

- Router task: `a1221b9d-67f0-4e93-a3af-58a59d5237a2`
- Work item: `01c42ad6-168e-4808-bec5-b9b34f365a2f`
- EA / lane: `QM5_10513`, `XAUUSD.DWX`, `Q10_NEWS`, T6
- Expansion source: `66af966d-f123-4f8c-be21-27354394cee9`

## Finding

No authenticated runner precondition failed. The work-item payload proves the
sealed plan, expansion binding, news calendar/custom-history admission, and EX5
staging all passed. The work-item log records the real `q09_news_runner.py`
spawn at `2026-08-29T09:07:00Z` with plan file SHA-256
`845c1fb519f0e458bf775b9df3e4382cc8e897aa69713c7c8404fe73a5562df8`.

The runner was launched as PID `9696`, creation key
`windows-filetime:134324680209208429`, under a `KILL_ON_JOB_CLOSE` job owned by
the terminal worker. A canonical worker-code replacement landed at
`2026-08-29T09:18:45Z`; the worker disappeared and its job-contained runner did
not produce a durable completion. Subsequent workers treated PID-only liveness
as ownership and repeatedly adopted the active row instead of spawning. During
the guarded live reconciliation at `2026-08-29T13:21:53Z`, PID `9696` was in
fact `C:\Program Files\Git\usr\bin\sleep.exe` with creation key
`windows-filetime:134324832342704116`. This is conclusive Windows PID reuse,
not plan revalidation, expansion binding, or EX5 staging failure.

## Fix

`terminal_worker.py` now:

1. binds runner liveness/adoption to the stored immutable process creation key;
2. rejects a live process occupying the historical PID when its key differs;
3. applies the same identity check while monitoring, avoiding monitoring or
   stopping an unrelated reused PID;
4. parks a bound Q10 news row under `NEWS_RUNNER_SPAWN_SILENT_ABORT` when its
   worker/runner disappears without summary evidence;
5. writes a structured `news_runner_spawn_abort_held` event and payload
   diagnostic containing expected and observed process identities.

Legacy rows without a creation key retain the prior tree-liveness behavior.
Gate criteria and the sealed news plan are unchanged.

## Live repair evidence

- Pre-mutation SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_governed_hold_20260829T131752Z.sqlite`
- Backup SHA-256:
  `b5c114260ba7b8f4f4de91c34f145e417b79700dabcb975c469d83bcabbe8f25`
- T6 had no terminal worker, news runner, or `terminal64.exe` process before the
  exact-row reconciliation. No active backtest was interrupted.
- The row was changed from stale `active/T6` to `pending/unclaimed` and parked
  with `release_on_restart=0` plus the structured PID-reuse event.

## Verification

- `python -m py_compile tools/strategy_farm/terminal_worker.py` — PASS
- Focused claim, stale-recovery, and log-bomb tests — 3 PASS
- Worker adoption and staged-EX5 suites — 16 PASS
- Combined worker suites — 92 PASS with one unrelated parallel-claim timing
  assertion under host load; that isolated assertion passed on rerun.
- `git diff --check` on the implementation and regression test — PASS

This is operational harness evidence only. It does not issue a pipeline verdict
or change any Q-gate acceptance criterion.
