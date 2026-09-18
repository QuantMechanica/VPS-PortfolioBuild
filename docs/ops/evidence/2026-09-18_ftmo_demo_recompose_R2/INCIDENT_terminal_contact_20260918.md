# Incident note — unintended write to the FTMO demo terminal during installer test development (2026-09-18 ~02:xxZ)

- **What:** while generalizing `tools/strategy_farm/ftmo/demo_install.py` (worktree `agents/fable-ftmo-installer-20260918`,
  commit `e0ba9fc327`), a default-argument capture (`validate_sources(package, target=TARGET)`) bound the real terminal path
  `C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850` at import time; one unit
  test's `install()` wrote 4 files into the live FTMO demo terminal's MQL5 tree.
- **Reverted:** `QM_FTMO_TrialTelemetry.ex5` and `QM_FTMO_TrialTelemetry_1514536732.set` restored from the tool's own
  backups and byte-verified against the 2026-09-06 install receipt (`411638a1…`, `f4da1592…`); the 2 stray synthetic files
  removed. Inventory reconciled: the only Sep-18 mtimes were the agent's and are resolved; remaining drift vs the receipt is the
  pre-existing Sep 6–8 rebuild history.
- **Not touched:** charts, chart profile, AutoTrading, T_Live, T1–T10, any database.
- **Root cause fixed** in the same commit (no import-time binding of the live target) plus an autouse pytest fixture that
  makes this class of escape impossible in tests.
- **Follow-up:** the demo terminal's collector binary/preset are unchanged; `ftmo_trial_pulse` continued RUNNING (8 magics)
  across the window. Recorded by Fable under production discipline (directive §1A "durable receipt").
