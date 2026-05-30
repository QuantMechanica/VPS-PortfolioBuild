# Claude Controlled Run Policy

Date: 2026-05-30
Target reset: Friday 2026-06-05 00:00 Europe/Berlin

Claude is not fully retired. It is a premium review and synthesis worker. It must not be
used as the default factory executor while weekly quota is constrained.

## Claude Owns

- Deep strategy critique and synthesis when the task explicitly needs `summary` or senior
  `review + strategy` reasoning.
- Final review of complex architecture or operating-model changes before OWNER action.
- High-signal board/CEO synthesis where a short written decision artifact is needed.
- Selected EA review only when Codex review has already passed and the expected value of a
  second-opinion review is high.

## Claude Does Not Own

- Routine EA builds.
- Routine Qxx pipeline repair.
- G0/card mass review batches.
- MT5 dispatch, queue pumping, smoke tests, or dashboard plumbing.
- Work that Codex or deterministic Python can do without material quality loss.

## Runtime Controls

- `D:\QM\strategy_farm\CLAUDE_PUMP_DISABLED.flag` blocks `farmctl.py pump` from spawning
  Claude lanes. The pump routes review/G0/research fallbacks to Codex instead.
- `D:\QM\strategy_farm\CLAUDE_DISABLED.flag` is the emergency full kill-switch. It disables
  Claude in the deterministic router and in orchestration wrappers.
- `D:\QM\strategy_farm\CLAUDE_BUDGET_POLICY.json` caps headless Claude orchestration:
  - max 2 real Claude orchestration runs per local day,
  - min 6 hours between real runs,
  - max 1 Claude session per run,
  - count budget from 2026-05-30 23:30 Europe/Berlin so stale same-day logs do
    not consume the new controlled-mode budget,
  - no runs after Friday 2026-06-05 00:00 Europe/Berlin.

With the 2026-05-30 quota snapshot showing weekly all-model usage at 41% and Sonnet at
47%, this keeps the remaining quota for explicit premium work instead of background churn.
