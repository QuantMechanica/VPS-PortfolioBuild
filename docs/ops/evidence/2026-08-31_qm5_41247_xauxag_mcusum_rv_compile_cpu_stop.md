# QM5_41247 XAU/XAG Centered-CUSUM Reversion — Build Complete, Compile/Q02 CPU Stop

Date: 2026-08-31

Branch: `agents/board-advisor`

## Outcome

`QM5_41247_xauxag-mcusum-rv` is a new, source-approved, committed
market-neutral-style commodity build. The governed compile row is source-fresh
and released as a single-item canary, but it remained pending and unclaimed.
Q02 was not enqueued because resident worker T7 then logged `cpu_high_pause`
at `98.4%` against the governed `97%` ceiling. No Q01 verdict or certification
is claimed.

## Edge And Non-Duplicate Boundary

The EA forms thirteen synchronized completed month-end
`ln(XAUUSD.DWX)-ln(XAGUSD.DWX)` endpoints and twelve adjacent relative log
returns. It mean-centers the full return vector, evaluates all eleven
nonterminal cumulative sums, requires a unique maximum absolute CUSUM at
split `4..8`, and fades the post-split mean with opposite equal-target-
notional XAU/XAG legs for the next broker month.

The corrected-root dedup scan found no exact identity. It retained one honest
fuzzy neighbor, `QM5_41245_wti-mcusum-shift-tr`, because both use centered
CUSUM mechanics. Manual review separates them: QM5_41245 is single-leg,
directional WTI continuation, whereas QM5_41247 is a contrarian XAU/XAG
relative-value basket with atomic two-leg lifecycle, aggregate risk, and
next-month exit. The governed receipt is
`artifacts/qm5_xauxag_mcusum_rv_preallocation_dedup_20260831.json`, SHA-256
`165C8CC9BCE9C560D2BF889DE1CBF5E3BA9A110147B921EF982D8CD8808D6C95`.

## Committed Build Evidence

- Source approval: commit `e1d653c557`.
- EA identity reservation: commit `18993d1424`.
- G0-approved Strategy Card: commit `3285eb201e`.
- Deterministic magic allocation: commit `8d9069a3b0`.
- EA, basket manifest, tests, and fixed-risk presets: commit `41aaf320df`.
- MQ5 SHA-256:
  `249DB08872348DC74503E4413158189E6A34EFAC8E9B2098F3E022120FFBD59E`.
- Basket-manifest SHA-256:
  `6CE2FA737398F9356FE1A65A5FBD962C600DDA69C896FD495264C2311A54C7B6`.
- Deterministic reference suite: 7/7 PASS, covering CUSUM centering,
  split boundaries, tied/zero maxima, ratio orientation, month continuity,
  exact contrarian sides, manifest/card locks, and fixed-risk presets.
- Strategy-card schema and scoped execution-contract lint: PASS with zero
  issues.
- All three backtest presets use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`. No live/demo/shadow/stress/optimization preset exists.

The binary is intentionally absent and each preset remains honestly marked
with a pending build hash. Therefore Q01 is pending, not PASS.

## Governed Compile And Binding Capacity Stop

Direct ad-hoc compilation first failed closed on the live-factory interlock.
The sanctioned enqueue created compile work item
`d8cd4994-6de9-4854-abec-5185a288a379`. A single-item rollout dry run matched
the queued and actual MQ5 hash exactly, then the apply step released only that
row. Its state at stop was `pending`, attempt `0`, unclaimed, with no verdict
or evidence path.

The release made a pre-mutation state backup at
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260831T115757Z_07f7b3cb.sqlite`,
SHA-256
`8E3755FCB691FCEBB28D9B8C21425CADB852BCEDA323EE47987B9CF6D5732D15`.

At `2026-08-31T12:02:43.267643Z`, resident worker T7 recorded CPU load
`98.4%`, threshold `97.0%`, and `hysteresis_latched=true`. This is the mission's
binding stop condition, so no further compile scheduling or Q02 mutation was
attempted.

## Queue And Safety State

- Q02 work items for `QM5_41247`: zero.
- Intended single Q02 carrier:
  `QM5_41247_XAU_XAG_MCUSUM_RV_D1 / D1` via the logical basket preset.
- No manual backtest or dispatch tick ran.
- No terminal was started, stopped, or reserved by this work.
- AutoTrading was not toggled.
- `T_Live`, the portfolio gate, and the live manifest were not changed.
- Unrelated staged, modified, and untracked worktree files were preserved.

Resume by consuming the existing exact compile row through a resident worker
only after CPU and reservation gates clear. Require zero-error/zero-warning
compile plus strict build-check PASS and current EX5/setfile hash binding.
Then take a fresh governed CPU reading and enqueue exactly one logical-basket
Q02 row; do not fan out the component presets.
