# QM5_10069 NZDUSD Q02 infrastructure recovery — CPU ceiling stop

## Outcome

No backtest or compile work was enqueued. The governed recovery target is ready,
but the binding paced-fleet CPU stop fired before the append-only Q02 mutation.

- Coordination task: `374ba9a6-478d-4df3-9881-4c99d143f967`
- EA: `QM5_10069_mql5-hs-rev`
- Target: `NZDUSD.DWX`, H1
- Preserved infrastructure row: `727fd995-bf25-4943-bf14-422f59adab65`
- Failure: `ONINIT_FAILED;INCOMPLETE_RUNS` on the stale pre-repair binary
- Recovery compile: `7deba014-7ca5-4e79-bd20-789bad639b69`, `COMPILE_OK`

## Why this was the nonduplicate target

The approved-card build backlog has no unbuilt candidate. The stronger-looking
market-neutral candidates cannot advance the funnel: `QM5_13106` AUDUSD/EURGBP
already has Q02 PASS, Q03 PASS, and Q04 FAIL; `QM5_21518` WTI/Brent is retired
because its required `XBRUSD.DWX` leg is unavailable. The current
`QM5_10069` repair task only requalified USDCHF. NZDUSD therefore remains a
distinct approved FX sleeve with infrastructure-only evidence after the old
binary, not a duplicate of that USDCHF run.

The approved card cites Israel Pelumi Abioye's MQL5 head-and-shoulders article
and defines fixed, non-ML H1 market-structure rules. `NZDUSD.DWX` is explicitly
in the approved target universe.

## Identity and controls

- MQ5 SHA-256: `d6243b426c4290aae893cc64088aecc9cca6cbf696abfe8792859588a60ba77c`
- EX5 SHA-256: `4f474930fa4c53657df8252416dc55efa7f3bc974ca706d63faacd54b1db7c55`
- Setfile SHA-256: `9e52a5bfafe2585eb86f86c8f6bc8446596d45e79dacaefbf0ab53a975da3dd1`
- Setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Setfile magic slot: `7`
- EA directory was clean relative to Git at inspection.

The required source pin audit was run before any possible queue mutation:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_10069_mql5-hs-rev/QM5_10069_mql5-hs-rev.mq5"
exit_code=0
ok=true
predicate=EA_FRAMEWORK_INPUT_PINNED
hit_count=0
hits=[]
```

No MQ5 source was written in this unit and no compile enqueue was attempted.

## Binding CPU stop

Five read-only `Win32_Processor.LoadPercentage` samples were taken immediately
before the intended Q02 enqueue:

```text
samples=[99,94,88,99,94]
max=99
ceiling=97
```

The maximum exceeded the 97% ceiling. `farmctl mt5-slots` simultaneously showed
five running factory terminals (`T1`, `T5`, `T7`, `T9`, `T10`) plus existing
reservations. In accordance with the mission, the append-only rerun was not
created and no dispatch or manual tester run was invoked.

## Safe handoff

When capacity is below the ceiling, recheck that the current EX5 still hashes to
`4f474930fa4c53657df8252416dc55efa7f3bc974ca706d63faacd54b1db7c55`,
rerun the source pin audit, confirm no open NZDUSD Q02 successor exists, and use
the canonical exact-row append-only Q02 path against
`727fd995-bf25-4943-bf14-422f59adab65`. Do not mutate the preserved row.

No `T_Live` path, AutoTrading setting, portfolio gate, or deploy manifest was
read-write touched.
