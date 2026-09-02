# Q09 REQUAL-8 pair 7 governed-smoke refusal at 05:04Z

- Recorded: `2026-09-02T05:06Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256:
  `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR7_SMOKE_REFUSED_NO_CAPACITY_GOVERNED_RESOLVER`

## Outcome

The router continuation authorized one real deferred-smoke attempt through the
governed `run_smoke.ps1` path. The reviewed pair-7 MQ5, EX5, and backtest-set
hashes still matched their sealed generation-0 bindings, and the pre-attempt
governed slot census showed resident workers on T1-T10. The exact hash-pinned
command was issued once with `-Terminal any`.

The governed resolver refused before launch:

```text
Exception: C:\QM\repo\framework\scripts\run_smoke.ps1:822
Terminal resolution returned no terminal. status=no_capacity error_code=none message=No message.
```

The command exited `1`. No terminal was selected or started for pair 7, no
active T5/T6 tester process was interrupted, and no pair-7 smoke report or
genuine smoke result was created. In accordance with the continuation, this
cycle did not retry, name a terminal, bypass the resolver, retrofit historical
capacity evidence, write a build-generation successor, enqueue Q02, release a
hold, or start pair 8.

## Exact governed command

```text
pwsh -NoProfile -File C:/QM/repo/framework/scripts/run_smoke.ps1 -EALabel QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8 -Symbol EURUSD.DWX -Year 2024 -Terminal any -Period D1 -SetFile C:/QM/repo/framework/EAs/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8/sets/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8_EURUSD.DWX_D1_backtest.set -MinTrades 1 -SmokeMode -ExpectedExpertSha256 3a3923930ddf97b7249e37e340312f09924775daea930f4fd3c57fc0441931e1
```

## Governed capacity evidence

The pre-attempt census at `2026-09-02T05:04:18+00:00` and post-refusal census
at `2026-09-02T05:04:55+00:00` agreed:

- T5 was actively running `QM5_41197 / GBPUSD.DWX / OPT_CENSUS`;
- T6 was actively running `QM5_41195 / XAGUSD.DWX / OPT_CENSUS`;
- T2, T5, and T6 carried governed custom-history reservations;
- resident workers existed on T1-T10;
- there were no duplicate terminal workers or orphaned terminal processes;
- no reservation attributable to this refused pair-7 attempt was created.

The current containment receipt was recorded at
`2026-09-02T04:50:02.768912+00:00` with `enabled=false`, mode SHA-256
`983543a1438be926768b41c379c53746c82f8e7a08311bf2f3062c80b0996733`,
and reason `v2_ramp_mismatch_false_trip_20260901`. Therefore the earlier review
expectation that containment-serial mode would make an idle terminal
dispatchable was not the active receipt at this attempt. The controller still
returned the fail-closed `no_capacity` result. This checkpoint records that
result without inferring dispatch authority from process idleness.

## Sealed artifact verification

| Artifact | SHA-256 |
|---|---|
| MQ5 | `ede8570a029563fadecdfb99b829331903dffa0d2e46a3bb64c6e3cf8af8e91f` |
| EX5 | `3a3923930ddf97b7249e37e340312f09924775daea930f4fd3c57fc0441931e1` |
| EURUSD.DWX D1 backtest set | `ee72ead97a1a8cf2bb1998ad064c52a4a9128c052e365117062b4771666e3bf6` |

The set remains `RISK_FIXED=1000` and `RISK_PERCENT=0`. The EA remains bounded
to `qm_news_stale_max_hours=336`.

Focused verification after the refusal:

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`;
- `validate_build_guardrails.py`: MQ5 and setfile `PASS`, zero findings, maximum
  news staleness `336` hours;
- approved manifest JSON: exact SHA-256 shown above;
- scoped EA-directory `git diff --check`: `PASS`.

## Serial-state verification

Read-only canonical database checks after the refusal found:

- pair-7 `QM5_41221 / Q02` work-item count: zero;
- pair-7 hold `30584122-b7b3-41eb-8e1a-b03517554d4d`:
  `Q09_AWAITING_SEALED_PLAN`, `active=1`, `released_at=NULL`,
  `release_note=NULL`;
- generation-0 build task `0f36f1bb-924b-4126-b682-c30ba1edfa41`:
  unchanged `done`;
- mechanical review `7b301e4c-2cd0-42c7-9bb7-d6fe4200d471`:
  unchanged `done`;
- EA review `58882906-5836-4ea5-9395-ea973cbe3c31`:
  unchanged `done` with `APPROVE_FOR_BACKTEST`;
- pair-8 `QM5_41222`: zero farm tasks and zero work items;
- pair-8 hold `08fe4173-07d9-47e1-97e9-a76b1159ad94`:
  `Q09_AWAITING_SEALED_PLAN`, `active=1`, `released_at=NULL`,
  `release_note=NULL`.

The protected `QM5_41162 / OPT_CENSUS` program remains exactly 1,161 terminal
rows: 237 `done/MEASURED` and 924 `done/SKIPPED_EXCLUDED`. No protected row was
mutated or interrupted.

No historical work item, hold, review, build result, EA source, EX5, setfile,
registry, terminal policy, AutoTrading setting, `T_Live` setting, main branch,
or `C:/QM/worktrees/cto_main` state was changed. No pipeline phase ran and no
pipeline verdict is asserted.

## Required continuation

The capacity refusal must be reviewed as recorded. A later authorized
continuation may retry only through the same governed `-Terminal any` path.
Only a genuine smoke result may support an append-only build-generation
successor bound to these same artifact hashes. Fresh generation-matched
reviews remain required before the manifest's single Q02 enqueue, and pair 7's
hold may be released only after exactly one Q02 row is verified. Pair 8 remains
strictly downstream.

## Verdict

`PAIR7_SMOKE_REFUSED_NO_CAPACITY_GOVERNED_RESOLVER`: one authorized governed
attempt failed closed before launch; zero smoke evidence, zero Q02 seeds, zero
hold releases, zero historical mutation, and zero protected-program
interruption.
