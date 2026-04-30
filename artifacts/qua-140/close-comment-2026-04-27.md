## Closed — orphan cleanup complete

The interaction card [`2e2dfb00`](/QUA/issues/QUA-140) was clerk-accepted by `local-board` at 14:10:09Z, which woke me. Cleanup is now complete, with one correction to the prior CEO comment.

### Correction

Prior CEO comment claimed PID 28864 was already dead. **That was wrong.** The full process tree was still alive when I rechecked:

```
pid=28864 cmd       (codex.CMD wrapper)
pid=27644 node      (codex.js exec)
pid=27588 codex     (stuck CLOSE_WAIT to 104.18.32.47:443)
pid=21328 pwsh      (long-lived AST parser child)
```

### Action taken

- **Local process termination** (within CEO authority, authorized by interaction `2e2dfb00`): killed all four PIDs via `Stop-Process -Force`. Post-kill verification: all four gone.
- **DB record cancel**: `POST /api/heartbeat-runs/595047d4/cancel` still returned `403 Board access required` for the CEO agent JWT — the clerk-accept on the interaction does not grant API permissions to the source agent. **However**, the recovery sweep auto-detected the dead pid within ~90s and marked the run `failed` (errorCode `process_lost`, finishedAt `2026-04-27T14:12:21.542Z`). No further board-side action needed.

### Final state

- Run `595047d4`: `failed` / `process_lost` ✅
- PID tree (28864/27644/27588/21328): terminated ✅
- Interaction `2e2dfb00`: `accepted` (clerk-flipped) ✅
- Silent-output watchdog: will no longer fire (run is no longer `running`)

### Follow-ups

- The underlying lifecycle bug (in-memory process handle lost 12s after start, then never reaped on `turn.completed`) is a recurring failure mode. Opening a CTO subtask for root-cause investigation — this is independent of cleanup and out of QUA-140's scope.
- Note for future similar wakes: the source agent (CEO here) cannot complete the DB-cancel half of the disposition; in practice we rely on either OWNER cancelling via UI or — as just demonstrated — the recovery watchdog auto-marking the run as `failed` once the local pids are dead. This works but is implicit; worth documenting in the QUA-188 broadened-autonomy waiver pattern.

Closing as `done`.
