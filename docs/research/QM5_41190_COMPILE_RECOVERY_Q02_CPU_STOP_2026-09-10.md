# QM5_41190 compile recovery and Q02 CPU stop

## Outcome

`QM5_41190_xtixng-mtheilsen-rv` is recovered through Q01. The append-only
compile successor `afc2d394-275f-4ec4-a381-0cdfe46a9ce1` finished
`COMPILE_OK`: MetaEditor reported zero errors and zero warnings, build-check
reported `PASS`, and the new `.ex5` SHA-256 is
`2749cbe4a069b302cc45e0288e0a58a212e1d21b3f801fa80f1f03ba35e5fe64`.

Q02 was not enqueued. The canonical `intake-first-q02` dry-run became
eligible for logical basket `QM5_41190_XTI_XNG_MTHEILSEN_RV_D1`, but the
immediately preceding five-sample admission check read `99.9%, 100%, 100%,
100%, 100%`. This hit the binding 97% CPU ceiling, so the apply command was
not run. The farm database contained no Q02 row for this EA at handoff.

## Scope and coordination

- Strategy Card: `strategy-seeds/cards/approved/QM5_41190_xtixng-mtheilsen-rv_card.md`
- G0: `APPROVED`; R3: `PASS`; timeframe: D1; expected cadence: approximately
  10-12 paired packages/year.
- Identity registry: one active `QM5_41190` / `xtixng-mtheilsen-rv` row.
- Magic registry: slot 0 `XTIUSD.DWX` / `411900000`; slot 1 `XNGUSD.DWX` /
  `411900001`.
- Pacer claim: `1a9f29d1-856e-4914-9c86-e170b535a2f0`.
- Active build binding: `ffd64966-d609-459a-8e6a-5e18b8a196c6`.
- Immutable failed predecessor: `5b6a9525-e988-4b0f-a7ec-b9f879adbb49`.
- Repair-successor source SHA-256:
  `2fb06bd4d2316de4c8f15d8db982f73d878865acc3b38bb89dc566fd6003b1e9`.
- Governed compile evidence:
  `D:/QM/reports/work_items/afc2d394-275f-4ec4-a381-0cdfe46a9ce1/QM5_41190/COMPILE_EA/compile_evidence.json`.

## Source repair

The failed compile had itself produced zero MetaEditor errors/warnings, but
build-check rejected three dynamically allocated buffers because their fixed
13- and 78-element bounds were not mechanically visible. The repair changes
those buffers to card-sized fixed arrays without changing their indexes,
ordering, estimator, signal, or lifecycle.

The same source still contained a pre-PACER locked guard. It equality-pinned
RNG, news, Friday-close, portfolio-weight, stress-default, and fixed-risk
amount inputs. The repaired guard pins only `strategy_*`, `qm_ea_id`,
`qm_magic_slot_offset`, and fixed-risk mode (`RISK_FIXED > 0`,
`RISK_PERCENT == 0`). Stress rejection is checked only for finiteness and the
inclusive `[0,1]` range. Symbols now enter through explicit runtime host and
companion strategy slots; broker symbol literals remain in setfiles, not
trading logic.

## Verification

- Reference model: 8/8 tests passed.
- `build_gate_hardening.py`: zero failures, including zero D10 buffer
  findings.
- Symbol-literal inventory: zero literals and zero findings in the EA source.
- Mandatory PACER audit was run before both compile-successor dry-run and
  apply:

  ```text
  python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:\QM\repo\framework\EAs\QM5_41190_xtixng-mtheilsen-rv\QM5_41190_xtixng-mtheilsen-rv.mq5"
  ```

  Both executions returned code 0, `ok: true`, `hit_count: 0`, and no
  `EA_FRAMEWORK_INPUT_PINNED` finding.
- All three backtest setfiles carry `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  explicit XTI/XNG runtime symbol slots. The logical-basket setfile SHA-256 is
  `500bde41673ca809b8bb663a4f992464b237ae7005782ea1ff2ce0c8ba9cb022`.
- Canonical first-Q02 dry-run: `eligible: true`, `would_enqueue: true`, no
  deferred legs.

No tester was manually dispatched. No `T_Live`, AutoTrading, portfolio gate,
deploy manifest, or live manifest was touched.

## Next safe action

After a fresh five-sample CPU check remains strictly below 97%, rerun the
canonical first-Q02 intake against compile work item
`afc2d394-275f-4ec4-a381-0cdfe46a9ce1` with `--apply`. Do not bypass the CPU
admission gate.
