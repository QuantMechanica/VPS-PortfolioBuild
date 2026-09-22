# Hourly Factory inspection in the existing Codex CLI thread

OWNER requested an hourly inspection and update on 2026-09-22, then explicitly
selected: "Automatische Nachrichten in diesem CLI-Chat". This installs a local
Windows task using the installed Codex CLI 0.155.1 `queue` command. It does not
enable email or launch a separate Codex execution session.

## Installed configuration

- Task: `QM_Codex_FactoryChat_Hourly`, enabled, repetition `PT1H`.
- First regular run: **2026-09-22 13:00 Europe/Berlin**, then each whole hour.
- Target thread: `01a0c58a-454a-76d3-998d-a26f15f34610` (explicit UUID, never `--last`).
- Principal: existing OWNER Windows user, Interactive, Limited; Pythonw and the
  CLI child create no new console. No credentials or additional subscription.
- Config: `D:/QM/reports/state/codex_factory_chat/config.json`.
- Dispatch receipts: `last_run.json`, `dispatch_state.json`, `dispatch.jsonl` in
  the same directory. Inspection evidence requested from the existing agent:
  `latest_check.md`. A queue receipt is not a completed inspection.
- Prompt: `docs/ops/CODEX_FACTORY_CHAT_HOURLY_PROMPT.md`.

The prompt checks actual executors, reviews, quotas, terminal tests, claimable
work, RAM/disk, the source intake and BR/NNFX candidates, and FTMO trial blockers.
It preserves existing OWNER pauses, independent review and financial evidence
requirements. It commissions only already-authorized reversible orchestration.
It neither renews the one-day token-burn override nor authorizes live changes.

This is a thread-specific OWNER reminder, separate from the Factory ON/OFF
manifest and deterministic `QM_StrategyFarm_HourlyMonitor_60min`. It remains
available to report an intentionally stopped Factory. The recipient must respect
Factory_OFF/AI_OFF flags; the reminder does not resume paused workers.

## Availability and duplicate protection

The machine must be running and the OWNER Windows session logged in. To process
the reminder and display an answer, this Codex thread must be open/resumed and
able to run (normal provider limits still apply). An active turn finishes before
queued work is processed. A closed thread is not itself launched by this task.

At most one hourly reminder remains pending in the CLI queue. While it is
pending, later ticks are suppressed; after resumption it asks for a fresh check,
not replay of every missed hour. A UTC hourly reservation prevents repeat sends
and DST ambiguity. An OS lock plus Scheduler IgnoreNew prevents concurrent runs.
A timeout or ambiguous delivery is not retried within the same hour. CLI queue
data is only read; all queue writes go through the supported `codex queue` CLI.
Unknown queue schema or a missing database fails closed with a logged error.

To pause: `Disable-ScheduledTask -TaskName QM_Codex_FactoryChat_Hourly`.
To resume: `Enable-ScheduledTask -TaskName QM_Codex_FactoryChat_Hourly`.
Reinstall/retarget using `tools/strategy_farm/install_codex_factory_chat_hourly.ps1
-ThreadId <UUID>`. It is intentionally outside the always-on repair manifest,
so an explicit disable is not silently undone by Factory health repair.

## Validation on 2026-09-22

- CLI help confirms `codex queue --thread <THREAD> --message <TEXT>`.
- Eight isolated unit tests passed (same-hour dedupe, offline backlog, thread
  isolation, timeout ambiguity, CLI failure, unknown schema, DST and process lock).
- PowerShell installer parsed successfully.
- Actual Scheduler run at 12:20 local: `LastTaskResult=0`, task returned Ready.
- CLI receipt at 10:20:49 UTC: queued message
  `01a0c8a1-ee47-73c3-8fce-c373bee533c3` for the exact target thread.
- Read-only queue verification confirmed that message. The active setup turn
  had not yet completed, so processing/display was still pending at verification.
- Earlier one-time CLI delivery probe:
  `01a0c89e-1c58-7890-b6e6-dfe19ee76d05`.

The eight tests run with:

```powershell
C:\Python311\python.exe -X utf8 -m unittest discover -s tools/strategy_farm/tests -p test_codex_factory_chat_hourly.py -v
```
