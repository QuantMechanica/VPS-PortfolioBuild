# STR-021 — Build record (QM5_20098)

- ea_id **20098** reserved via farmctl reserve_ea_ids (atomic; strategy_id
  WEB-SOURCES-HARVEST-2026-07), row in `framework/registry/ea_id_registry.csv`.
- Magic rows: 200980000-200980001 for XAUUSD.DWX(0) XAGUSD.DWX(1) in `framework/registry/magic_numbers.csv`
  (collision-guarded append under registry lock); resolver regenerated via
  `update_magic_resolver.py` and all magics verified present (commit 664902bc4).
- Skeleton: `framework/templates/EA_Skeleton.mq5` copy, only inputs + 5 hooks
  filled (codex bodies, task 18d690d2; integrated via Edit — no blind apply);
  conventions: input group "Strategy", perf-allowed markers reviewer-signed.
- Card: `D:\QM\strategy_farmrtifacts\cards_approved\QM5_20098_weekly-open-liquidity-sweep_card.md`
  (G0 cross-approved by codex — builder!=approver).
- SPEC.md: validate_spec_doc PASS. build_check.ps1 PASS. compile_one.ps1 -Strict:
  0 errors / 0 warnings, fresh .ex5 (build+commit atomic, commit 67d9a3d24).
- Set files: 2 sets M15 backtest, gen_setfile.ps1 (-Env backtest; RISK_FIXED=1000,
  RISK_PERCENT=0). NOTE: build_hash header line empty — Get-FileHash missing in
  the constrained shell (provenance-only; run_smoke hashes independently).
- Compliance (Q01 checklist): magic registered + verified; risk mode FIXED
  (backtest sets) / PERCENT intent live; per-trade cap framework 1%; news filter
  framework fail-closed; KS_DAILY_LOSS 3% hardcoded; KS_PORTFOLIO_DD external
  guard live (QM_StrategyFarm_LiveBookDDGuard); Friday-close default-on.

## Cross-review closure (task 20cb7145)

Codex integration review: 6x CONFIRM (splice line-identical, skeleton contract
sha-verified, closed-bar discipline, strategy fidelity, guardrails PASS,
validators PASS) + 1 P3 defect (input-group rename) — **REBUTTED with
evidence**: build_check ERRORs on any group name other than the literal
"Strategy" (EA_INPUT_GROUP_MISSING, report build_check_20260724_111725.json);
the framework guardrail forced the rename. Specs amended to codify it.
