# QM5_11463 EURUSD Q02 infrastructure diagnosis and CPU stop

Date: 2026-08-30

Branch: `agents/board-advisor`

Farm task: `7217df8a-1b0a-45ad-863f-b39f97dc79c4`

Outcome: **DIAGNOSED READY; Q02 NOT ENQUEUED BECAUSE THE 97% CPU STOP WALL
FIRED**

## Selection and collision control

No priority-1 build was admissible under the structural-only build contract.
The unbuilt rates and lumber cards still fail their required-input gate, the
strongest unbuilt structural FX cards lack preallocated magic rows, and the
remaining registry-complete unbuilt FX candidate is an indicator-stack port
rather than a structural edge. The build skill requires an approved card plus
both deterministic registry allocations and does not permit inventing the
missing rows.

The next high-value non-duplicate target was therefore the EURUSD carrier of
`QM5_11463_goodwin-j-session-high-breakout-usdjpy`. The approved card is a
structural H1 session-range breakout: construct one daily session high/low,
trade its break only in the prior-D1 candle direction, use a fixed protective
stop, and exit at end of day. It is sourced to Jarrod Goodwin's published
*Beat the Markets Strategy Guidebook* and uses no ML, adaptive indicator,
grid, martingale, or PnL-feedback rule.

Before diagnosis, an atomic farm recheck found no open EURUSD Q02/Q03 row, no
append-only successor, and no competing live claim for this EA. The exact
scope was claimed as ops task `7217df8a-1b0a-45ad-863f-b39f97dc79c4`, assigned
to `codex:agents/board-advisor`.

The online pre-claim database backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11463_eurusd_history_sync_claim_20260830T075627Z.sqlite`

## First failed layer

The preserved EURUSD predecessor is
`b0c9b4f2-64e1-4043-8c97-c2e767c0f991` (`failed / INFRA_FAIL`) on
`EURUSD.DWX / H1`, 2018-07-02 through 2022-12-31. Its retained summary is:

`D:\QM\reports\work_items\b0c9b4f2-64e1-4043-8c97-c2e767c0f991\QM5_11463\20260807_193006\summary.json`

All three T3 attempts failed before usable EA execution with `NO_HISTORY` and
`INCOMPLETE_RUNS`. Each report had an empty expert, empty symbol, `M0 1970`,
zero bars, and invalid history context. The summary explicitly records
`oninit_failure_detected=false`. The EX5 and setfile were stable during the
attempts and matched their authenticated work-item bindings.

The control row separates infrastructure from strategy behavior. Work item
`c994bed4-35e7-4926-9ba4-845ccd5a72da` ran the identical MQ5/EX5 identity on
`GBPUSD.DWX / H1` on T8 and finished Q02 `PASS` with one valid report and 841
trades. No source, binary, setfile, or strategy-mechanics repair is indicated;
the first failed layer is T3-local EURUSD history availability.

## Artifact and risk binding

| Artifact | Current and predecessor SHA-256 |
|---|---|
| MQ5 | `e747f80b8b1b6d940f0b2c8c21dcc4f251bdfc6e8f6f78808c66226df0993c10` |
| EX5 | `07a308a50e00283b2f11dced99a4b840024c7a3d6fbdcbea3816140e0a53f834` |
| EURUSD H1 setfile | `511b98cd2e1fdcc14755c2e3ffc913959bcc0bcccb890da1ab1aa76223079a9a` |

The exact setfile retains `RISK_FIXED=1000` and `RISK_PERCENT=0`.
`validate_spec_doc.py` passed 1/1. A static `build_check -SkipCompile` attempt
failed closed with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because terminal64
processes were alive; it was not bypassed or retried. The authenticated hashes
and the same-binary GBPUSD PASS make a rebuild unnecessary.

## Binding CPU stop

At 2026-08-30T07:59:56Z through 08:00:08Z, five host CPU samples were:

`94.0%, 96.0%, 100.0%, 100.0%, 100.0%`

The average was 98.0% and the maximum was 100.0%. Both exceed the governed
97% average-or-maximum paced-fleet wall. `farmctl mt5-slots` concurrently
reported four active research terminals (`T6`, `T7`, `T9`, and `T10`); the
terminal-count ceiling was not binding, but the host-CPU wall was.

The mission's explicit stop condition therefore fired before the append-only
enqueue. No new QM5_11463 EURUSD work item exists, the failed predecessor is
unchanged, and no dispatch or tester launch was requested.

Machine-readable receipt:
`artifacts/qm5_11463_eurusd_q02_infra_repair_cpu_stop_20260830T080008Z.json`

## Reclaimable continuation

After CPU is below the governed resume threshold, a future paced operator must
reclaim this EA and repeat the exact duplicate, artifact, fixed-risk, and
capacity checks. The intended producer is the supported
`farmctl.append_only_exact_row_rerun` path using predecessor
`b0c9b4f2-64e1-4043-8c97-c2e767c0f991`. The successor must be steered away
from T3. Current append-only payload construction deliberately drops runtime
keys such as `avoid_terminals`, so that steering must be added through a
governed atomic pending-row repair rather than assumed to copy from the failed
row.

No EA mechanics, historical verdict, registry, setfile, portfolio gate,
T_Live process or file, deploy manifest, AutoTrading setting, portfolio
admission, or certification state was changed.
