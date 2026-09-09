# FX cointegration QM5_10025 current-binary Q02 enqueue

Recorded: 2026-09-09T22:41:26Z (2026-09-10 00:41 Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

The frozen sign-aware 66-pair scan remains fully mechanized, so no duplicate
Strategy Card, EA, registry identity, or magic allocation was created. The two
preferred anchors are beyond Q02 rather than blocked by current `ONINIT` or
`NO_HISTORY` failures:

- `QM5_12532` AUDUSD/NZDUSD: logical Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: logical Q02 PASS, then Q04 FAIL.

The existing approved fallback `QM5_10025_rw-fx-broad-pairs` was advanced
instead. It is a structural H4 market-neutral FX strategy sourced to Robot
Wealth: at monthly rebalance it selects a partner from seven FX majors, freezes
the OLS hedge ratio, and trades a beta-weighted two-leg log spread. Its card is
G0 APPROVED with R1-R4 PASS and contains no ML, grid, or martingale mechanic.

Exactly one current-binary USDJPY/H4 Q02 successor was enqueued:
`d16ec281-927d-4dba-a83d-700cd9caa9fa`. At post-write verification it was
pending, unclaimed, attempt zero, priority-tracked, and the only unsuperseded
open Q02 row for the exact EA/symbol identity.

## Baseline repair

The canonical USDJPY backtest preset carried `strategy_debug=true`, added after
the last executable baseline. That input is absent from the approved card, and
the EA SPEC explicitly says recovery diagnostics are default-off and enabled
only in an evidence-specific preset. Removing the override restores the
canonical baseline to the approved semantic contract; the source default is
already `false`. No entry, exit, sizing, selection, or risk mechanic changed.

The guarded `requalify-q02` dry-run then recovered the exact predecessor preset
from Git (`2d8a1ba...`), found a zero-parameter executable diff, authenticated
the current COMPILE_OK record `21c7d995`, and accepted the current identities:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `db7424efcba0a8df90184240e277e1a7546e8030672eec88a4c72a89c32a5a61` |
| EX5 | `49fcc59b5232531f5fd2e3ba7a0c71f0bac703f54e17f7c92c911e31944d91f1` |
| USDJPY H4 setfile | `8fbc0a841fea34b345aa7494cc4d822c3ea1c2acfffad65596e2e7bacf8578c3` |

The setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## PACER and resource guards

The source-pin audit was run against the existing MQ5 before the Q02 enqueue:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_10025_rw-fx-broad-pairs/QM5_10025_rw-fx-broad-pairs.mq5"
```

It exited zero with `ok=true` and zero `EA_FRAMEWORK_INPUT_PINNED` findings.
No MQ5 was written or edited and no compile was enqueued. An ad-hoc
`build_check.ps1 -SkipCompile` attempt was refused by the live-factory compile
guard, so no bypass or retry was attempted; the successor instead binds the
existing governed COMPILE_OK evidence whose compile and build-check results are
both PASS.

Immediately before the queue write, five one-second whole-host CPU samples were
`40.368334%`, `34.740291%`, `40.270339%`, `44.244551%`, and `43.003387%`.
Average was `40.52538%` and maximum `44.244551%`, both below the binding 97%
ceiling.

## Lineage and safety

The new row preserves ZERO_TRADES predecessor `050dd2ea` and records the
canonical `farmctl:requalify-q02/v1` supersedes edge. The attempted direct rerun
of intermediate row `e49888a1` was correctly refused before mutation because
its pre-dispatch crash payload lacked the required
`dispatch_ex5_verified_at` marker; the guarded post-binding requalification
path was used instead.

No dispatch tick or manual MT5 launch was performed. No portfolio-admission,
portfolio-KPI, Q08-contribution, portfolio-gate, deploy manifest, `T_Live`, or
AutoTrading surface was touched. Unrelated shared-worktree changes were left
unstaged and excluded.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_10025_q02_enqueue_20260909T224126Z_board_advisor.json`.
