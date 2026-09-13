# Health-check RCA: evidence-cohort LOSS_OBSERVED + ftmo_trial_pulse MONTHLY_SLEEVE_STATE

Date: 2026-09-13
Author: ops (agents/board-advisor)
Scope: two failing health checks — `schtask:QM_EvidenceCohortWatch_Daily_0420`
(LOSS_OBSERVED, exit 3, also trips `task_monitor_escalation`) and `ftmo_trial_pulse`
(FAIL / ALARM).

Constraints honoured: `farm_state.sqlite` opened read-only; FTMO terminal + `T_Live`
read-only; no git, no scheduled-task edits, no terminal starts. One Python tooling
defect fixed with a test (rollback documented). No restore executed.

---

## CHECK 1 — EvidenceCohortWatch LOSS_OBSERVED

**Watcher:** `tools/strategy_farm/evidence_cohort_watch.py` (baseline
`artifacts/evidence_cohort_baseline.json`, log `D:\QM\strategy_farm\logs\evidence_cohort_watch.log`).
It baselined 1205 rows on 2026-08-17 whose `evidence_path` (`summary.json` /
`aggregate.json`) existed then, and re-checks each with a literal `os.path.exists`.

**Observed:** the 2026-09-13 02:20Z run reported `watched=1205 intact=176
file_missing=1029 root_missing=0` → exit 3. `file_missing` has climbed steadily
(0 on 08-23 → 240 on 08-24 → 1029 on 09-13); the working-tree baseline modification is
this scheduled run's own appended observation + losses (not a hand edit).

**Root cause — the exit-3 is dominated by a watcher false positive.** DL-090 retention
(`tools/strategy_farm/report_retention.py`, `mode=apply` daily ~02:20Z, log
`D:\QM\reports\state\report_retention.log`) **compresses the kept set in place**:
`summary.json` → `summary.json.gz`, then unlinks the original (report_retention.py
L268-275). The watcher checks the `.json` path only and is blind to the `.gz` sibling, so
every compressed kept row is mis-reported as deleted.

Disk reality of the 1029 flagged rows (script: scratchpad `verify_loss*.py`):

| class | count | meaning |
|---|---|---|
| `.json.gz` sibling present | **857** | DL-090 compression — evidence survived (false positive) |
| in `D:\QM\reports\_retention_quarantine\*` | **16** | DL-090 age-out (non-PASS superseded/infra), recoverable |
| genuinely absent (no file, no `.gz`, not quarantined) | **156** | real content loss |

- Verdict mix of the 1029: 518 PASS-family, 351 FAIL-family, 160 ZERO_TRADES.
- **Genuine loss = 172 rows** (95 PASS-family, 69 FAIL, 8 ZERO_TRADES); 16 are in the
  surviving quarantine window, leaving **156 unrecoverable in place (95 PASS-family)**.

