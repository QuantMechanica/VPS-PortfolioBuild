# QM5_41005 D1 compile-infrastructure repair

Date: 2026-09-12

Branch: `agents/board-advisor`

EA: `QM5_41005_richard-donchian-50day-cta-benchmark`

Scope: paced-fleet priority 2; structural D1 Donchian CTA; compile and Q02
requalification preparation only

## Collision-free claim and source authority

- Farm agent task: `30ceeacd-0647-485a-9886-725af2139d61`
- Failed Q02 predecessor: `1ff79936-5ae0-4abb-8658-17a03dfc1a23`
- Predecessor verdict: `INFRA_FAIL`, `compile_gate:COMPILE_FAILED`
- Exact authority:
  `router_build_rework:30ceeacd-0647-485a-9886-725af2139d61`
- Implementation commit: `62efe816ff`

The approved card is `g0_status: APPROVED`, `r3_data_available: PASS`, and
`r4_ml_forbidden: PASS`. The active registry has four exact slots for
XTIUSD.DWX, XAUUSD.DWX, SP500.DWX, and EURUSD.DWX.

## Diagnosis and repair

The historical Q02 predecessor did not launch MT5. Its durable compile result
was `INCLUDE_MIRROR_REFUSED`, `errors=-1`, because the legacy dispatch path had
no governed terminal/include-mirror claim.

The first governed compile row, `787af7b7-d5cc-4b70-bee6-6f984674034b`, then
exposed a separate deterministic build-contract defect before MetaEditor:

```text
SETFILE_DECLARED_STRATEGY_PARAMS_MISSING
```

The EA still named its eight strategy inputs with the legacy `Inp*` convention.
They were mechanically renamed into the required `strategy_*` namespace in the
MQ5, SPEC, focused contract test, and all four D1 backtest setfiles. Defaults,
ranges, signal rules, risk rules, symbol universe, and strategy mechanics were
not changed. Each regenerated backtest set retains `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

Current MQ5 SHA-256:
`83603471fb631b4ba8114d4136881b363f4f6826f0bd31bbee6954b8f356992a`

The tracked EX5 remains the deliberately stale predecessor binary:
`12e35b8185adb912bc6023947a5cea20c5c7a540e16542669c924d1aa0b585d6`.
It is not claimed as evidence for the repaired source.

## Validation

The binding PACER audit was run after the MQ5 edit and immediately before every
enqueue attempt. Its final result was:

```json
{"ok":true,"predicate":"EA_FRAMEWORK_INPUT_PINNED","source_count":1,"hit_count":0,"hits":[]}
```

Other scoped checks:

- four `gen_setfile.ps1` invocations: PASS
- focused EA and exact-authority tests: 8 passed
- `build_gate_hardening.py`: zero failures and warnings
- `validate_build_guardrails.py`: PASS, five files, no findings
- `validate_spec_doc.py`: PASS
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`
- raw-source quarantine check: `RAW_MQ5_SOURCE_ALLOWED`
- `git diff --check`: PASS (line-ending notices only)

The ad-hoc strict build wrapper was not used to compile: it correctly returned
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` while factory terminals were running.

## Governed compile disposition

Two post-repair rows reached older resident workers and failed closed at their
candidate recheck before setfile generation or MetaEditor:

- `5beafef2-5ee5-46d1-9825-cf59c81b6c79` on T6
- `558c27f0-dacb-4da1-8f88-0177714a7928` on T10

Both recorded `SOURCE_REPAIR_AUTHORITY_INVALID`; those resident processes had
not loaded commit `62efe816ff`. No source/build failure is inferred from those
infrastructure refusals.

To avoid further retry churn, exact current-source compile row
`369c27d3-2436-448c-b43b-e69ec4487cc2` remains pending under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`. After reviewed workers load the committed
authority, release only that row, require an authenticated `COMPILE_OK` receipt
for the current MQ5/EX5 identity, and then use `requalify-q02` to append a new
Q02 successor to `1ff79936-5ae0-4abb-8658-17a03dfc1a23`.

No Q02 row was appended without that compile proof.

## Capacity and safety

Observed five-sample CPU maxima were 87.70%, 78.04%, and 82.81%; the backtest
CPU ceiling was not reached. No backtest was launched by this repair.

No T_Live file, AutoTrading state, portfolio gate, or T_Live manifest was
readied or changed. No terminal process was started, stopped, or restarted.
