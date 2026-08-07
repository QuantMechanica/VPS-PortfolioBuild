# FX Cointegration Frontier / Q02 CPU-Ceiling Stop

Date: 2026-08-07

Branch: `agents/board-advisor`

Status: no unbuilt relationship remains in the frozen 66-pair scan; one
existing low-frequency FX card selected for Q02 breadth promotion; enqueue
stopped before apply at the binding paced-fleet CPU ceiling

## Outcome

The frozen sign-aware scan and current repository were reconciled before any
mutation. Both requested anchors are already beyond Q02:

- `QM5_12532` has a logical-basket Q02 PASS and Q04 PASS, followed by Q05
  FAIL.
- `QM5_12533` has a logical-basket Q02 PASS, followed by Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

The relationship frontier is now exhausted. The repository is built through
rank 64 as `QM5_20255_usdchf-eurjpy`; rank 65 (`USDCHF.DWX` / `AUDUSD.DWX`)
is already an explicit pair slot in
`QM5_1156_caldeira-cointegration-pairs-fx`; and rank 66
(`USDCAD.DWX` / `EURAUD.DWX`) is the dedicated
`QM5_12803_edgelab-usdcad-euraud-cointegration` basket, with Q02 PASS and a
later Q04 FAIL. A new Card or EA for either final row would duplicate existing
mechanization.

No new Strategy Card, EA allocation, magic row, EA source, setfile, or basket
manifest was created.

## Reproducible frontier check

The full 66-row ranking was reproduced from the frozen Darwinex D1 export by
running the governed scan with negative hedge ratios retained:

```powershell
python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges
```

The last two rows are both adverse one-shot candidates rather than positive
edge claims:

| Rank | Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | Existing coverage |
|---:|---|---:|---:|---:|---:|---|
| 65 | USDCHF / AUDUSD | -0.21 | -0.66 | -5.70% | 16 | explicit `QM5_1156` pair slot |
| 66 | USDCAD / EURAUD | 0.57 | -0.87 | -5.84% | 13 | dedicated `QM5_12803`; Q02 PASS, Q04 FAIL |

The reputable structural method remains the OWNER-ratified Tier-A extraction
of Ernest P. Chan, *Quantitative Trading* (Wiley, 2009), preserved at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. The scan is
pair-selection evidence only; it does not turn the adverse rows into author
performance claims.

## Existing-card fallback

With no honest unbuilt scan pair, the canonical fallback was
`QM5_11646_robo-rsi8-pending-d1`, the existing reputable-source,
low-frequency D1 FX card built in commit `31dea3914`. Its five backtest
setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and registered symbol slots.

At selection time its first Q02 wave contained:

| Symbol | State |
|---|---|
| `EURUSD.DWX` | Q02 PASS |
| `AUDUSD.DWX` | Q02 PASS |
| `GBPUSD.DWX` | Q02 pending |

The deferred sidecar still contained exactly two second-wave hosts,
`USDJPY.DWX` and `USDCAD.DWX`. A target-only dry run at
`2026-08-07T01:40:10+02:00` selected exactly those two rows with
`promotion_reason=stage1_pass`, selected zero never-tested rows, and selected
zero stranded retries:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_11646
```

The dry-run evidence is
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`. It records
`apply=false`, target `QM5_11646`, and 1,431 pending rows before the dry run.

## Binding CPU ceiling

The mandatory immediate pre-apply sample at
`2026-08-07T01:40:32+02:00` found nine factory terminals running:

```text
T1, T2, T3, T4, T5, T7, T8, T9, T10
```

Nine exceeds the binding seven-terminal ceiling. The guarded command exited
before invoking `--apply`. A post-stop read-only check confirmed that
`QM5_11646` still has only its original three Q02 work items and that both
deferred setfiles remain in `q02_deferred_symbols.json`.

No queue row was inserted, claimed, or dispatched. No MT5 process was launched,
stopped, reserved, reaped, or controlled.

## Next paced action

