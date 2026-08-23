# E4 governed rebuild wave — canary handoff

Date observed: 2026-08-23 UTC  
Authority: OWNER 2026-08-22 E4 / `OWNER-DEC-MQ5-DRIFT-LIVE`  
Router task: `1854fc66-7ff8-4138-946e-0b23695309df`  
Disposition: **REVIEW — fail-closed partial delivery**

## Outcome

The recommended canary, `QM5_13213_balke-gmt3-range-breakout`, received only the two required hardening repairs: direct first-on-tick MAE tracking and zero-initialization of both `QM_EntryRequest` values. The scoped build guardrail validator passes. A direct governed compile attempt was refused because live terminal processes make include mirroring unsafe. The EA was therefore submitted through the canonical `COMPILE_EA` queue, where the intentionally active worker-rollout hold prevents execution.

No new EX5 exists, no setfile was restamped, and no Q02 canary was enqueued. This is deliberate: without a new EX5 hash there is no current execution identity against which a canary can be adjudicated. No zero-trade result was treated as PASS. The remaining five EAs were not rebuilt.

## Source/binary classification

Hashes below are SHA-256 over the exact on-disk bytes. Timestamps are filesystem UTC observations. For unchanged rows, the MQ5 predates the current EX5 and no post-binary source edit is present. Because EX5 is opaque and these older builds have no complete source-hash binding, timestamp provenance is useful but is not represented as cryptographic proof of compiler input.

| EA / requested symbol | MQ5 hash and time | Existing EX5 hash and time | Classification and action |
|---|---|---|---|
| `QM5_10706_tv-mon-ls` / GBPUSD | `909327914d7fd65301751c38421c5dec3cddf8e96864d45c26f4db7a1f8fe27c`, 2026-08-16 22:04:20Z | `eaffda6f03c8b422896c0e9ab5ea0f3c7100f8546592353ed661f19d056b78cb`, 2026-08-21 12:10:23Z | No post-binary source drift observed. Held for post-canary Claude review; not rebuilt. |
| `QM5_10847_tv-inside-gem` / GDAXI | `7029f20d249672ddfa2861735b04a71e5645ee8f7ed7499dfb6300c4ee27b835`, 2026-07-05 13:55:49Z | `73071f44dd22f2a7394fb1ff2d981a12eafa88498c320fa12142f2af63131673`, 2026-08-17 22:00:22Z | No post-binary source drift observed. Held for post-canary Claude review; not rebuilt. |
| `QM5_12989_grimes-nested-pb-v2` / XAUUSD | `72b3fd6effeca0afac8765d6af04bc90ff1ee88af431ebef6d9a1b3031efb240`, 2026-08-05 16:30:01Z | `77d3c5fda5ef2dfd0c138e6520f76d450a04fe812fcefabac07e2673fcd2e425`, 2026-08-22 13:30:12Z | No post-binary source drift observed. Latest recorded build check still identifies `EA_INDICATOR_BUFFER_UNBOUNDED`; held for post-canary repair/review. |
| `QM5_13128_pre-fomc-drift-ndx` / NDX | `4e6e18c1967ae802aa31190b7ca75329eb451ddee88706f8f1dd546506172d25`, 2026-08-22 14:14:39Z | `59b9d1657fb04a9f33a030d420da76a1cae92c4223f4404842a53feed1848370`, 2026-08-22 14:00:23Z | **STOP / identity adjudication required.** Commit `4112f5b07` is after the binary and changes 63 lines (56 insertions, 7 deletions), including the OWNER-ratified event/news contract, entry/exit diagnostics and order-result behavior as well as hardening. The entry predicate appears intended to remain equivalent, but this is not a pure mechanical gate-only diff and must not be silently rebuilt under the existing identity. Its pre-existing compile row `3c893190-0297-4efb-b810-ad7f602ff63d` remains pending behind the rollout hold and was not released. |
| `QM5_13213_balke-gmt3-range-breakout` / USDJPY | pre-repair MQ5 `3e8344b9404a64350815ff0cea21af3f77859df2cca76dd4ef42ed3f213b6314`; repaired MQ5 `d140d313c3bbcd87ccefacfb2068bf164f9db9edfbe49ba410a83fcd4d79054f` | old/current EX5 `8d1767d600dbf616df11d4b4b9d36174d5b23fd209c7204addde3740667fea70`, 2026-08-22 12:30:09Z; new EX5: **not produced** | Hardening-only source repair. Governed compile queued and held; canary not yet eligible. |
| `QM5_1567_demark-td-reverse-sequential-h4` / EURUSD | `685af902fd614945f15df604810f52b561d6dd3c0d155166b09dde9126da0f27`, 2026-07-25 21:14:03Z | `aee0eb60798ef7ada09e49df6e9a339dd8199f810de56dab8a25957cb26fba31`, 2026-08-22 13:00:16Z | No post-binary source drift observed. Latest recorded build check identifies raw-series calls and `EA_Q08_MAE_HOOK_MISSING`; held for post-canary repair/review. |

