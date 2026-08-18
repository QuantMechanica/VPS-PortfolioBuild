# QM5_10008 GBPUSD Q02 infrastructure repair at CPU ceiling

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `REPAIRED_COMPILED_Q02_NOT_ENQUEUED_CPU_CEILING`

## Scope and farm claim

This unit repairs only the approved structural `QM5_10008_ff-sd-first-touch-h1`
EA and its `GBPUSD.DWX` H1 Q02 preset. The farm claim is
`32f4b9dc-4ed6-4e2c-98d5-966ca261a3d9`, backed up before mutation at:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10008_gbpusd_q02_claim_20260818T024555Z.sqlite`

The immutable source row is Q02 work item
`0f647bf2-23d3-4ce4-83e1-4c615a1feb39`. It ended `INFRA_FAIL` on
2026-06-22 with `DETERMINISTIC_NO_SUMMARY`, no evidence artifact, and no
MQ5/EX5/setfile hash binding. There was no pending or active GBPUSD Q02/Q03
row, no GBPUSD higher-phase row, and no other active farm owner when the claim
was inserted.

The card is G0-approved, R1-R4 PASS in its governing frontmatter, deterministic,
non-ML, and price-only. It estimates roughly 40 trades per year per symbol.
The current EA identity already produced Q02 PASS evidence on EURUSD and USDJPY,
so recovering the never-adjudicated GBPUSD arm adds FX funnel breadth without
creating another EA.

## Diagnosis and minimal repair

The pre-repair strict checker raised
`BUILD_CHECK_DWX_ADVISORY_DWX_SPREAD_FAILCLOSED`. The EA rejected
`ask == bid` in `Strategy_NoTradeFilter`, while Darwinex `.DWX` Model-4
history can legitimately model zero spread. That gate can suppress every entry
before the approved supply/demand mechanic is evaluated.

The source now rejects only invalid prices, an invalid point size, or a crossed
quote (`ask < bid`). No base-zone, impulse, freshness, entry, stop, target,
time-stop, sizing, or position-lifecycle rule changed.

The GBPUSD backtest setfile was also an obsolete generic stub: it used filter
keys not declared by this EA, left `build_hash: pending`, omitted `qm_ea_id`,
and omitted every strategy input. The repaired preset now explicitly seals:

- `qm_ea_id=10008`, slot 1 / registered magic `100080001`;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- both current news axes and the legacy mode OFF, because the approved baseline
  defines no event dependency;
- the exact card defaults for ATR, 2-6 bar bases, 1.5 ATR impulse, two
  directional closes, 0.15 ATR stop buffer, 2R target, 20-bar pending expiry,
  30-bar trade time stop, and 72-bar lookback.

The other three symbol presets were not changed.

## Static and compile evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Pre-repair strict check | PASS with one zero-spread advisory | `D:\QM\reports\framework\21\build_check_20260818_024652.json` |
| Targeted MetaEditor compile | PASS, 0 errors / 0 warnings, `SINGLE_SYMBOL_OK` | `framework/build/compile/20260818_024943/QM5_10008_ff-sd-first-touch-h1.compile.log` |
| Final strict build check | PASS, 0 failures / 0 warnings | `D:\QM\reports\framework\21\build_check_20260818_025014.json` |

Artifact hashes after the final compile:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `705560e4481b053fbd64cabd11b6ca8f632c8b60d1c3505dce54bb08c1187c91` |
| EX5 | `a9f9e22e97a62f787f062100718c120d55ba5f21b0308911d5df3b03175ded49` |
| GBPUSD RISK_FIXED setfile | `2b4a3e9ad0a13b00b7e1020e05a57b5b2ef18191e8292f69c23cb12da24b67ca` |
| Compile log | `2cc355e8ce32dc811fa28f6da8a38f665c46ed519c89f9e0060d543046cff38a` |
| Final build-check report | `f039464e07e1e5e629e7b44ebd2c0ade332f694f408d9c80aeedd867765701ba` |

No smoke, manual tester, phase runner, or backtest was launched.

## Binding CPU stop

At `2026-08-18T02:51:28Z`, five one-second host samples averaged 99.8% CPU and
peaked at 100%. Factory terminals were running from the exact T1, T3, T4, T6,
and T8 roots; the farm DB recorded six active phase rows across T1, T2, T3,
T4, T6, and T8. This is the mission's binding backtest CPU ceiling.

Per the explicit stop condition, no append-only Q02 successor was inserted and
no dispatch action followed the sample. The next below-ceiling paced worker may
append exactly one hash-bound GBPUSD Q02 successor to source row
`0f647bf2-23d3-4ce4-83e1-4c615a1feb39` after rechecking that no GBPUSD row is
pending/active and the artifact hashes above remain current.

## Safety boundary

No `T_Live` path, AutoTrading setting, live/demo/shadow/stress/optimization
preset, portfolio gate, deploy manifest, T_Live manifest, terminal process,
or historical work-item verdict was changed. The repair is not a profitability,
Q02, certification, decorrelation, or portfolio-admission claim.
