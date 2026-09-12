# QM5_41180 XTI/XNG market-neutral build and Q02 handoff

Date: 2026-09-12 UTC

Branch: `agents/board-advisor`

Router build task: `3882cc71-0697-4d6e-861d-4f3a14febf0f`

Approved card:
`strategy-seeds/cards/approved/QM5_41180_xtixng-mspearman-rv_card.md`

## Selection and scope

`QM5_41180_xtixng-mspearman-rv` was the highest-diversity collision-free
approved build candidate found in the farm database: a D1, approximately
5--8-package-per-year, two-leg XTI/XNG relative-value strategy. Both registry
rows are active (`411800000` for XTI slot 0 and `411800001` for XNG slot 1),
both `.DWX` symbols are canonical, no EX5 existed, and the EA had no prior
farm work item when claimed. This advances an energy-spread/market-neutral
mechanic rather than adding another standalone index, metal, or XNG sleeve.

The implementation remains card-faithful: thirteen synchronized completed
month ends, strict Spearman ranks, inclusive integer score threshold 104,
contrarian XTI/XNG sides, a single aggregate fixed-risk budget, equal target
notionals within the 20% mismatch cap, frozen ATR stops, and later-month or
40-day stale exit. The approved sources are EIA Villar/Joutz, Ramberg and
Parsons in *The Energy Journal*, Spearman (1904), and pinned R Core behavior.

## PACER build-guard remediation

The inherited uncompiled source failed the mandatory framework-input-pin
audit with eight findings: equality checks for `qm_rng_seed`, five
`qm_news_*` controls, and two `qm_friday_close_*` controls. Compile was not
enqueued while those findings existed.

The locked-configuration predicate now checks only registered identity,
`strategy_*` parameters, and fixed-risk mode. It no longer compares RNG,
news, Friday-close, or portfolio-weight controls. The stress rejection input
is accepted only when finite and in the inclusive `[0,1]` range. Broker
symbols are resolved from the host chart and registered companion input;
the only remaining broker-symbol literal is the permitted companion input
default.

The required post-write, pre-enqueue audit was then run against the absolute
MQ5 path and returned:

```json
{"ok":true,"predicate":"EA_FRAMEWORK_INPUT_PINNED","source_count":1,"hit_count":0,"hits":[]}
```

No compile command ran before that PASS.

## Build and review evidence

- Governed compile work item:
  `ffd68a3b-fbd4-480d-8f59-4dc4a6e35976`.
- Compile result: `COMPILE_OK`, zero errors, zero warnings.
- Framework build check: `PASS` with zero failures (three non-blocking
  card-location warnings because the card of record is in `strategy-seeds`).
- MQ5 SHA-256:
  `225d8abfa334e7840c62e4d3f256c6b5899f6ea19d39f0e7ec23713d597e7d66`.
- EX5 SHA-256:
  `298dec7694bb17b39d12c604d45aba54acae7974b206148ba2aa173522ebc5a1`.
- Compile evidence:
  `D:/QM/reports/work_items/ffd68a3b-fbd4-480d-8f59-4dc4a6e35976/QM5_41180/COMPILE_EA/compile_evidence.json`.
- `validate_build_guardrails.py`: PASS, zero findings.
- `validate_spec_doc.py`: PASS.
- Focused reference suite: 8 passed.
- Post-compile framework-input-pin audit: PASS, zero findings.
- Generated setfiles: three; all use `RISK_FIXED=1000` and
  `RISK_PERCENT=0`. The basket manifest names XTI as host and both XTI/XNG as
  traded symbols.

Review found no blocking card-fidelity, registry, magic, risk-mode, framework,
compile, or documentation defect. The single logical basket setfile is the
only valid Q02 carrier; neither physical leg is a standalone strategy row.
The accepted `review_ea` task is
`d173cce4-dc74-43e3-b015-5b0a4e70d738`.

## Q02 capacity and admission

Five fresh one-second whole-host CPU samples taken immediately before
admission were `80.4823%`, `72.4217%`, `63.7759%`, `66.3298%`, and
`84.6747%`. The average was `73.5369%` and the maximum was `84.6747%`, so
neither reached the binding 97% ceiling.

The governed first-Q02 intake appended exactly one pending D1 work item:

- Work item: `f2d55a4f-5e4f-4387-b407-3b18f5a19849`.
- Logical symbol: `QM5_41180_XTI_XNG_MSPEARMAN_RV_D1`.
- Setfile SHA-256:
  `436e0b9a1dece577be31d666414601bdf8758a361e60de7ffc663594678fd41e`.
- EX5 SHA-256:
  `298dec7694bb17b39d12c604d45aba54acae7974b206148ba2aa173522ebc5a1`.
- Receipt:
  `D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/ffd68a3b-fbd4-480d-8f59-4dc4a6e35976_f2d55a4f-5e4f-4387-b407-3b18f5a19849.json`.
- Receipt SHA-256:
  `b8cfdf2f8f6bd947989b0d209ba8ce5906be097c17813d9888523fc9257f4fee`.

No physical-leg Q02 rows were appended. The Q02 item was left pending for the
normal terminal-worker path; no dispatcher tick or tester launch was issued
by this build task.

## Safety boundary

No manual tester or backtest was started. No portfolio gate, admission state,
live/demo/shadow/stress artifact, or deployment manifest was changed.
AutoTrading and `T_Live` were not touched.
