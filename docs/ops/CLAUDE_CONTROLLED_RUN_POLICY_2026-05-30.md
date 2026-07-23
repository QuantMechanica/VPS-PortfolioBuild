# Claude Controlled Run Policy

Date: 2026-05-30
Target reset: Friday 2026-06-05 00:00 Europe/Berlin

Claude is not fully retired. It is a premium review and synthesis worker. It must not be
used as the default factory executor while weekly quota is constrained.

## Claude Owns

- Deep strategy critique and synthesis when the task explicitly needs `summary` or senior
  `review + strategy` reasoning.
- Final review of complex architecture or operating-model changes before OWNER action.
- High-signal OWNER decision support where a short written analysis artifact is needed.
- Selected EA review only when Codex review has already passed and the expected value of a
  second-opinion review is high.

## Claude Does Not Own

- Routine EA builds.
- Routine Qxx pipeline repair.
- G0/card mass review batches.
- MT5 dispatch, queue pumping, smoke tests, or dashboard plumbing.
- Work that Codex or deterministic Python can do without material quality loss.

## Runtime Controls

- `farmctl.py pump` may spawn Claude automatically for the Claude-owned lanes above.
  Pump Claude concurrency is capped at 3 simultaneous Claude sessions.
  G0/card mass review remains routed to Codex.
- `D:\QM\strategy_farm\CLAUDE_DISABLED.flag` is the emergency full kill-switch. It disables
  Claude in the deterministic router and in orchestration wrappers.
- `D:\QM\strategy_farm\CLAUDE_BUDGET_POLICY.json` caps headless Claude orchestration:
  - no daily run-count cap,
  - no fixed minimum interval between real runs,
  - max 3 Claude sessions per orchestration run,
  - count budget from 2026-05-30 23:30 Europe/Berlin so stale same-day logs do
    not consume the new controlled-mode budget,
  - no runs after Friday 2026-06-05 00:00 Europe/Berlin.
- `QM_StrategyFarm_ClaudeVerify_4h` is disabled during controlled mode because it
  invokes Claude directly and does not use the orchestration budget policy.

With the 2026-05-30 quota snapshot showing weekly all-model usage at 41% and Sonnet at
47%, this keeps Claude available for the right work while avoiding accidental stale
process churn.
