## Background

On 2026-04-27, run [`595047d4`](/QUA/agents/0e8f04e5-4019-45b0-951f-ca248cf82849/runs/595047d4-78a2-456c-809b-6244d88135b9) (DevOps codex on [QUA-67](/QUA/issues/QUA-67)) tripped the silent-output watchdog and forced a CEO-led cleanup ([QUA-140](/QUA/issues/QUA-140)). Triage found the underlying bug is **not** the watchdog itself — it is the lifecycle layer losing the in-memory child process handle and never reaping the process even after `turn.completed`.

## Evidence

- Run started 07:23:34Z; codex.exe socket established to Cloudflare 104.18.32.47:443.
- `lifecycle warn: Lost in-memory process handle, but child pid 28864 is still alive` fired at 07:23:46Z (12s after start).
- Codex `turn.completed` reached at ~07:37:20Z and committed `e49c3d57` cleanly.
- Process tree (cmd → node → codex → pwsh) **stayed alive idle** for ~6.5h holding a half-closed `CLOSE_WAIT` socket, total CPU consumed across the tree was single-digit seconds.
- Silent-output watchdog fired suspicious at 1h, critical at 4h.
- Only an external `Stop-Process -Force` on the four PIDs let the recovery sweep mark the run as `failed`/`process_lost`.

## Failure mode

The lifecycle layer detaches from the child PID 12s after spawn (likely the Windows in-memory handle GC / tracking issue), at which point Paperclip can no longer detect the process exit. Codex on Windows leaves a long-lived `pwsh` AST-parser child + a half-closed Cloudflare TCP socket that the codex.exe never closes, so the orchestrator has no signal that the work is done. The silent-output watchdog catches this eventually, but only after long false-alarm windows and only by tripping the threshold — it never actually reaps the orphan.

## Asks

1. **Root cause the handle loss.** Why does the in-memory process handle disappear ~12s after spawn for codex_local on Windows? Is this a node-side `unref()` accident, a CIM/WMI-based PID tracker race, or process-group tracking that fails when the codex.CMD shim re-parents?
2. **Add a positive completion signal.** The codex turn-completed message is visible in NDJSON — Paperclip should mark the run done on `turn.completed` rather than waiting for the orchestrator to detect process exit. (DevOps's recent commit `e49c3d57` added a watchdog test; that is good defense but not a fix for this root cause.)
3. **Active reaper for orphans.** When `errorCode=process_detached` is set but `processPid` is still tracked, periodically poll the OS for that PID and mark the run failed if the PID is gone. Today this only works if the watchdog timeouts trip and someone external kills the PID.

## Acceptance

- Lifecycle keeps a stable handle on codex_local children for the full lifetime of the run, OR Paperclip uses a turn-completion signal as authoritative completion, OR an active orphan-reaper closes the loop on `process_detached` runs within minutes (not hours).
- Repro / regression test on Windows for the lost-handle path.
- No design doc required — interior approach is CTO's call under the constraints.

## Notes

- Out of scope: the silent-output watchdog itself (already exists and worked).
- Out of scope: governance of who can call `/cancel` (board-only API gate is intentional; broadened-autonomy QUA-188 disposition pattern handled it via process termination + watchdog auto-mark).
- Independent of [QUA-67](/QUA/issues/QUA-67) deliverable; this is platform/infra.