**PASS-class loss = a real DL-090 concern (P0 candidate for the orchestrator).** DL-090
S2.1 keeps every PASS run indefinitely, yet 95 PASS-family artifacts that existed at
baseline are gone with no `.gz` and not in the surviving quarantine. Their run dirs exist
but are **empty** (e.g. `D:\QM\reports\work_items\c9dad40f-...\QM5_20176\20260816_214903\`
= empty `raw\run_01`, `raw\run_02`; dir mtime 08-31 17:21, off the 02:20 retention
cadence). 81 of the 95 are the **sole** PASS run for their `(ea_id,symbol,phase)` cell
(DB read-only check). The deleting mechanism is **not** the current retention tool
(compression leaves `.gz`; PASS is never aged-out/quarantined) — it is the pre-existing
unexplained-deletion class this watcher was built to detect (cf.
`docs/ops/evidence/2026-08-17_P0_evidence_loss_is_dated_not_ongoing.md`,
`2026-09-05_m05_evidence_loss_adjudication.md`). The DB `work_items` rows and `ea_metrics`
numbers persist, so the **verdicts are intact**; only the backing report artifacts are
lost.

### Fix applied (tooling defect, with test + rollback)

`evidence_cohort_watch.py`: added `_evidence_present(path)` returning
`exists(path) or exists(path + ".gz")`, used in `cmd_check` (`f_ok`) and
`collect_candidates`. This aligns the watcher with its own stated purpose ("forward
observation of evidence **survival**") — a gzipped-in-place artifact is survival, not
deletion. No verdict/threshold changed; the report-root check is untouched.

- Test: `tools/strategy_farm/tests/test_evidence_cohort_watch.py::test_gzip_compressed_evidence_is_not_a_loss`
  (regression). Full file: **5 passed**.
- Validated against real disk (scratchpad `validate_fix.py`, baseline copy, no tracked
  file mutated): **file_missing 1029 → 172, intact 176 → 1033**, exit still 3.
- **Rollback:** `git checkout -- tools/strategy_farm/evidence_cohort_watch.py
  tools/strategy_farm/tests/test_evidence_cohort_watch.py` (three edits + one test).

### What still needs the orchestrator (not done here)

1. **After this fix the watch still exits 3** — correctly, for the 172 genuine losses
   (95 PASS-family). That is the true P0 signal, no longer buried under 857 compression
   rows. Adjudicate the PASS loss.
2. **Restore / regenerate plan (do not auto-run):**
   - 16 quarantined rows: restore from `D:\QM\reports\_retention_quarantine\<snapshot>\<rel path>`
     to the original path if any are wanted (all non-PASS age-outs).
   - 95 PASS + 61 other unrecoverable: not in surviving quarantine and not in DB backups
     (`state\backups` hold only the sqlite DB, not report files). Options: (a) an off-host
     report mirror if one exists; (b) **deterministic re-run** of the graded backtest to
     regenerate the artifact (verdict + `ea_metrics` already persist). Prefer (b) only for
     cells whose artifact a delivery decision will actually cite.
   - **Baseline refresh is NOT the fix** for the compression rows (the code fix handles
     them); `--init` only adds new rows and will not rewrite existing entry paths.
3. Consider making the watcher (or the retention job) emit a benign note when it
   compresses, so future audits don't re-litigate this.

---

## CHECK 2 — ftmo_trial_pulse FAIL (MONTHLY_SLEEVE_STATE ×2 for QM5_1537)

**Pulse:** `tools/strategy_farm/ftmo_trial_pulse.py`. Reported `condition=ok`,
`decision=OWNER-DEC-M13-ECONOMIC-TRIAL-20260906`, `review_trigger=20/25`,
`ea_errors: QM5_1537_ea-1537.log MONTHLY_SLEEVE_STATE (twice)` → verdict ALARM (exit 1).

**Source of the event:** `framework/EAs/QM5_1537_aa-vol-sma10/QM5_1537_aa-vol-sma10.mq5`
L242: `QM_LogEvent(ready ? QM_INFO : QM_ERROR, "MONTHLY_SLEEVE_STATE", ...)`. So the EA
deliberately logs **ERROR when `ready==false`** — this is **not** a regex
misclassification; the pulse regex (`level in ("ERROR","FATAL")`) is correct.

**FTMO log evidence** (read-only,
`...\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Files\QM\QM5_1537_ea-1537.log`):

| ts_utc | level | ready | valid_count | reject_reason |
|---|---|---|---|---|
| 2026-09-06T22:05:00Z | ERROR | false | 0 | `calendar_stale` |
| 2026-09-07T05:32:42Z | ERROR | false | 0 | `calendar_stale` |
| 2026-09-07T10:55:37Z | INFO | true | 37 | "" (recovered) |
| 2026-09-07T22:05:00Z | INFO | true | 37 | "" |
| 2026-09-09T17:49:25Z | INFO | true | 37 | "" |

The two ERRORs are **real but stale** — a September calendar-staleness right after M13
activation that **already recovered on 2026-09-07** and stayed healthy through 09-09.

**Why the pulse still alarms:** the pulse only clears a `MONTHLY_SLEEVE_STATE` ERROR when a
newer healthy state satisfies `ts >= latest_init` (ftmo_trial_pulse.py L517-547) — a
deliberate post-restart guard so a reboot cannot inherit a pre-restart healthy state.
The FTMO terminal **rebooted 2026-09-11** (VPS reboot, commit `43d2378f57`): the 1537 log
shows `DEINIT`/`INIT`/`INIT_OK` at 2026-09-11T19:51Z, whose `SLEEVE_CALENDAR_INIT` carries
a **valid** September calendar (`rows=108, last_month=202609`, sha256s present). No
`MONTHLY_SLEEVE_STATE` has been emitted since (last log line = Friday `FRIDAY_CLOSE`;
XAGUSD has no weekend ticks). So `latest_init` (09-11) is newer than the last healthy sleeve
proof (09-09), the guard rejects it, and the 09-06/07 ERRORs resurface.

**Verdict: false alarm from a real-but-recovered fault; no live sleeve problem** (the
09-11 `SLEEVE_CALENDAR_INIT` proves the September calendar is valid). Equity/risk limits
are clean; the M13 economic-trial review trigger (qualified_pairs 20/25) is independent and
**unaffected**.

### Resolution (no code change — the guard is verdict logic, out of scope)

- **Expected self-clear:** at the next XAGUSD session open (**Mon 2026-09-14**) the EA
  ticks and emits a fresh `MONTHLY_SLEEVE_STATE` (INFO, valid_count 37, month 202609) after
  the 09-11 INIT; that satisfies `ts >= latest_init` and clears both stale errors → pulse
  returns OK. No OWNER action needed if it clears.
- **If it does NOT clear Monday:** treat as a real sleeve-calendar issue — OWNER runs
  `tools/strategy_farm/qm1537_monthly_sleeve_refresh.py` on the FTMO host (FTMO is
  OWNER-controlled; AI is read-only there) and confirms a fresh healthy
  `MONTHLY_SLEEVE_STATE`.
- **Optional monitor hardening (orchestrator/OWNER decision — changes alarm suppression,
  therefore not done here):** give the `MONTHLY_SLEEVE_STATE` recovery a weekend /
  post-reboot grace (as `kill_switch_runtime_proof_warns` already has), so a mid-period
  reboot with a still-valid `SLEEVE_CALENDAR_INIT` does not resurface recovered errors
  until the next scheduled sleeve emission.

---

## Evidence index

- Watcher / baseline / log: `tools/strategy_farm/evidence_cohort_watch.py`,
  `artifacts/evidence_cohort_baseline.json`, `D:\QM\strategy_farm\logs\evidence_cohort_watch.log`
- Retention: `tools/strategy_farm/report_retention.py`,
  `D:\QM\reports\state\report_retention.log`, `D:\QM\reports\_retention_quarantine\*`
- DL-090: `decisions/DL-090_backtest_report_retention_policy.md`
- Fix + test: `tools/strategy_farm/evidence_cohort_watch.py`,
  `tools/strategy_farm/tests/test_evidence_cohort_watch.py`
- Pulse: `tools/strategy_farm/ftmo_trial_pulse.py`; EA emitter
  `framework/EAs/QM5_1537_aa-vol-sma10/QM5_1537_aa-vol-sma10.mq5` L242
- FTMO log (read-only):
  `...\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Files\QM\QM5_1537_ea-1537.log`
