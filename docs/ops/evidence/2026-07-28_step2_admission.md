# Step-2 admission: QM5_10145 satellite fidelity

Date: 2026-07-28  
Router task: `b4eb6cff-79c2-4fd3-8eed-19f8681096bd`

## Verdict

**STOP AT GATE.** The runner gate remains PASS, but the satellite gate is a
decisive FAIL. The joint 10145 sleeve is not the standalone QM5_10145 strategy:
it trades more often, one second later, and with materially different stops and
position sizes.

| Gate | Required | Result |
|---|---:|---:|
| Runner invariance | fresh standalone 9936 = joint runner, subject only to individually logged account-level kill-switch exceptions | **PASS: 1,143 / 1,143 exact; no exception needed in this rerun** |
| Satellite fidelity | fresh standalone 10145 = joint magic 201810001 | **FAIL: 0 / max(425, 291) exact; match rate 0.000000** |

No three-sleeve run is admitted by this result.

## Governed standalone control

QM5_10145 was compiled from the current canonical tree through
`framework/scripts/compile_one.ps1`:

- compile: 0 errors, 0 warnings;
- MQ5 SHA-256:
  `fa6b13d47e4c3a34a9456c6ec57899c483e06dca0a593d6a44dfa59860f72d19`;
- immutable staged EX5:
  `D:/QM/strategy_farm/artifacts/ex5_staging/step2_admission_10145_fresh/QM5_10145_tsm-meanret.ex5`;
- staged EX5 SHA-256:
  `849545a5b8ceba41bbe9bc576dd130efcc381e324d10802029a8e65219472764`;
- base XAUUSD set SHA-256:
  `0acbbeb78f4093f556b1e061f5fba94b25b3025dbf267f2dc13939ed8e2abb0`;
- set risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- governed Q02 work item:
  `d1907cea-cb85-49fd-a228-ac8d6000c031`;
- terminal/window/model: T7, 2018-07-02 through 2025-12-31, Model 4;
- result: PASS, 537,721,146 real ticks, 1,931 D1 bars, 12m14s;
- durable summary:
  `D:/QM/reports/work_items/d1907cea-cb85-49fd-a228-ac8d6000c031/QM5_10145/20260728_191540/summary.json`.

The staged EX5 SHA was verified before and after the run. The news seed was OK
at age 15 hours, below the unchanged 336-hour fail-closed ceiling.

The first governed attempt failed before testing because T7 inherited a 20.46
GB tester-agent journal from the preceding XAUUSD log-bomb run. Its failed
summary is retained at
`D:/QM/reports/work_items/d1907cea-cb85-49fd-a228-ac8d6000c031/QM5_10145/20260728_190729/summary.json`.
The same work item was requeued without changing the binary, set, model, or
window; the next governed agent completed normally.

## Frozen operands and exact comparator

The ownership-fix joint rerun is work item
`f0a3c02e-c1b1-42ec-9675-b1e600d15f78`, PASS on T4. Its staged EX5 SHA is
`806e53c1fe94bc2cbae3ddc8de66a3add985c7ef443e0a6ab9f226083778a7cb`.
The q08 ownership fix harvested 425 closed XAUUSD trades for magic 201810001.

Task-scoped operands:

- joint satellite:
  `D:/QM/strategy_farm/artifacts/step2_admission_d1907cea/20181_magic_201810001_XAUUSD_DWX.jsonl`
  (425 rows; SHA-256
  `e85c7d750579d526942fdcc910582adcd6aea69b394bb0bf6d38955612372e78`);
- fresh standalone:
  `D:/QM/strategy_farm/artifacts/step2_admission_d1907cea/10145_XAUUSD_DWX_fresh.jsonl`
  (291 rows; SHA-256
  `8cb0ae89e16125ee6ab22d989687b52b011181c9da519dfe91c29eb5c3044c46`).

`tools/strategy_farm/compare_joint_replay.py` reported:

```json
{
  "joint_trades": 425,
  "gated_trades": 291,
  "matched": 0,
  "unmatched_joint": 425,
  "unmatched_gated": 291,
  "match_rate": 0.0,
  "mismatch_categories": {
    "exact": 0,
    "same_entry_same_volume_shifted_exit": 0,
    "different_entry": 291,
    "extra": 134,
    "missing": 0
  }
}
```

An extended nearest-entry decomposition (±2 seconds) found:

- 283 aligned entries, all with the joint entry exactly one second later;
- 142 joint entries without a nearby standalone entry;
- 8 standalone entries without a nearby joint entry;
- only 75 of the 283 aligned entries share the exact close second;
- zero aligned trades share volume within 0.005 lots;
- median joint/standalone volume ratio 4.857143 (range 1.75 to 10.0).

## Mechanisms

### Wrong timeframe in the joint ATR stop

The standalone is a D1 EA. Its `Strategy_EntrySignal` calls `QM_StopATR` from a
D1 chart. The joint implementation calls the same helper at
`QM5_20181_ftmo-joint-multisym-timer.mq5:442`, but the joint chart is
USDJPY/H1. `QM_StopATR` calls `QM_StopRulesReadATRValue`, which reads
`QM_ATR(symbol, PERIOD_CURRENT, ...)` at
`framework/include/QM/QM_StopRules.mqh:67`.

Therefore the joint XAUUSD sleeve sizes from an H1 ATR while standalone 10145
sizes from a D1 ATR. This directly explains the materially tighter joint stops
and larger lots (for example, the first aligned trade is 1.46 lots joint versus
0.30 standalone). This is an implementation defect, not account-level
portfolio interaction.

### Entry clock differs

All 283 alignable entries are one second later in the joint stream. The joint
uses `EventSetTimer(1)` and dispatches the non-host sleeve from `OnTimer`
(`QM5_20181...mq5:368,668-689`); standalone enters on its first XAUUSD tick.
The exact-second gate therefore fails independently of sizing.

### News contract differs

Standalone uses `qm_news_temporal=3` and `qm_news_compliance=1`. The joint call
at `QM5_20181...mq5:454` routes through `QM_BasketOpenPosition` with only the
legacy news mode, so it does not reproduce standalone's FW1 two-axis news
filter. The 142 joint-only versus 8 standalone-only nearby entries show that
entry-set divergence is real in the fresh measurement; the earlier assertion
that this difference was empirically inert is no longer supportable.

### Why 425 closed rows versus the prior 149 accepted-order count

The current logger records 426 `BASKET_ORDER_ACCEPTED` and 35 market-closed
rejections; q08 records 425 closed satellite trades. The prior run recorded 149
accepted and 34 market-closed events. Market-closed handling was not repaired:
the source still advances `last_closed_bar` before attempting the order, and
the rejection count is effectively unchanged (34 to 35). The ownership commit
changed targeted magic/symbol registration and added disabled slot 2; its diff
did not change `QM20181_Run10145` entry mechanics.

Consequently the 149-to-426 acceptance jump is **not attributable to a
deployability or market-closed fix from the source diff**. It is a real
cross-run divergence whose causal mechanism is not established by the
available artifacts. It does not rescue admission: both the fresh operand
comparison and the source-level ATR/news defects independently fail the gate.

## Admission decision

Step 2 is rejected. Before any new admission measurement, the joint sleeve
must explicitly read XAUUSD/D1 ATR, reproduce the standalone FW1 news contract,
and define an OWNER-approved timing equivalence if exact tick time is no longer
the intended gate. Any repair then requires another same-vintage governed
joint/standalone pair. No strategy mechanics, fail-closed news ceiling,
AutoTrading, T_Live, or terminal configuration were weakened here.
