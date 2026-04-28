Status: DevOps implementation complete for QUA-415 (Rule 7 set-file gate).

- Implemented set-file generator: `21cc3e6`
- Added worked example + deterministic output: `fc52012`
- Added dispatch gate proof artifact: `591e9af`

Validation artifacts:

- `docs/ops/QUA-415_SETFILE_WORKED_EXAMPLE_2026-04-28.md`
- `framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/sets/QM5_SRC04_S03_lien_fade_double_zeros_EURUSD.DWX_H1_backtest.set`
- `docs/ops/QUA-415_DISPATCH_GATE_EVIDENCE_2026-04-28.json`

Behavior now enforced:

- `resolve_backtest_target.py` rejects dispatch start without `job.setfile_path`.
- Reject code: `BACKTEST_REJECTED_NO_SETFILE`.
- Backtest set template enforces: `ENV=backtest`, `RISK_FIXED>0`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT`.

Pipeline-Operator follow-up required for co-owner closeout:

- Post workflow-side confirmation commit hash in QUA-415 showing dispatcher consumption of `setfile_path` in active run path.
