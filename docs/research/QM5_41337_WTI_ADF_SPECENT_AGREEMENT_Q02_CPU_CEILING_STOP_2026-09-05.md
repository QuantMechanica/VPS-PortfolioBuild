# QM5_41337 WTI ADF-Spectral-Entropy Agreement — Q02 CPU-Ceiling Stop

**Date:** 2026-09-05  
**Branch:** `agents/board-advisor`  
**Outcome:** one new, non-duplicate commodity edge was carded, source-built,
strict-compiled, and committed. The final Q01-smoke/Q02 admission stopped at the
binding host CPU ceiling; no smoke or Q02 work item was launched.

## Edge delivered

`QM5_41337_wti-adf-specent-agree-tr` is a direct `XTIUSD.DWX` D1 energy sleeve.
Once per broker month it reconstructs 60 completed monthly WTI log closes. It
trades the newest 12-month return direction only when both independent state
tests pass:

- lag-one, intercept-only ADF t statistic is inclusively at least `-2.594`;
- normalized spectral entropy of the newest 48 demeaned monthly log returns is
  inclusively at most `0.88`, using the exact length-48 DFT, bins 1..24,
  doubled paired-bin power, and undoubled Nyquist power.

The conjunction differs from the existing single-ADF, single-spectral-entropy,
Phillips-Perron, and ADF-KPSS EAs. Deterministic fixtures cover both one-gate
disagreement directions. The sole set is fixed at `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, with an ATR(20) x 3.5 frozen stop,
monthly attempt state, and next-month exit.

## Durable repository evidence

- source approval and reproducible source packet: `faea4503f7`;
- approved card, independent fixtures, and G0 decision: `a4c2bc075a`;
- governed EA/magic allocation: `b4f19bc76b`;
- MQ5, SPEC, oracle tests, and fixed-risk set: `5ee89fa949`;
- compiled EX5, generator-bound set, and compile-release receipts: `b8e4fa9fe6`.

Preallocation dedup covered 4,817 EA-registry rows and 1,436 cards and found no
exact strategy identity. The external Wiki root was unavailable and is disclosed
in the dedup artifact; four expected fuzzy neighbors were manually resolved as
non-equivalent mechanics.

Verification before compile:

```text
python -m unittest .../test_wti_adf_specent_agree_tr_reference.py
Ran 8 tests — OK

python framework/scripts/validate_spec_doc.py \
  framework/EAs/QM5_41337_wti-adf-specent-agree-tr
PASS (1/1)

python framework/scripts/skill_card_schema_lint.py --card ...
status=ok; ml_hits=[]; missing_sections=[]
```

## Governed compile result

The direct strict compile first refused safely because live factory terminals
were running (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`). No process was stopped or
bypassed. The source-fresh governed compile row was released only after a fresh
five-sample CPU window remained below 97% (average `72.0897%`, maximum
`80.3016%`).

- compile work item: `dc2db235-f889-411a-8775-db523fcf00c6`;
- terminal claim: `T6`;
- status/verdict: `done / COMPILE_OK`;
- strict compile: 0 errors, 0 warnings;
- build check: `PASS`;
- generated setfile count: 1;
- EX5 SHA-256:
  `C3A0EEBA9A9D2DA2DDA593CB39B79EE18FF714C128BF384EA14BE7D0ACD8361A`;
- compile evidence:
  `D:/QM/reports/work_items/dc2db235-f889-411a-8775-db523fcf00c6/QM5_41337/COMPILE_EA/compile_evidence.json`.

A build-lifecycle task was created for the exact approved runtime card:
`dd86d2aa-67b2-4e9b-afe4-3484fa33675a`. It remains pending because the next
required action was the bounded Model-4 Q01 smoke.

## Binding CPU stop

Immediately before that smoke, at `2026-09-04T22:41:47.4926813Z`, the fresh
five-sample total-CPU series was:

```text
99.5382, 99.9513, 95.6071, 94.2387, 97.7547 percent
average = 97.4180 percent
maximum = 99.9513 percent
binding ceiling = 97 percent
```

Both the average and maximum violated the strict-below-97% admission rule. The
conditional command exited with `CPU_CEILING_STOP` before invoking
`run_smoke.ps1`. Therefore no tester run, Q01 smoke verdict, build-result
transition, or Q02 work item was created. A post-stop census shows only the
completed `COMPILE_EA` row for `QM5_41337`.

## Safe continuation boundary

On a later paced wake, reuse build task
`dd86d2aa-67b2-4e9b-afe4-3484fa33675a`; do not create another build task or
compile row. Take a fresh five-sample CPU window. Only if both average and
maximum are strictly below 97% may the bounded Model-4 D1 smoke run. Then record
the hash-bound clean build result so the canonical auto-Q02 path creates exactly
one `XTIUSD.DWX / D1` Q02 work item from the fixed-risk set.

No portfolio gate, `T_Live` manifest, live setfile, AutoTrading setting, or live
deployment state was touched.
