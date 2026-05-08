---
name: qm-p2-baseline
description: Use when Pipeline-Operator is launching a P2 Baseline Backtest sweep for an EA that has compile-PASS and setfiles generated. Don't use without an .ex5 file and setfiles. Don't use for P3 sweeps — P3 has a separate runner. Don't use if an existing P2 run is already in progress (check for lock file).
owner: Pipeline-Operator
reviewer: CEO
last-updated: 2026-05-08
basis: framework/scripts/p2_baseline.py + docs/ops/PIPELINE_PHASE_SPEC.md § P2
---

# qm-p2-baseline

Procedure for launching and monitoring a P2 Baseline Backtest sweep — the first quantitative filter in the V5 pipeline. Determines which symbols show any edge at all before parameter optimization.

## When to use

- EA has `.ex5` compiled under `framework/EAs/QM5_<NNNN>_<slug>/`
- Setfiles exist: `framework/EAs/QM5_<NNNN>_<slug>/sets/<ea_label>_<SYMBOL>_H1_backtest.set`
- No P2 run currently in progress (no lock file, no .htm files < 30 min old in the report dir)
- Assigned via a Kanban task with `phase=P2`

## When NOT to use

- No `.ex5` file (build first via `qm-build-ea-from-card`)
- No setfiles (generate first via `qm-new-setfiles`)
- P2 report already exists and has verdicts (use `--resume` flag if partial, or check if P3 should be launched instead)
- A P2 run is already running (WAIT, do not start parallel run)

## Pre-flight checklist

```
1. .ex5 exists:  framework/EAs/QM5_<NNNN>_<slug>/QM5_<NNNN>_<slug>.ex5
2. Setfiles exist: framework/EAs/QM5_<NNNN>_<slug>/sets/ (ls count matches symbol list)
3. No existing lock or in-progress run: D:\QM\reports\pipeline\QM5_<NNNN>\P2\ (no fresh .htm)
4. Factory terminals available: T1-T5 running (check via tasklist for terminal64.exe)
5. Disk space: D:\QM\ has >= 2 GB free
```

## Procedure

### Step 1: Dry run (ALWAYS first)

```bash
cd C:/QM/repo
python framework/scripts/p2_baseline.py --ea QM5_<NNNN> --dry-run
```

Inspect output:
- Any `INVALID: setfile_missing` → file a recovery issue for missing setfile and exclude that symbol
- Print shows symbol list and terminal assignment plan

### Step 2: Real run

```bash
cd C:/QM/repo
python framework/scripts/p2_baseline.py --ea QM5_<NNNN>
```

Optional flags:
- `--symbols EURUSD.DWX,GBPUSD.DWX` — run subset only
- `--resume` — skip symbols already PASS in existing report.csv
- `--period H1` — timeframe (default H1)

Expected runtime: ~3 hours for full 36-symbol sweep (sequential).

### Step 3: Monitor progress

Check .htm file count rising in `D:\QM\reports\pipeline\QM5_<NNNN>\P2\`:
```bash
ls D:/QM/reports/pipeline/QM5_<NNNN>/P2/ | wc -l
```
Do NOT trust tracker state alone — filesystem is truth.

### Step 4: Read the report

```
D:\QM\reports\pipeline\QM5_<NNNN>\P2\report.csv
```

Columns: `ea_id, phase, symbol, terminal, verdict, invalidation_reason, evidence`

Verdict categories:
| Verdict | Meaning | Action |
|---------|---------|--------|
| `PASS` | Symbol shows edge in P2 window | Advance to P3 |
| `FAIL` | No edge, sub-threshold | Park this symbol |
| `INVALID` | Setup problem (missing data, setfile error) | Fix setup; do not call EA weakness |
| `NO_REPORT` | Size-0 .htm file | Infrastructure problem; file recovery issue |

### Step 5: Attach evidence and close task

On exit code 0 (all symbols processed):
```bash
python C:/QM/paperclip/tools/ops/mark_done.py \
  --task <QM-NNNNN> \
  --agent pipeline-operator \
  --evidence "D:/QM/reports/pipeline/QM5_<NNNN>/P2/report.csv"
```

On exit code 1 (some FAIL/INVALID): inspect `report.csv`, file ONE summary issue with failed-symbol list + modal failure reason. Mark task done (partial results are still valid).

On exit code 2 (runner crash): report to Board Advisor. Do not retry.

### Step 6: If PASS symbols ≥ 1 — request P3 promotion

Comment on the parent issue with PASS symbol count. CEO decides whether to promote to P3.

## Key paths

- Runner: `framework/scripts/p2_baseline.py`
- Reports: `D:\QM\reports\pipeline\QM5_<NNNN>\P2\`
- JSON summary: `D:\QM\reports\pipeline\QM5_<NNNN>\P2\p2_<ea>_result.json`
- Per-symbol: `D:\QM\reports\pipeline\QM5_<NNNN>\P2\<ea_id>\<run_tag>\summary.json`

## DO NOT

- Start a parallel P2 run if one is already in progress
- File one recovery issue per failed symbol — file ONE summary issue
- Call `INVALID` or `NO_REPORT` an EA weakness — they are setup problems
- Use `pipeline_dispatcher.py` directly for P2 — it schedules state only, does NOT launch MT5
- Touch T6

## References

- `framework/scripts/p2_baseline.py` — canonical runner
- `docs/ops/PIPELINE_PHASE_SPEC.md` § P2 — phase spec
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` § P2 — gate thresholds
- `framework/scripts/dl054_gates.py` — DL-054 pre-launch gates (G1, G2, G5) wired into p2_baseline.py
