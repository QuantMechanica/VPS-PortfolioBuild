# Ratified gate decision/doc/code/test matrix

Date: 2026-08-21

Task: `6fe2ab8c-7a49-47fc-8f15-471bb1eb4331`

Status: **RATIFIED 2026-08-22 — OWNER-DEC-GATECONTRACT; thresholds unchanged.**

The canonical Company Reference Vault on `G:/My Drive/QuantMechanica - Company Reference/` was unavailable to this headless process (`Test-Path=False`). The documentation column therefore cites the durable repository copy where one exists and says `MISSING` where the canonical page could not be inspected. It does not infer Vault contents from code.

| Contested point | Ratifying decision + effective date | Documentation | Executable code | Contract test |
|---|---|---|---|---|
| Q01 smoke waiver | `decisions/2026-08-22_q01_smoke_saturation_waiver.md`: accepted; waiver is limited to a compiled/build-clean result carrying `deferred_p2_smoke` plus durable tester-saturation evidence. | `docs/ops/GATE_CONTRACTS_2026-08-22.md`; producer/reviewer wording in `tools/strategy_farm/prompts/SCHEMAS.md`, `codex_build_ea.md`, `codex_review_ea.md`, and `claude_review_ea.md`. | `tools/strategy_farm/farmctl.py::_q01_smoke_admission` fails missing/blank/generic deferrals closed, retains zero-trade blocking, and records the admission basis on Q02 payloads. | `tools/strategy_farm/tests/test_zero_trade_prevention.py` locks missing, unsupported deferred, saturation-waived, passed, and zero-trade cases. **MATCHES.** |
| Q02 PF floor | `C:/QM/repo/decisions/2026-07-25_q02_pf_floor_120_to_110.md:69-72`: accepted OWNER amendment disables the evidence curve and makes the floor flat 1.10. Effective 2026-07-25. | Repository fallback is stale: `C:/QM/repo/docs/ops/PIPELINE_REWRITE_PROPOSAL_2026-05-23.md:43` says `PF > 1.30`. Canonical Vault page: **MISSING — G: unavailable.** | `C:/QM/repo/framework/scripts/p2_baseline.py:234` sets `Q02_PF_MIN = 1.10`; `:261-272` records the disabled curve and `hard_bottom_pf=1.10`; `:400-403` applies that floor. | `C:/QM/repo/framework/scripts/tests/test_p2_baseline.py:291-307`: proves 1.30 passes and 1.09 fails while the curve flag is false. **MATCHES decision/code.** |
| Q07 second axis | `C:/QM/repo/decisions/2026-07-25_q07_second_axis_worst_seed_pf.md:29-31`: PASS if every seed is non-losing and either variance is below 20%, or worst-seed PF is at least 1.10 with variance below 40%. Effective 2026-07-25. | Repository fallback omits the second axis: `C:/QM/repo/docs/ops/PIPELINE_REWRITE_PROPOSAL_2026-05-23.md:48` documents only variance below 20% and no seed PF below 1.0. Canonical Vault page: **MISSING — G: unavailable.** | `C:/QM/repo/framework/scripts/q07_multiseed.py:47-59` defines 20%, 1.0, 1.10, and 40%; `:739-775` enforces losing-seed precedence and the bounded second axis. | `C:/QM/repo/framework/scripts/tests/test_q05_q07_verdicts.py:1928-1954`: positive second-axis, weak-worst-seed, extreme-dispersion, and losing-seed cases. **MATCHES decision/code.** |
| Q08 N/A handling | `decisions/2026-08-22_q08_fixed_parameter_not_applicable.md`: accepted; current fixed-parameter behavior is ratified without widening structural proof. | `docs/ops/GATE_CONTRACTS_2026-08-22.md` plus retained implementation evidence `docs/ops/evidence/2026-07-27_q08_evidence_defects_fix.md`. | `sub_8_5_neighborhood.py` requires explicit structural proof; `sub_8_7_pbo.py` maps authoritative `INVALID_NA`; `aggregate.py` keeps N/A sub-gate-only and non-punitive. | `framework/scripts/tests/test_q08_davey_subgates.py` proves both N/A mechanisms, non-blocking clean behavior, and computed-failure precedence. **MATCHES.** |
| Q09 hard portfolio gate | `C:/QM/repo/decisions/2026-07-26_q09_hard_gate_dl083_port.md:8-21`: accepted OWNER rule; stricter-of-two correlation, reject at `>=0.40`, strong admit below `0.15` with positive marginal contribution, otherwise delta-Sharpe `>=0.020`. Effective after the reviewed 2026-07-26 gate merge (`:29-34`). | Repository fallback is materially stale/renumbered: `C:/QM/repo/docs/ops/PIPELINE_REWRITE_PROPOSAL_2026-05-23.md:50` calls Q09 News Impact Mode rather than hard portfolio admission. Canonical Vault page: **MISSING — G: unavailable.** | `C:/QM/repo/tools/strategy_farm/portfolio/portfolio_admission.py:48-88` binds the decision and constants; `:107-121` computes the stricter-of-two value; `:433-462` invokes the hard classifier and fails insufficient overlap closed. | `C:/QM/repo/tools/strategy_farm/tests/test_portfolio_admission_dl083_gate.py:42-141` locks constants, both binding bases, UNKNOWN handling, and all threshold boundaries. **MATCHES decision/code.** |
| Q10 recency enforcement | `decisions/2026-08-22_q10_recency_cohort_activation.md`: accepted; exact cohort is every Q10 row with `created_at >= 2026-09-01T00:00:00Z`; older rows remain shadow-only. | `docs/ops/GATE_CONTRACTS_2026-08-22.md` mirrors the cutoff, two enforcing thresholds, UNKNOWN behavior, and stale-window blocker. | `q10_recency.py` enables the policy switch; `q10_confirmation.py::_apply_recency_gate` applies it by immutable row timestamp; `farmctl.py::_phase_runner_cmd_for_work_item` passes that timestamp and fails closed if absent. | `framework/scripts/tests/test_q10_recency.py` locks pre-cutoff shadow, cutoff boundary, PF/decline failure, UNKNOWN, and staleness; `test_phase_runner_process_lineage.py` locks timestamp transport. **MATCHES.** |

