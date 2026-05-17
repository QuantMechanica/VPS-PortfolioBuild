# Strategy Farm — Canonical JSON Schemas

Single source of truth for the JSON contracts between pipeline stages.
**If you change any schema below, update this file FIRST.** Both
`codex_build_ea.md` (producer) and `codex_review_ea.md` (consumer)
reference this document so they cannot drift.

Past lesson: the codex_review §E check assumed a `status` field at top
level of `build_result.json` that the producer never wrote — silently
FAILed every review for 24h. Schema-by-prose without a shared truth file
is how that happens.

---

## build_result.json — written by `codex_build_ea` per `{{build_result_path}}`

Producer: Codex Build agent.  Consumer: pump record_build_result + codex_review §E.

Top-level fields (all required unless marked optional):

| Field                 | Type              | Description                                              |
|-----------------------|-------------------|----------------------------------------------------------|
| `task_id`             | string (UUID)     | The build_ea task id this result belongs to.            |
| `ea_id`               | string            | `QM5_NNNN` identifier.                                   |
| `ea_dir`              | string (path)     | Repo-relative dir of the new EA (`framework/EAs/...`).   |
| `mq5_path`            | string (abs path) | Absolute path to written `.mq5`. Must exist.             |
| `ex5_path`            | string (abs path) | Absolute path to compiled `.ex5`. Must exist.            |
| `magic_base`          | int               | `ea_id * 10000` — base for per-symbol magic slots.        |
| `symbols_registered`  | list[string]      | DWX symbols this EA registered (e.g. `["NDX.DWX"]`).     |
| `setfiles_generated`  | list[string]      | Paths to setfiles in `sets/` dir (may be empty if smoke deferred). |
| `build_check_passed`  | bool              | Did `framework/scripts/build_check.ps1` pass?            |
| `compile_succeeded`   | bool              | Did MetaEditor compile produce a `.ex5`?                 |
| `smoke_result`        | string            | One of: `"ok"`, `"PASS"`, `"framework_error"`, `"METATESTER_HUNG"`, `"INCOMPLETE_RUNS"`, `"MIN_TRADES_NOT_MET"`. |
| `smoke_report_path`   | string (abs path) | Where the smoke summary.json lives.                      |
| `blocked_reason`      | string (optional) | Present + non-empty = build is blocked; reason text.     |
| `open_questions`      | list[string] (optional) | Unresolved decisions Codex deferred to reviewer.   |

Pass criteria for §E mechanical review:
- `build_check_passed == true`
- `compile_succeeded == true`
- `blocked_reason` absent OR empty string
- Both `mq5_path` and `ex5_path` reference files that exist on disk

There is **no top-level `status` field** in this schema. Codex review §E
must NOT check for one.

---

## smoke summary.json — written by smoke test runner per `{{smoke_report_path}}`

Producer: `framework/scripts/p2_baseline.py` / smoke variant.  Consumer:
codex_review §D, claude_review, pump record_build_result.

| Field            | Type     | Description                                           |
|------------------|----------|-------------------------------------------------------|
| `ea_id`          | string   | `QM5_NNNN`.                                           |
| `symbol`         | string   | DWX symbol tested.                                    |
| `from_date`      | string   | ISO date (e.g. `"2024-01-01"`).                       |
| `to_date`        | string   | ISO date.                                             |
| `total_trades`   | int      | Trade count over the smoke window.                    |
| `net_profit`     | float    | Closed-PnL net of fees + swaps.                       |
| `max_dd`         | float    | Max equity drawdown over the run.                     |
| `final_balance`  | float    | End-state balance.                                    |
| `bars_processed` | int      | Bar count the EA saw (sanity check).                  |
| `result`         | string   | `"ok"`, `"FAIL"`, `"MIN_TRADES_NOT_MET"`, etc.        |

Sanity bar for §D:
- `total_trades >= 1` (zero = entry logic broken on this symbol)
- `bars_processed > 0` (smoke actually ran)
- `final_balance > 0` (no broker-side NaN)

---

## codex_review verdict JSON — written by `codex_review_ea` per `{{verdict_path}}`

Producer: Codex Review agent. Consumer: pump _record_codex_review_result.

| Field             | Type           | Description                                       |
|-------------------|----------------|---------------------------------------------------|
| `review_task_id`  | string (UUID)  | The codex_review task id.                         |
| `build_task_id`   | string (UUID)  | The build_ea task being reviewed.                 |
| `ea_id`           | string         | `QM5_NNNN`.                                       |
| `reviewer`        | literal        | Always `"codex"`.                                 |
| `verdict`         | literal        | `"PASS"` or `"FAIL"`.                             |
| `sections`        | object         | `{framework_corset, intraday_discipline, magic_registry, smoke_sanity, build_result, forbidden_grep}` each `"PASS"` / `"FAIL"` / `"UNKNOWN"`. |
| `findings`        | list[string]   | One concrete string per section that FAILed.      |
| `reviewed_at`     | string (ISO)   | UTC timestamp.                                    |

Rules:
- ANY section `FAIL` → overall `verdict: "FAIL"`.
- `UNKNOWN` allowed for non-applicable sections (e.g. intraday_discipline
  for daily-bar strategies).
- ALL sections PASS / UNKNOWN → overall `verdict: "PASS"`.

---

## claude_review (ea_review) verdict JSON — written by `claude_review_ea` per `{{verdict_path}}`

Producer: Claude Review agent. Consumer: pump record_review_result.

| Field              | Type         | Description                                                    |
|--------------------|--------------|----------------------------------------------------------------|
| `review_task_id`   | string       | The ea_review task id.                                         |
| `build_task_id`    | string       | The build_ea task being reviewed.                              |
| `ea_id`            | string       | `QM5_NNNN`.                                                    |
| `verdict`          | literal      | `"APPROVE_FOR_BACKTEST"` / `"REJECT_REWORK"` / `"REJECT_DEAD"`. |
| `r_status`         | object       | `{r1, r2, r3, r4}` each `"PASS"`/`"FAIL"`/`"UNKNOWN"`.          |
| `concerns`         | list[string] | Specific concerns Claude raised.                               |
| `recommendations`  | list[string] | Specific fixes Codex must make for rework.                     |
| `reviewed_at`      | string (ISO) | UTC timestamp.                                                 |

---

When you change a schema:
1. Edit the table above first.
2. Update the producer prompt (which fields to write).
3. Update the consumer prompt (which fields to read).
4. Bump a `schema_version` field on the schema if breaking change.

Never let prompts disagree with this file.
