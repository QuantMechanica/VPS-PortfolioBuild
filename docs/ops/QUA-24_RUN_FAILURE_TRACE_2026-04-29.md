# QUA-24 Run Failure Trace (2026-04-29)

Scope: trace stale-lock recurrence evidence for Pipeline-Operator dead runs and isolate likely release-path failure modes.

Source of truth: `C:\QM\paperclip\app\run.log`.

## Target runs

- `d24967d2-3e80-41c6-bdc9-5ed31826ec10`
- `1f66ce45-30ad-47db-ba28-ed51bc31b824`

## Evidence extracted

### 1) Dead-run lock behavior is reproducible (release call returns 409)

- `2026-04-26 20:50:11` local log line `21839`:
  - `POST /api/issues/d293614b-8a90-4381-8cc7-a9faa5671382/release 409`
- `2026-04-26 20:57:21` local log line `22414`:
  - `POST /api/issues/QUA-14/release 409`

Interpretation: the lock holder run could not be released by subsequent actor context, matching the observed assignee/run-id ownership gate.

### 2) `d24967d2` remained log-active while issue mutations failed with ownership conflicts

- Log retrieval for run `d24967d2` repeatedly succeeds (`GET /heartbeat-runs/.../log 200`) across many offsets:
  - first success line `21747` (`offset=0`)
  - continued retrieval lines `21756`, `21779`, `21807`, `21945`, `22146`, `22230`.
- During same period, issue mutations on related issue paths returned `409`:
  - `POST /api/issues/.../checkout 409` line `21831`
  - `PATCH /api/issues/79bcbfae-b654-... 409` line `22233`
  - `POST /api/issues/79bcbfae-b654-.../release 409` line `22259`

Interpretation: the run ledger/log stream remained queryable while lock ownership blocked state transition calls.

### 3) `1f66ce45` shows similar long-lived log polling + failed mutation

- Run log retrieval for `1f66ce45` succeeded repeatedly (`GET /heartbeat-runs/.../log 200`):
  - lines `22634`, `22642`, `22763`, `23142`, `23366`, `23413`.
- Mutation failure in same window:
  - `PATCH /api/issues/79bcbfae-b654-... 500` line `23314`

Interpretation: recovery/update path can fail mid-heartbeat while lock-bearing run context continues to be referenced.

### 4) High-signal backend write failure present during lock incidents

- `2026-04-26 21:08:32` line `23314`:
  - `PostgresError: invalid byte sequence for encoding "UTF8": 0x00`
- Similar UTF8 `0x00` failures are present elsewhere in lock-conflict periods (e.g., lines around `36353`, `36458`).

Interpretation: un-sanitized control bytes in issue comment/description payloads can abort persistence on mutation endpoints; this is a plausible co-factor for runs exiting without clean release sequencing.

## Working hypothesis (operational)

Stale locks are not a single failure mode. At least two classes are visible:

1. Ownership-gated release failures (`/release 409`) after run handoff mismatch.
2. Mutation-path hard failures (`500` with UTF8 `0x00`) that can interrupt normal heartbeat cleanup/release flow.

## Immediate mitigation status

- Watchdog task hardening is already committed (`9db6c600`) to reduce misconfigured monitoring blind spots.
- This trace adds incident evidence for upstream fix lane (QUA-115 / platform lock-reattach root cause).

## Next actions

1. Add payload-sanitization guard in Paperclip issue/comment write path to strip `\u0000` before DB write.
2. Add server-side stale-lock auto-expire guard keyed on `executionLockedAt` + missing/terminal `activeRun`.
3. Keep scheduler watchdog monitor-only; retain PATCH-only assignee-cycle recovery runbook as break-glass.
