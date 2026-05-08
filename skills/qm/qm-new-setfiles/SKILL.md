---
name: qm-new-setfiles
description: Use when generating backtest set files for an EA across its canonical symbol list before a P2 baseline run. Don't use for individual symbol re-runs (edit the .set file directly instead). Don't use if setfiles already exist and are up-to-date.
owner: Pipeline-Operator
reviewer: CTO
last-updated: 2026-05-08
basis: framework/scripts/gen_setfile.ps1 + docs/ops/PIPELINE_PHASE_SPEC.md § P2 pre-flight
---

# qm-new-setfiles

Procedure for generating backtest `.set` files for an EA across its full canonical symbol list. This is a prerequisite for P2 baseline launch.

## When to use

- EA `.ex5` exists but `sets/` directory is empty or missing symbols
- CTO has allocated an `ea_id` and directed setfile generation
- Preparing for first P2 baseline run on a new EA
- A new symbol was added to the canonical list and needs a new setfile

## When NOT to use

- Setfiles already exist and match the current EA parameter set
- EA has not yet been compiled (build first via `qm-build-ea-from-card`)
- Generating setfiles for a P3 parameter sweep — P3 uses `.set` files with optimization ranges, not fixed parameters

## Canonical symbol list (39 symbols)

Exclude: `NDXm.DWX`, `GDAXIm.DWX` (empty relicts — no bar history).  
The generator script applies this exclusion automatically.

## Procedure

### Step 1: Confirm EA directory exists

```bash
ls C:/QM/repo/framework/EAs/QM5_<NNNN>_<slug>/
```

Expected: `QM5_<NNNN>_<slug>.ex5` + `QM5_<NNNN>_<slug>.mq5`

### Step 2: Run set file generator (all symbols)

```powershell
pwsh C:/QM/repo/framework/scripts/gen_setfile.ps1 `
  -EALabel QM5_<NNNN>_<slug> `
  -Period H1
```

Or for a specific symbol subset:
```bash
python C:/QM/repo/framework/scripts/gen_setfile.py \
  --ea QM5_<NNNN>_<slug> \
  --symbol EURUSD.DWX \
  --period H1
```

### Step 3: Verify output

```bash
ls C:/QM/repo/framework/EAs/QM5_<NNNN>_<slug>/sets/ | wc -l
```

Expected: 37 files (39 canonical minus 2 relicts).

Output naming: `<ea_label>_<SYMBOL>_H1_backtest.set`

Example: `QM5_1003_davey_baseline_3bar_EURUSD.DWX_H1_backtest.set`

### Step 4: Spot-check one setfile

```bash
cat "C:/QM/repo/framework/EAs/QM5_<NNNN>_<slug>/sets/<ea_label>_EURUSD.DWX_H1_backtest.set"
```

Verify:
- Symbol field matches `EURUSD.DWX` (DWX suffix, not raw broker name)
- Period = H1
- Default EA parameters are set (not sweep ranges for P2)

### Step 5: Commit

```bash
git add framework/EAs/QM5_<NNNN>_<slug>/sets/
git commit -m "feat(<ea_label>): generate H1 setfiles for canonical symbol matrix"
```

### Step 6: Ready for P2

After setfiles are committed, launch P2 via `qm-p2-baseline`.

## Key paths

- Generator: `framework/scripts/gen_setfile.ps1` (PowerShell) or `framework/scripts/gen_setfile.py` (Python)
- Output: `framework/EAs/QM5_<NNNN>_<slug>/sets/`

## References

- `framework/scripts/gen_setfile.ps1` — canonical generator
- `docs/ops/PIPELINE_PHASE_SPEC.md` § P2 pre-flight — setfile requirements
- `framework/EAs/QM5_<NNNN>_<slug>/sets/_TEMPLATE.set` — template (if exists)
