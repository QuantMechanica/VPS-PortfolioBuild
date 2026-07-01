# Round24 Admission Screen CLI Evidence

Task: `97e655fe-874c-438b-b7d9-721a6039b1a3`

Implemented a reusable `report.htm`-basis admission screen in:

- `tools/strategy_farm/portfolio/prop_challenge_optimizer.py`
- `tools/strategy_farm/tests/test_prop_challenge_optimizer.py`

## Behavior

- Added `--screen-candidate EA_ID SYMBOL` mode to screen one candidate against the Round24 lead.
- Parses native MT5 `report.htm` closing deals, not Q08 jsonl streams.
- Rebuilds Round24 lead daily PnL from `source_reports` in `prop_challenge_ftmo_combo_scale_sweep_round24_20260630.json`.
- Uses the clean Round24 bar within the max-loss guard. On the current Round24 artifact this selects:
  - risk scale `5.9`
  - min robust pass `57.04`
  - mean robust pass `57.776`
  - max max-loss breach `4.96`
  - mean target-not-reached `38.04`
- Emits one JSON verdict artifact with `ADMIT`, `BACKUP`, or `REJECT`, metric deltas versus Round24, parsed candidate report stats, selected weights, and confirmation rows when run.

Example:

```powershell
python tools\strategy_farm\portfolio\prop_challenge_optimizer.py `
  --screen-candidate QM5_10494 XAUUSD.DWX `
  --candidate-report <fresh-report.htm> `
  --screen-risk-scales 5.7,5.8,5.9,6.0,6.1 `
  --candidate-weights 0.01,0.02,0.03,0.05,0.08,0.10
```

## Verification

Focused unit test:

```powershell
python -m unittest tools.strategy_farm.tests.test_prop_challenge_optimizer
```

Result: `Ran 8 tests in 0.161s - OK`.

Syntax check:

```powershell
python -m py_compile tools\strategy_farm\portfolio\prop_challenge_optimizer.py tools\strategy_farm\tests\test_prop_challenge_optimizer.py
```

Result: PASS.

Real CLI smoke, using an existing validation report because no fresh `report.htm` was found under the configured validation root for `QM5_10494`, `QM5_12700`, `QM5_12832`, `QM5_12821`, or `QM5_12823`:

```powershell
python tools\strategy_farm\portfolio\prop_challenge_optimizer.py --screen-candidate QM5_10375 SP500.DWX --candidate-report "D:\QM\reports\prop_ftmo_candidates_20260629\validation_round27\QM5_10375\20260630_090000\raw\run_01\report.htm" --screen-risk-scales 5.8,5.9 --candidate-weights 0.01,0.02 --screen-runs 20 --screen-seeds 0,1,2,3,4 --force-confirm --out "D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_round24_admission_smoke_QM5_10375_SP500_20260630_codex.json"
```

Result:

- Verdict: `REJECT`
- Reason: `confirmed screen breaches the max-loss guard`
- Candidate report: `QM5_10375:SP500.DWX`, `641` closed trades
- Benchmark: clean Round24 bar at risk scale `5.9`
- Output artifact: `D:\QM\strategy_farm\artifacts\portfolio\prop_challenge_ftmo_round24_admission_smoke_QM5_10375_SP500_20260630_codex.json`

No MT5 terminal was launched and `T_Live` / AutoTrading were untouched.
