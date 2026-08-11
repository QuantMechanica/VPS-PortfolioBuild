# QM5_12538 Q02 closed-bar performance recovery

Date: 2026-08-11
Branch: `agents/board-advisor`
EA: `QM5_12538_nnfx-canonical-stack2-st-vortex`
Scope: Q02 infrastructure repair for a nine-pair D1 FX sleeve; no economic verdict

## Selection and coordination

- The approved build backlog had no clean, unclaimed low-frequency forex, crypto, rates, energy-beyond-XNG, or market-neutral-pairs card with all deterministic registry inputs available. This made the mission's priority-2 repair lane the highest valid non-duplicate action.
- `QM5_12538` is an APPROVED, structural D1 strategy over `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `EURJPY.DWX`, and `GBPJPY.DWX`. The approved card records R1-R4 PASS and the No Nonsense Forex doctrine/community-vetted component basis.
- EA registry row `12538` and active magic slots 0-8 were present before changes. All nine `.DWX` symbols were present in the governed symbol matrix.
- Farm claim: `agent_tasks.id=9ef5d015-9a16-4b84-b520-6e1638212b72`, assigned to `codex:agents/board-advisor` before source changes.
- Pre-claim SQLite backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12538_perf_claim_20260811T192440Z.sqlite`.

## Diagnosed infrastructure defect

The Q02 history contains 104 `INFRA_FAIL` rows for this EA, including 62 rows whose `payload_json.verdict_reason` is explicitly `ACTIVE_TIMEOUT`. All latest symbol rows were bound to the prior EX5 SHA-256 `d6bdb066e83c28b6d40d273731b04044fa3cc35093742e7c6591ad7533d1825f`.

The prior per-tick exit path rebuilt McGinley Dynamic and SuperTrend over the 250-bar warm-up on every tick while a position was open. It also repeated the closed-bar ATR read. This bounded reconstruction is appropriate once per closed D1 bar, but its placement in `Strategy_ExitSignal()` multiplied it by the tick count and matches the recurrent active-timeout signature. This repair changes execution cost only; it does not reinterpret an economic result.

## Repair

- Added a tester-robust cache keyed by `QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1)`.
- Rebuild McGinley, SuperTrend, Vortex, ADX, ATR, and baseline-cross state at most once per completed D1 bar; entry, management, and exit hooks reuse that state in O(1) time on intervening ticks.
- Kept baseline exits available when an entry-only component is unavailable and fail closed for missing history rather than retrying the 250-bar scan every tick.
- Restored the current framework lifecycle order: MAE sampling first, position management and exits before the central entry-only news gate, and zero-initialized entry requests.
- Preserved the approved card's parameters and mechanics. No signal threshold, risk mechanic, or market universe changed.
- Regenerated all nine canonical backtest setfiles from the approved card. Each contains the 14 explicit `strategy_*` inputs, its registered magic slot, `RISK_FIXED=1000`, and `RISK_PERCENT=0`.

Current artifact bindings:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `061a979cb6fc1ac5f681b7faeb82c686fab29643e304ffd4d44f4d280a8bcaf2` |
| EX5 | `0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20` |
| AUDUSD set | `ec78b5b748ff9465bb9ff3ea9be6d3c5243364c5a52ce414931ead39b1401690` |
| EURJPY set | `4b4ad3559d41be24a341e361262decf80de7ed03aa2ec5a50d390d770e238e96` |
| EURUSD set | `4cf46cf7200dcc5c704e9ded7140bb002e077f7dbb7b63409eb822cd3af2534e` |
| GBPJPY set | `5826fe906bc47b8b4a99aa9fb32f1fe3a69fb0d6e0f906f7766b5bcff52f05e1` |
| GBPUSD set | `8f8b4e84e2ddd94bb618d90f99169f3776e915787339c40a1821bf32b2f2af46` |
| NZDUSD set | `8143fc09db751bcb4f895bee69a350dc7873e6760bd3b980512b4773ac1e5d13` |
| USDCAD set | `6dceed052238a1a43a31ac046ced330ec90aea4f496be1b323eca704dc96e6a0` |
| USDCHF set | `300e27c8a0f9de2df0a8efbbec3e901d84e34981e6b140d9dd99f3de3c3bccd3` |
| USDJPY set | `fc11fd3889ede0071cd01ee534a7fe122f63ea7e03576c6abfba1613c27594e3` |

## Verification

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12538_nnfx-canonical-stack2-st-vortex`: PASS.
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12538_nnfx-canonical-stack2-st-vortex`: PASS, 10 files checked, no findings.
- `pwsh framework/scripts/build_check.ps1 -EALabel QM5_12538_nnfx-canonical-stack2-st-vortex -RepoRoot C:\QM\repo`: PASS, 0 failures, 0 warnings.
- Compile result: PASS, 0 errors, 0 warnings. Log: `C:\QM\repo\framework\build\compile\20260811_193241\QM5_12538_nnfx-canonical-stack2-st-vortex.compile.log`.
- Build-check report: `D:\QM\reports\framework\21\build_check_20260811_193241.json`.
- `git diff --check` on the EA directory: PASS.

## CPU ceiling and deferred Q02 handoff

At 2026-08-11 19:33 UTC the farm scan showed active tester processes on T1, T4, and T9, five terminal reservations, and a five-sample host CPU average of 88.7%. Per the paced-fleet instruction to stop at the backtest CPU ceiling, no smoke test was launched and no new runnable Q02 work item was appended.

One older EURUSD Q02 row (`31e65c62-2721-432d-8ad0-b59989ffa688`) was already pending before this repair and remains bound to the prior EX5. It is not evidence for the repaired binary. The safe next action, once capacity is below the ceiling, is an append-only current-binary Q02 requalification for the nine registered FX symbols, guarded by EX5 SHA-256 `0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20`.

No portfolio gate, T_Live artifact, deploy manifest, or AutoTrading setting was touched.
