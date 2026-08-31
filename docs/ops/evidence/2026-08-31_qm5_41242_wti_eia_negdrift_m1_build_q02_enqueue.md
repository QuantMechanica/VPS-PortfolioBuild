# QM5_41242 WTI EIA Negative Drift M1 Build And Q02 Enqueue

Date: 2026-08-31  
Branch: `agents/board-advisor`  
Outcome: `COMPILE_OK_Q02_PENDING`

## Diversity choice and authority

`QM5_41242_wti-eia-negdrift-m1` was the highest-priority untouched approved
card found in the build backlog after excluding EAs with existing build or
compile work. It adds WTI event-reaction exposure beyond the certified
index/metal/energy concentration and is a low-frequency structural rule, not
an indicator or ML variant.

- Approved card:
  `strategy-seeds/cards/approved/QM5_41242_wti-eia-negdrift-m1_card.md`
- Source: Armstrong, Cardella, and Sabah (2021), *Journal of Financial
  Economics* 140(3), 916–940, DOI `10.1016/j.jfineco.2021.02.002`, plus the
  official EIA WPSR schedule.
- Build task: `de47b55a-6801-4eb1-be77-f74ddd5fd405`, claimed by
  `codex:agents/board-advisor` before compile enrollment.
- Identity: EA ID `41242`, exact active slot-0 magic `412420000`, symbol
  `XTIUSD.DWX`, timeframe `M1`.

The implementation trades one ordinary-Wednesday price proxy: a strictly
negative completed 10:30 New York M1 bar permits one SELL during seconds 0–29
of 10:31. It uses a frozen `3.0 * ATR(20,M1)` hard stop, no target, and the
planned 10:35 New York exit. The New York date is consumed before fallible
gates, so a failed or blocked attempt cannot retry.

## Q01 repair and deterministic verification

The pre-existing prose `SPEC.md` failed the canonical seven-section Q01 schema.
It was converted to the required template without changing the strategy. The
single-symbol scope validator also identified a literal `SymbolSelect` call;
the EA now verifies the exact host first and selects `_Symbol`, preserving the
card lock while eliminating the false foreign-symbol leak.

Verification results:

- approved-card schema lint: PASS;
- G0 card lint: PASS;
- EA registry/magic prerequisite guard: PASS;
- canonical SPEC validation: PASS, 1/1;
- build guardrails: PASS, zero findings;
- single-symbol validator: `SINGLE_SYMBOL_OK`, zero violations;
- local mechanical reference suite: PASS, 16/16;
- banned ML/external-runtime/raw-indicator scan: no hits;
- governed strict build check: PASS, 0 errors, 0 warnings.

## Governed compile receipt

The compile was enrolled with the exact open build-task binding and released
only after the source-hash-bound dry run matched. The resident worker compiled
it on its claimed quiescent slot; no terminal was started or stopped manually.

- COMPILE_EA work item: `5f952c62-7486-4633-92f3-a7af2ca76f2f`
- Verdict: `COMPILE_OK`
- Evidence:
  `D:\QM\reports\work_items\5f952c62-7486-4633-92f3-a7af2ca76f2f\QM5_41242\COMPILE_EA\compile_evidence.json`
- MQ5 SHA-256:
  `a34b7fad09ac90076d5aacf3c749da3043da0dd87371039c75eb3a6a0b1b7417`
- EX5 SHA-256:
  `7af4ac433eab6e0c4ea16a0a808363eec4a2bfb5b3c7fd5120be3e4addad7388`
- Final setfile SHA-256:
  `883ec9b65e4cb5a6957f0deac419319d4f59734877ed49600070a5dc012d6c49`
- SPEC SHA-256:
  `64336d821afd3f36aad0e13e95d934e4cbdc6558626d8f90d13e05e9ff256539`

The only preset is
`QM5_41242_wti-eia-negdrift-m1_XTIUSD.DWX_M1_backtest.set`, with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Smoke capacity and CPU boundary

Exactly one non-iterative Q01 smoke attempt was made through
`run_smoke.ps1 -Terminal any -SmokeMode`. The resolver returned
`status=no_capacity` before launch; no tester run or smoke report was created.
The build result records `deferred_p2_smoke` with the measured process evidence
`terminal64=4`, `metatester64=2`.

Fresh five-sample whole-host checks never reached the OWNER stop ceiling:

| Boundary | Samples (%) | Max (%) | Ceiling (%) |
|---|---|---:|---:|
| pre-compile enrollment | 88.29, 86.28, 81.45, 89.85, 86.82 | 89.85 | 97.00 |
| post-compile / pre-smoke | 51.12, 57.53, 64.75, 82.92, 75.89 | 82.92 | 97.00 |
| pre-Q02 record | 70.65, 75.93, 74.81, 70.92, 69.06 | 75.93 | 97.00 |

## Q02 handoff

Recording the build created exactly one idempotent Q02 work item:

- work item: `e8f40ff0-b0db-41a1-a35c-1c65c0870cde`;
- tuple: `QM5_41242 × XTIUSD.DWX × M1 × Q02`;
- status at handoff: `pending`, unclaimed, attempt count 0;
- custom-history archive admission: `ACTIVE`, 108 selected rows;
- enqueue path: `record_build_result.auto_q02`;
- Q02 fanout cohort size: 1, as required by the approved single-symbol card.

No Q02 verdict, profitability claim, decorrelation claim, optimization,
portfolio-gate change, deploy action, `T_Live` access, or AutoTrading change was
performed by this unit.