After a fresh immediate factory-terminal sample is strictly below seven,
repeat the target-only dry run and apply only if it still selects exactly the
same two deferred rows and no other work:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_11646
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_11646 --apply
```

Normal workers own dispatch and Q02 execution.

## Safety

- `T_Live`, AutoTrading, deploy manifests, and live setfiles were not touched.
- No portfolio-admission, portfolio KPI, or Q08-contribution path was touched.
- No manual tester, smoke test, or pipeline phase was launched.
- Existing unrelated dirty-worktree files were left untouched.

## 2026-08-07 04:32Z continuation audit

The deferred-symbol fallback became stale before a safe apply window opened.
A target-only dry run for `QM5_11646` selected zero rows because the canonical
farm had already promoted and completed both deferred hosts. Current terminal
evidence now records Q02 PASS on all five declared FX symbols:

| Symbol | Q02 work item | Verdict |
|---|---|---|
| `AUDUSD.DWX` | `53f68c79-595a-465c-8d40-5badd8396b3e` | PASS |
| `EURUSD.DWX` | `591178a9-50db-4097-987a-aa6f3dffe5f5` | PASS |
| `GBPUSD.DWX` | `430172e1-7334-4a31-8871-97c53eb4ce7d` | PASS |
| `USDCAD.DWX` | `2dc0bd15-419d-4e11-8037-7dedc8e891a5` | PASS |
| `USDJPY.DWX` | `c77db90c-dedd-4cce-8035-b850538a0797` | PASS |

The same card has since reached terminal Q04 FAIL on all five symbols, so it
is no longer a valid funnel-advancement fallback. Re-enqueueing any of these
rows would duplicate terminal work. Direct canonical-farm reads also
reconfirmed that the requested anchors are not currently blocked at Q02:
`QM5_12532` retains logical-basket Q02 PASS followed by Q04 PASS and Q05 FAIL,
and `QM5_12533` retains logical-basket Q02 PASS followed by Q04 FAIL.

The immediate `farmctl mt5-slots` sample at `2026-08-07T04:32:53+00:00`
found every factory terminal `T1` through `T10` running. The separately
observed `T_Live` and FTMO terminals were excluded from the factory count and
were not controlled. Ten factory processes exceed the binding seven-terminal
ceiling, so the mission stopped before selecting another existing FX card,
applying an enqueue, dispatching work, or launching a tester.

The target-only dry-run evidence is
`D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json` with
`generated_at=2026-08-07T04:32:35+00:00`, `apply=false`, and zero selected
rows. No queue row, deferred sidecar entry, terminal process, EA artifact,
registry, portfolio gate, or live artifact was changed.

## 2026-08-07 08:31Z paced-fleet audit

The non-duplicate decision remains binding. The frozen 66-pair frontier is
already fully mechanized, and neither requested anchor has a Q02 ONINIT or
NO_HISTORY blocker. `QM5_12532` remains beyond Q02 with Q04 PASS followed by
Q05 FAIL; `QM5_12533` remains beyond Q02 with Q04 FAIL. Creating another
scan-derived basket would duplicate existing work.

Before selecting a second existing-card fallback, the mandatory immediate
`farmctl mt5-slots` sample found eight factory terminals running:

```text
T1, T2, T3, T6, T7, T8, T9, T10
```

Eight exceeds the binding seven-terminal ceiling. All ten enabled terminal
workers were also present. The separately observed `T_Live` and FTMO
terminals were excluded and not controlled. Per the paced-fleet stop rule, no
fallback was selected, no queue row was inserted or dispatched, and no tester
or terminal action followed.

The machine-readable snapshot is
`artifacts/fx_cointegration_frontier_stop_20260807T083123Z_board_advisor.json`.
No Strategy Card, EA, setfile, basket manifest, registry, portfolio gate,
T_Live manifest, or AutoTrading state changed.

## 2026-08-07 09:30Z paced-fleet audit

The governed 66-pair frontier and anchor dispositions remain unchanged at
repository head `d9ec7b4d6`: every relationship is already mechanized,
`QM5_12532` is past Q02 with Q04 PASS followed by Q05 FAIL, and `QM5_12533`
is past Q02 with Q04 FAIL. A new scan-derived Card or build would therefore
duplicate existing work.

The mandatory immediate `farmctl mt5-slots` sample observed eight factory
terminals running:

```text
T1, T3, T5, T6, T7, T8, T9, T10
```

Eight exceeds the binding seven-terminal ceiling, and all ten enabled
terminal workers were present. `T_Live` and the FTMO terminal were observed
only to exclude them from the factory count; neither was controlled. The
factory roster is a fresh observation rather than a copy of the 08:31Z
snapshot: `T2` exited, `T5` entered, and the count remained eight.

Per the paced-fleet stop rule, no fallback EA was selected, no queue row was
inserted or dispatched, and no tester or terminal action followed. The
machine-readable snapshot is
`artifacts/fx_cointegration_frontier_stop_20260807T093028Z_board_advisor.json`.
No Strategy Card, EA, setfile, basket manifest, registry, portfolio gate,
T_Live manifest, or AutoTrading state changed.

## 2026-08-07 10:16Z paced-fleet audit

The governed 66-pair frontier and anchor dispositions remain unchanged at
repository head `bef21f297`: every relationship is already mechanized,
`QM5_12532` is past Q02 with Q04 PASS followed by Q05 FAIL, and `QM5_12533`
is past Q02 with Q04 FAIL. A new scan-derived Card or build would therefore
duplicate existing work.

The mandatory immediate `farmctl mt5-slots` sample observed eight factory
terminals running:

```text
T1, T3, T4, T5, T7, T8, T9, T10
```

Eight exceeds the binding seven-terminal ceiling, and all ten enabled
terminal workers were present. `T_Live` and the FTMO terminal were observed
only to exclude them from the factory count; neither was controlled. This is
a fresh observation rather than a duplicate of the 09:30Z snapshot: `T6`
exited, `T4` entered, and the count remained eight.

Per the paced-fleet stop rule, no fallback EA was selected, no queue row was
inserted or dispatched, and no tester or terminal action followed. The
machine-readable snapshot is
`artifacts/fx_cointegration_frontier_stop_20260807T101608Z_board_advisor.json`.
No Strategy Card, EA, setfile, basket manifest, registry, portfolio gate,
T_Live manifest, or AutoTrading state changed.
