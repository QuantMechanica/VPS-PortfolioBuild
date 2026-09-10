# QM5_9406 first-Q02 binary recovery

- Recorded at: 2026-09-10 UTC
- Branch: `agents/board-advisor`
- EA: `QM5_9406_qs-daily-mac`
- Farm task: `7fa67295-4b30-4c27-beba-970983acb74b` (`infra_repair`, active)
- Compile successor: `11be44a2-33f5-49f9-af41-8efba6f10151`
- Scope: diversity-first, low-frequency D1 funnel recovery; no strategy change

## Selection

The approved build backlog had no claimable unbuilt forex, crypto, rates, or
new-energy card with complete deterministic prerequisites. `QM5_9406` is a
reviewed D1 structural trend EA with seven active FX symbols among its
13-symbol universe and had never reached Q02. It was therefore selected as the
highest-value non-duplicate diversity funnel gap after excluding EAs already
claimed by other paced agents.

## Diagnosis

The current MQ5 SHA-256 is
`23bc76a30cadb074ca66c66ffcd9a5602222cd1649232a433ed29510d0c4c5cf`.
The latest current-source COMPILE_OK receipt is work item
`28aa59c6-9664-402c-8e9a-f3571b1ea8fc`, which records EX5 SHA-256
`5cb131e4ea12a03e4f09472e3e59243e754ad8d37f5021fdbf23e8e996d56f12`.
The canonical EX5 instead had SHA-256
`d88740fed1952b737134010f86f8fcba65e2ce5252f9b4ed6b1502c58f3e97bf`,
the binary emitted by older failed compile work item
`92aa4297-9869-4f48-a888-b768d0c168c1`. Consequently, first-Q02 intake failed
closed with `compile_ex5_sha256_mismatch` even though the reviewed source and
13 fixed-risk setfiles remained present.

## Repair contract and enqueue

`compile_work_items.py` now recognizes exactly one append-only recovery
authority:

`router_first_q02_binary_repair:7fa67295-4b30-4c27-beba-970983acb74b:QM5_9406`

The authority is bound to EA ID 9406, the exact label, the current source hash,
the exact reviewed COMPILE_OK predecessor, its recorded binary hash, and the
absence of any prior Q02 row. It does not waive strategy, backtest, or gate
verdict requirements and cannot authorize another EA. The isolated regression
fixture also verifies the append-only successor path and wrong-authority
refusal.

Before enqueue, the binding PACER audit returned:

```json
{
  "ok": true,
  "predicate": "EA_FRAMEWORK_INPUT_PINNED",
  "source_count": 1,
  "hit_count": 0,
  "hits": []
}
```

The exact compile successor was enqueued through `farmctl enqueue-compile` with
`RISK_FIXED=1000.0` and `RISK_PERCENT=0.0`. It is pending under the standard
`COMPILE_EA_WORKER_ROLLOUT_PENDING` activation hold; no duplicate enqueue was
made. After the reviewed worker rollout releases this exact hold and records a
source-matched COMPILE_OK binary, the next governed action is
`intake-first-q02` for one FX canary.

## Verification and safety

- `python -m pytest tools/strategy_farm/tests/test_compile_work_items.py -q`:
  `86 passed`
- Fresh pre-enqueue CPU sample: average 72.77%, maximum 87.12%; the 97% ceiling
  was not hit.
- Farm DB rollback anchor:
  `D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260910T065318Z_b032eb58.sqlite`
  (SHA-256 `7e5992850debaedbe37ba93bd654cb4d9eb6c22ad0f631cea718b4e715e9101a`)
- AutoTrading, T_Live, the portfolio gate, and the T_Live manifest were not
  changed.
