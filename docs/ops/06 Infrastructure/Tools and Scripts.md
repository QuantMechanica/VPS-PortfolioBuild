# Infrastructure: Tools and Scripts

## PBO toolchain (P3 -> P7)

- `framework/scripts/pbo_calculator.py`
  - Purpose: deterministic CSCV-based computation of `pbo_pct`.
  - Input: CSV rows with `config_id`, `slice_id`, `score`.
  - Output: JSON with `pbo_pct`, `splits_evaluated`, `overfit_splits`.
- `framework/scripts/p7_statval.py`
  - Purpose: enforce P7 hard gates.
  - Reads `pbo_pct` from `--sweep-pass-rows`.
  - Does not estimate PBO itself.

## Ownership decision

- PBO calculation ownership is assigned to `pbo_calculator.py` in pipeline infrastructure.
- P7 ownership remains verification-only (gate enforcement and verdict emission).
- Missing `pbo_pct` is treated as a deterministic hard-fail path at P7.

## P4 walk-forward runner

- `framework/scripts/p4_walk_forward.py`
  - Purpose: enforce P4 gate structure (`>=6` folds, anchored windows, DEV->HO embargo, regime labels, clean OOS evidence).
  - Inputs: `--ea`, `--walk-forward-csv`, optional `--out-prefix`.
  - Outputs: `P4_<ea>_result.json`, `phase_runner_log.jsonl`, and `report.csv`.

Exact command:

```bash
python framework/scripts/p4_walk_forward.py --ea QM5_1001 --walk-forward-csv framework/scripts/tests/fixtures/p4_walk_forward.csv
```

## Strategy Wiki Tooling

- `framework/scripts/lint_strategy_wiki.py`
  - Purpose: deterministic lint for Strategy Wiki graph integrity.
  - Checks:
    - broken `[[...]]` cross-references
    - missing YAML frontmatter
    - `_INDEX.md` drift vs filesystem
    - duplicate IDs/slugs
  - CLI:
    - `python framework/scripts/lint_strategy_wiki.py [--vault PATH]`
  - Default vault:
    - `G:\My Drive\09 Strategy Wiki`
  - Exit codes:
    - `0` clean
    - `1` violations / invalid vault

- `framework/scripts/research_dedup_check.py`
  - Purpose: deterministic dedup checks across registry + cards + wiki strategies.
  - Commands:
    - `check`
    - `list`
    - `audit`
  - Sources:
    - `strategy-seeds/cards/*.md`
    - `09 Strategy Wiki/strategies/*.md` (via `--vault`)
  - CLI examples:
    - `python framework/scripts/research_dedup_check.py check --slug <slug> --strategy-id <id> [--vault PATH]`
    - `python framework/scripts/research_dedup_check.py list [--vault PATH]`
    - `python framework/scripts/research_dedup_check.py audit [--vault PATH]`
