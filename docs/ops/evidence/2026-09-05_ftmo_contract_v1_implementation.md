# FTMO probability and correlation contract V1 — implementation receipt

Date: 2026-09-05
Router task: `814de468-ab19-4640-aa46-6ca6d66d9b1f`
Result: `PASS_IMPLEMENTATION_REVIEW — ECONOMIC DECISION UNCHANGED`

## Delivered contract and loader

The embedded JSON from `FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md` is materialized as `tools/strategy_farm/config/ftmo_probability_contract.v1.json` (SHA-256 `54cb80fd4623a8a08d792c0d15b347f7999a7ff3565d373121e01dba3bef7e27`). The strict loader rejects duplicate keys, non-finite JSON, schema/root drift, a fallback-enabled ROT contract, P1/DSR drift, and any attempted activation of the C-6 gates.

The loader validates the rulepack percent strings through the explicit conversion `Decimal(value) * Decimal("0.01")`. It proves parity for point P1 `"80" -> 0.80`, breach `"10" -> 0.10`, P2 conditional `"85" -> 0.85`, and joint `"65" -> 0.65`; freshness and shadow-run counts are also checked. The rulepack's proposed P1 lower `"70" -> 0.70` is retained as a dominated source value: the binding ratified lower bound remains the stricter `0.80` and, because `lower <= point` is enforced, no additive point gate is introduced.

DSR remains a separate necessary gate with fleet default `N=369`. `DECLARED_TRIAL_COUNT=154` remains solely the opt-census measurement declaration and is never imported as the DSR selection pool.

## Engine consumption

- `build_book_ftmo.py` reads P1 lower `0.80`, strict hard book correlation `|r| < 0.50`, account weight `10.0`, sleeve unit weight `1.0`, and bootstrap replicate floor `100` from the versioned contract.
- The builder no longer consumes the zeros-dropped raw signed matrix. It accepts only V4 Layer-A `CERTIFY_A` records and uses the conservative absolute CI endpoint `abs_upper`. `PROVISIONAL`, `ABSTAIN`, missing, and malformed pairs fail closed as `CLUSTER_CORRELATION_UNVERIFIED`. Layer-B `FLAGGED` remains supplementary and cannot override a valid Layer-A certification.
- The selector compares absolute magnitude, so `r=-0.92` is rejected; equality at `0.50` is also rejected because the gate is exclusive.
- `ftmo_timebox_eval.py` reads the 60/30 calendar-day horizons, P1 design bar, 2,000-replicate moving-block bootstrap settings, `0.15` warning band, `0.40` timebox reject, and 20-day shared-calendar floor from the same contract. Its result records the contract SHA and the inert C-6 statuses.
- `ftmo_p1_mc.py` and `challenge_firstpassage.py` now label their outputs `DIAGNOSTIC_ONLY`. MC records that 90 trading days is roughly 126 calendar days versus the authoritative 60-calendar-day P1 estimand and is structurally optimistic; first-passage records that its unlimited horizon and in-sample-selected stages are non-binding.

## C-6 gates kept inert

No estimator was designed or inferred in this change. These outputs cannot pass or fail a book:

| Output | Status | Reason |
|---|---|---|
| Breach upper-95 <= 0.10 | `INERT_UNTIL_C6_ENGINE_OWNER_APPROVED` | MC breach is only a lower bound; no admissible upper-bound construction is specified. |
| P2 conditional >= 0.85 | `INERT_UNTIL_C6_ENGINE_OWNER_APPROVED` | No approved conditional-bound credit formula exists. |
| Joint two-phase >= 0.65 | `INERT_UNTIL_C6_ENGINE_OWNER_APPROVED` | No approved joint credit formula exists. |

C-2 proposed rulepack gates (freshness and shadow run) retain their declared status from the contract; this implementation does not promote them. No book, threshold, roster, farm state, terminal, or deployment state was changed.

## Current sealed-eight scratch decision

All outputs are read-only derivatives under `D:/QM/reports/portfolio/ftmo_contract_v1_20260905/`. The source bundle is the eight-stream, loader-verified current population at `D:/QM/strategy_farm/artifacts/portfolio/fund_score_current_population_20260904_bc7e/`.

| Artifact | SHA-256 |
|---|---|
| `roster.json` (8 qualified pairs) | `426cb0bae4876c0549f5b660e4900ce0172885014a4b5695e167372e5cf270c1` |
| `fund_scores.json` (8/8 scored) | `2b5757d8680437947e4943f5d685f10b13a5356fa2c24fb40dd49d918da5fc78` |
| `correlation_v4.json` | `bdc4eac9c89b28bed7b1855c73287156366ab1dda349b2242080f45c28b88d8a` |
| `manifest_after.json` | `6867feb4051af67ddfdff42ba4598c285c3607a38d9767d33d89dc6c4c2cee1a` |

Before migration, the raw active-only matrix had zero usable pairs and listed all 28 pairs as insufficient overlap. The old builder nevertheless selected zero sleeves before correlation became relevant because every current FUND_SCORE is below the unchanged `1.0` floor; the decision was `BAR_NOT_MET`.

After migration, Layer A produced `CERTIFY_A` for 28/28 pairs, with maximum `abs_upper=0.313426`; the combined supplementary surface reports 25 `CERTIFIED` and 3 Layer-B `FLAGGED`. The builder consumes all 28 valid Layer-A CI endpoints. It still selects zero sleeves because all FUND_SCORE rows remain below `1.0`, so the decision remains `BAR_NOT_MET`. This is the intended decision delta: estimator correctness changes, economic outcome does not.

The scratch manifest checks are: FUND_SCORE fail, aggregate-control fail (empty selected roster), density fail, cost/swap coverage vacuously true for the empty selected roster, P1 bootstrap fail (missing), and concentration-tail fail. It is not a book build and carries `deployment_action=NONE`, `autotrading_action=NONE`, `challenge_recommendation=NONE`.

## Verification

Focused command:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_probability_contract.py tools/strategy_farm/tests/test_dual_book_builders.py tools/strategy_farm/tests/test_ftmo_timebox_eval.py tools/strategy_farm/tests/test_portfolio_correlation.py -q
```

Result: 44 passed, 1 optional dependency skip before the final output-label assertion was added; the final rerun result is recorded with the task verdict. `py_compile` passes for the loader and all four engine consumers. `git diff --check` passes.

No C-6 estimator, purchase, book build, live action, AutoTrading change, or terminal action occurred.
