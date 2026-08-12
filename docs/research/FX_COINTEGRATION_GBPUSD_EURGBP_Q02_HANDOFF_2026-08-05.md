# QM5_20223 GBPUSD/EURGBP FX cointegration Q02 handoff

Date: 2026-08-05
Branch: agents/board-advisor
Status: Q01 PASS; one logical-basket Q02 work item PENDING; post-enqueue fleet
at the seven-terminal CPU ceiling

## Outcome

QM5_20223_gbpusd-eurgbp is a new, dedicated, low-frequency D1 FX
cointegration basket. It is the first unbuilt exact pair after the already
mechanized frontier in the frozen sign-aware 66-pair scan. The approved Card,
EA source and binary, deterministic registry rows, two-symbol basket manifest,
and RISK_FIXED presets are committed on this branch.

Q02 work item `696ed8f9-476b-4238-ac17-cf9a0f68e0e8` was enqueued at
2026-08-05T09:39:03Z for logical symbol
`QM5_20223_GBPUSD_EURGBP_COINTEGRATION_D1`. It was pending and unclaimed at
verification. The physical `GBPUSD.DWX` host preset was deliberately skipped
with reason `basket_manifest_logical_setfile_preferred`.

## Anchor triage

- QM5_12532 has canonical Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- QM5_12533 has canonical Q02 PASS, followed by Q04 FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker. Repairing or
  duplicating either Q02 run was therefore unwarranted.

## Selection and source boundary

The fixed scan was reproduced with:

    python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges

GBPUSD/EURGBP is sign-aware rank 44 of 66:

| Measure | Frozen value |
|---|---:|
| DEV net Sharpe | -0.078882576442 |
| OOS net Sharpe | -0.098985257721 |
| OOS return | -0.844505115263% |
| OOS state changes | 17 |
| DEV beta | -0.399228065368 |
| Half-life | 149.504604611880 D1 bars |

The exact unordered pair was absent from dedicated cards, EAs, registry rows,
and two-symbol traded manifests. The deterministic dedup guard returned CLEAN
for slug `gbpusd-eurgbp`, strategy ID
`AI-CODEX-FX-COINT66-20260609-GBPUSD-EURGBP`, and mechanic
`cointegration-pair-trade`.

The mechanical method is bounded to the OWNER-ratified Tier-A extraction of
Ernest Chan's pair-trading examples in
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the method, not a GBPUSD/EURGBP performance claim. Negative DEV and OOS scores,
the long half-life, and cadence inferred below the binding Q02 floor are
explicit adverse evidence. Economic or frequency failure retires the sleeve;
it does not authorize a beta refit, filter, or parameter rescue.

## Implementation contract

- Host and first traded leg: `GBPUSD.DWX`, D1.
- Companion and second traded leg: `EURGBP.DWX`.
- Frozen residual: `ln(GBPUSD) - (-0.399228065) * ln(EURGBP)`.
- Entry: absolute z-score above 2.0, scored against the strictly prior 60
  aligned closed-D1 residuals.
- Exit: absolute z-score below 0.5; each leg also has a 2.0 ATR(20) stop.
- Negative beta makes a long-spread package long both pairs and a short-spread
  package short both pairs.
- Partial entry failure and orphaned-leg states flatten the whole package.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The basket is regression-residual-neutral only; it retains currency, carry,
  and broad risk-sentiment exposures.

## Q01 evidence

- Strict compile: PASS, zero errors, zero warnings.
- Strict build check: PASS, zero failures, zero warnings.
- Build report:
  `D:\QM\reports\framework\21\build_check_20260805_093400.json`.
- Compile summary: `D:\QM\reports\compile\20260805_093341\summary.csv`.
- Strategy Card schema lint: PASS on draft, approved, and EA-local copies;
  zero missing sections and zero ML-ban hits.
- Spec validation and build guardrails: PASS.
- Symbol scope: BASKET_OK with zero violations.
- Basket manifest regression: 40 passed.
- Magic resolver regressions: 5 passed.
- Magic rows: `GBPUSD.DWX` slot 0 / 202230000 and `EURGBP.DWX` slot 1 /
  202230001.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the final strict build are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `2B07AFFB65A30A82D19ED2AFDAE8BF6A180DABF383D95E49AE847C129E9D4887` |
| EX5 | `7C0B1ED6777ED6622AF451A7E8658284C7A1100635FAD64FD929925B5D2EA751` |
| basket manifest | `DC51A81594BD9928AA97297B65A02DB38C4D02364152D7CF70930444DB765959` |
| logical Q02 setfile | `EE8FCDC593CD6B75670F4F0CCBB2E1665A3414743F525D7EFDE6CCA3850FFA6D` |
| physical host setfile | `F1A559AD0DED5AAA3F454654D615D3B4ED3E3869D38E3F2EE14242EF08A949CC` |

## Q02 enqueue and fleet safety

The guarded enqueue used
`tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20223`.
Fourteen observations found the canonical mutation lock legitimately occupied
by `farmctl.py pump`; the lock was never bypassed, removed, or reaped. The
successful acquisition occurred with six running factory terminals, below the
binding ceiling of seven. Queue evidence is
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`; it records one
priority-track logical insertion, one physical-preset skip, and 1,568 pending
rows before insertion against the separate 7,000-row queue ceiling.

The immediate verification found exactly one QM5_20223 row, Q02 PENDING and
unclaimed. The following capacity scan found seven factory terminals running
(`T1,T10,T2,T3,T4,T5,T9`). Work stopped at that ceiling. No dispatch tick,
terminal reservation, tester launch, T_Live action, AutoTrading action, or
portfolio-gate edit was performed.

## Commit chain

- `455dc0fdf`: source-backed G0 approval and research decision.
- `babc308c0`: deterministic EA, binary, manifest, presets, registries,
  resolver, cards, and regression test.
- The following ops commit records the verified Q02-pending state and this
  handoff.

No portfolio admission/contribution gate and no T_Live manifest was changed.
