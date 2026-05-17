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

Producer: `framework/scripts/smoke_*.ps1` (one summary per (ea, symbol, year)
test session, with one or more `runs[]` entries).  Consumer: codex_review
§D, claude_review, pump record_build_result.

Top-level fields:

| Field                   | Type           | Description                                          |
|-------------------------|----------------|------------------------------------------------------|
| `timestamp_utc`         | string (ISO)   | When the run kicked off.                             |
| `run_tag`               | string         | YYYYMMDD_HHMMSS tag (also dir name under `smoke/`).  |
| `result`                | string         | `"PASS"` or `"FAIL"` (overall).                      |
| `reason_classes`        | list[string]   | If FAIL, the classes (e.g. `["MIN_TRADES_NOT_MET"]`).|
| `ea_id`                 | int            | Numeric EA id (e.g. `1049`).                         |
| `ea_label`              | string         | `QM5_NNNN`.                                          |
| `expert`                | string         | Expert subpath used in tester.                       |
| `symbol`                | string         | DWX/native symbol tested.                            |
| `year`                  | int            | Backtest year (e.g. `2024`).                         |
| `terminal`              | string         | `"T1"`..`"T5"`.                                       |
| `model`                 | int            | Tick model (4=every-tick required).                  |
| `period`                | string         | Timeframe (`"H1"`, `"D1"`, etc.).                    |
| `min_trades_required`   | int            | Pass threshold for trade count.                      |
| `deterministic`         | bool           | Re-run determinism check passed.                     |
| `oninit_failure_detected`| bool          | EA OnInit returned INIT_FAILED in any run.           |
| `model4_log_marker_detected`| bool       | Required marker present.                             |
| `report_dir`            | string (path)  | Where raw run reports live.                          |
| `runs`                  | list[object]   | Per-run results — see below.                         |

Each `runs[i]` entry:

| Field          | Type     | Description                                                |
|----------------|----------|------------------------------------------------------------|
| `run`          | string   | `"run_01"`, `"run_02"`.                                    |
| `status`       | string   | `"PASS"` / `"FAIL"`.                                       |
| `failure`      | string   | If FAIL, the class (`"REPORT_MISSING"`, etc.).             |
| `error`        | string   | Human-readable error if any.                               |
| `exit_code`    | int      | Tester process exit code.                                  |
| `report_path`  | string   | Path to the report.htm (if produced).                      |
| `total_trades` | int      | Trades in this run (when report parsed).                   |
| `net_profit`   | float    | (when report parsed).                                      |
| `max_dd`       | float    | (when report parsed).                                      |
| `final_balance`| float    | (when report parsed).                                      |

Sanity bar for codex_review §D (checks the TOP-LEVEL `result` field and
the FIRST `runs[0]` entry):
- Top-level `result == "PASS"` → §D PASS.
- Top-level `result == "FAIL"` AND `reason_classes` contains
  `"MIN_TRADES_NOT_MET"` → §D FAIL with finding "0 trades in smoke window".
- Other failure classes (`"REPORT_MISSING"`, `"INCOMPLETE_RUNS"`,
  `"MODEL4_MARKER_REQUIRED"`) are build-infra issues — §D PASSes (these
  surface via §E `blocked_reason` instead).

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