The prior build evidence rows used for the failure classifications are:

- `QM5_1567`: `2bb466d0-bbbe-4486-9368-645a127d25af`, `COMPILE_FAIL`, `EA_FRAMEWORK_RAW_SERIES_CALL; EA_Q08_MAE_HOOK_MISSING`.
- `QM5_12989`: `7d21410b-b1cd-4e99-9543-55e8a412fca6`, `COMPILE_FAIL`, `EA_INDICATOR_BUFFER_UNBOUNDED`.
- `QM5_13213`: `0a1da4c0-a0b0-455b-963a-4c3bfc3648cc`, previously reported `EA_Q08_MAE_HOOK_MISSING; EA_TRADE_REQUEST_UNINITIALIZED`; both source defects are repaired in this handoff.

## Canary repair and compile evidence

The exact `QM5_13213` source diff is limited to:

1. `ZeroMemory(buy_req)` immediately after the local buy request declaration.
2. `QM_FrameworkTrackOpenPositionMae()` as the first statement in `OnTick()`.
3. `ZeroMemory(req)` immediately after the main entry request declaration.

Focused validation:

```text
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_13213_balke-gmt3-range-breakout
verdict: PASS
files_checked: 11
findings: []
max_news_stale_hours: 336
```

The required direct compile path was attempted with exact EA scope:

```text
python tools/strategy_farm/compile_ea.py --ea-id 13213 --json --fail-on-error
exit: 1
verdict: COMPILE_FAILED
reason_class: INCLUDE_MIRROR_REFUSED
errors: -1
warnings: -1
EX5 produced: no
```

This refusal is the required safety outcome while `terminal64` processes are alive; no process was interrupted. `build_check.ps1 -EALabel QM5_13213_balke-gmt3-range-breakout` was not run after the repair because compilation never produced a candidate EX5. Running it could not establish the missing binary identity and would encounter the same include-mirror guard.

The canonical enqueue command created this append-only utility row:

```text
work_item_id: 8c13d2f4-eb5c-4c8c-aac4-29d805e31e81
phase: COMPILE_EA
ea_id: QM5_13213
status: pending
attempt_count: 0
mq5_sha256: d140d313c3bbcd87ccefacfb2068bf164f9db9edfbe49ba410a83fcd4d79054f
risk_contract: RISK_FIXED=1000.0, RISK_PERCENT=0.0
hold: COMPILE_EA_WORKER_ROLLOUT_PENDING (active, release_on_restart=1)
hold reason: COMPILE_EA rows require the reviewed worker version on the full terminal fleet; release only through the governed release-on-restart ceremony
```

The hold was not bypassed or released. The release ceremony is outside this task.

## Registry, setfile and canary invariants

- `ea_id_registry.csv` and `magic_numbers.csv` have no task diff.
- All six IDs remain active. Active magic-row counts are `10706=6`, `10847=5`, `12989=1`, `13128=1`, `13213=1`, `1567=11`.
- `QM5_13213` retains active `USDJPY.DWX` magic `132130000`; its historical XAUUSD row remains retired. No row was reactivated or renumbered.
- No setfile changed. Consequently there is no unauthorized parameter diff and no `build_hash` restamp without a binary.
- The queued canary contract is fixed-risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Q02 canary row ID: **not created**. Eligibility requires a successfully compiled EX5 and a sealed execution-identity hash equal to that new EX5. The old EX5 must not be used to fabricate that condition.
- The other five rebuilds remain held in REVIEW until a green `QM5_13213` canary is reviewed by Claude. `T_Live`, live presets, deployments and AutoTrading were not touched.

## Review continuation

After the reviewed compile-worker rollout releases the utility hold, the next reviewer should require: compile PASS, scoped `build_check -EALabel` PASS, setfile diff limited to `build_hash`, then one append-only Q02 for `QM5_13213` whose `report.execution_identity.sha256` equals the newly produced EX5 SHA-256. A zero-trade run is never sufficient for PASS. `QM5_13128` must remain stopped until Claude decides whether its post-binary event-contract diff requires a new EA identity.