## Sign-off findings

1. **Decision/code/test aligned:** Q02, Q07, and Q09. Their repository documentation fallbacks are stale; the canonical Vault pages could not be checked in this session.
2. **Ratification closed:** Q01 is saturation-only and Q08 fixed-parameter N/A is explicitly ratified.
3. **Policy/code conflict closed:** Q10 has a deterministic 2026-09-01 cohort switch and no retroactive regrading.
4. **Vault mirror still unavailable:** the repository decisions and gate-contract mirror are durable; canonical Vault synchronization remains an OWNER/documentation operation, not a reason to weaken executable gates.

## Focused verification

The current executable contracts were checked without writes to factory or terminal state:

```text
python -m pytest -q tools/strategy_farm/tests/test_zero_trade_prevention.py
  tools/strategy_farm/tests/test_p2_full_dwx_fanout.py
  tools/strategy_farm/tests/test_basket_work_items.py
  tools/strategy_farm/tests/test_dwx_history_range_filter.py
  framework/scripts/tests/test_q08_davey_subgates.py
  framework/scripts/tests/test_q10_recency.py
  framework/scripts/tests/test_q10_confirmation.py
  tools/strategy_farm/tests/test_phase_runner_process_lineage.py
191 passed in 14.02s
```

## 2026-08-22 ratification closeout

OWNER-DEC-GATECONTRACT supplied the authority and the missing Q10 cohort date.
The three dated decision records, gate-contract mirror, executable changes, and
focused tests now close the formerly contested cells. Historical evidence keeps
its original semantics; no pre-cutoff Q10 row is regraded and no gate threshold
was changed.

Implementation evidence: `docs/ops/evidence/2026-08-22_gate_contract_ratification.md`.
