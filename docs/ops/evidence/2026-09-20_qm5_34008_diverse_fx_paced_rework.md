# QM5_34008 diverse-FX paced rework

## Scope and claim

- EA: `QM5_34008_multicurrency-basket-dispersion-hedger`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_34008_multicurrency-basket-dispersion-hedger.md`
- Router task: `fa7ca587-77f8-4cea-b71b-7bb1b746b33d`, claimed by `codex:agents/board-advisor`
- Canonical build task: `bc8b7e7e-9d73-459c-b322-d75ce7fc9e07`
- Diversity: seven `.DWX` FX pairs in one market-neutral H1 package
- No T_Live, AutoTrading, portfolio-gate, or live-manifest state was touched.

## Source repair

The repair keeps the approved cross-sectional dispersion mechanic and closes the
remaining build-review gaps:

- literal card direction: buy the minimum-return pair and sell the
  maximum-return pair;
- one `strategy_package_risk_pct=0.50` input, while governed backtests stay
  `RISK_FIXED=1000` and `RISK_PERCENT=0` and split fixed risk equally across the
  two legs;
- real 1.5-ATR broker-side protective stops on both legs;
- news admission on both selected leg symbols before the first order; and
- fail-closed validation of backtest risk mode plus finiteness/inclusive range
  validation for `qm_stress_reject_probability`.

The configuration guard does not compare `qm_rng_seed`, any `qm_news_*` input,
or any `qm_friday_close_*` input. Stress probability is not compared with a
default. All seven H1 backtest setfiles were regenerated with their exact active
magic-slot offsets and remain intentionally unbound (`build_hash: pending`)
until a fresh governed compile exists.

## PACER guard and admission evidence

Immediately before each syntactically valid enqueue attempt:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_34008_multicurrency-basket-dispersion-hedger/QM5_34008_multicurrency-basket-dispersion-hedger.mq5"
ok=true predicate=EA_FRAMEWORK_INPUT_PINNED source_count=1 hit_count=0 hits=[]
```

The fresh five-sample CPU admission check was below the 97% ceiling:
`49.784, 60.487, 54.396, 64.913, 84.972`; average `62.910`, maximum
`84.972`.

## Verification

- `build_gate_hardening.py`: PASS, no failures.
- `validate_build_guardrails.py`: PASS, zero findings.
- `validate_spec_doc.py`: PASS.
- `validate_symbol_scope.py`: `BASKET_OK`, zero violations.
- Targeted static suite: 3 PASS, 2 expected binding failures. The failures are
  limited to `build_hash: pending` and the deliberately stale pre-repair build
  receipt; neither can be refreshed without a new EX5.
- `execution_contract_lint.py --ea-id 34008`: fail-closed `contract_missing`.
  This work did not invent an execution-contract registry record.

## Governed compile outcome

No compile work was enqueued. The first request used the claimed router-task ID
and was refused `BUILD_TASK_BINDING_NOT_FOUND`; router tasks are not canonical
`tasks.kind=build_ea` rows. A canonical open build task was then created through
`farmctl build-ea`.

The exact repair-successor request for failed predecessor
`1c77fcf2-39ef-47f6-a448-5dd1457bce03` authenticated that new build task but
refused:

```text
eligible=false
reason=PREDECESSOR_BUILD_TASK_REBIND_FORBIDDEN
old_mq5_sha256=7203979e4a508dee2a5e041c57538e29b8bb107dbdf0cf0d53b0d76c977266ae
current_mq5_sha256=01f91ecdd747d2dab9df8b829d42febfa9979dc8051507a90cd3da8c36cae715
successor_work_item_id=null
```

The predecessor is permanently bound to exhausted build task
`c97b5cdc-8d55-404e-9ec0-47496d1a75f6`. There is no hash-bound repair authority
for QM5_34008 in `compile_fail_repair_authorities.v1.json`. Direct MetaEditor
compilation would bypass the live-factory provenance gate and was not attempted.
Without a fresh EX5/build identity, smoke and Q02 admission were correctly
skipped.
