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
