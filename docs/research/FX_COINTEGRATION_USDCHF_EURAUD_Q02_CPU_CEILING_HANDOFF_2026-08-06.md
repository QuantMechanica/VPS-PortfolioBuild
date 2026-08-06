# QM5_20252 USDCHF/EURAUD Q02 CPU-Ceiling Handoff

Date: 2026-08-06

Branch: `agents/board-advisor`

Status: Q01 PASS; target-only Q02 dry run PASS; NOT ENQUEUED because the
paced-fleet CPU ceiling became binding before apply

## Outcome

`QM5_20252_usdchf-euraud` is the current non-duplicate forex continuation.
It implements the first remaining relationship-level gap in the frozen
sign-aware 66-pair scan as a dedicated, low-frequency D1 basket. The approved
Card, deterministic EA ID, two traded-symbol magic rows, EA source and binary,
`basket_manifest.json`, and `RISK_FIXED` backtest presets are committed and
Q01-clean.

A target-only guarded enqueue dry run selected exactly one logical-basket Q02
item and skipped the physical host preset as intended. No apply followed. The
immediate capacity recheck found every factory terminal `T1` through `T10`
running, above the binding seven-terminal ceiling. Per the mission, work
stopped without queue mutation, dispatch, or tester launch.

## Anchor triage

Current canonical Strategy Farm queries confirmed:

- `QM5_12532` has logical-basket Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533` has logical-basket Q02 PASS, followed by Q04 FAIL.
- Neither anchor has a current pending or active Q02 ONINIT / NO_HISTORY
  blocker.

Repairing or re-enqueueing either anchor would duplicate completed funnel
work.

## Selected sleeve and source boundary

The durable authorization is
`decisions/2026-08-06_usdchf_euraud_cointegration_g0.md`. The structural
method is bounded to the OWNER-ratified Tier-A extraction of Ernest P. Chan,
*Quantitative Trading* (Wiley, 2009), preserved at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Pair
selection comes from the OWNER-requested frozen Darwinex D1 scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`.

USDCHF/EURAUD is rank 63 of 66 in the sign-aware scan:

| Measure | Frozen value |
|---|---:|
| DEV net Sharpe | 0.035741181146 |
| OOS net Sharpe | -0.511801618546 |
| OOS return | -5.026003522460% |
| OOS state changes | 15 |
| DEV beta | -0.013891609131 |
| Half-life | 97.341572780157 D1 bars |

The adverse OOS result and slow cadence are explicit falsification evidence.
This is a one-shot Q02 retirement candidate, not a profitability claim. No
beta refit, filter addition, or parameter rescue is authorized after an
economic or cadence failure.

The governed dedup review found no dedicated USDCHF/EURAUD two-leg basket.
Rank 62 USDJPY/AUDUSD was already covered by explicit pair slots in
`QM5_1156` and `QM5_1257`, making rank 63 the first relationship-level build
gap rather than a duplicate of an existing dedicated sleeve.

## Q01-ready implementation

- EA: `QM5_20252_usdchf-euraud`.
- Logical symbol: `QM5_20252_USDCHF_EURAUD_COINTEGRATION_D1`.
- Host and first traded leg: `USDCHF.DWX`, D1.
- Companion traded leg: `EURAUD.DWX`.
- Conversion-history-only symbol: `AUDUSD.DWX`; no order or magic slot.
- Frozen residual:
  `ln(USDCHF) - (-0.013891609131) * ln(EURAUD)`.
- Entry: `abs(z) > 2.0` against the strictly prior 60 aligned closed-D1
  residuals.
- Exit: `abs(z) < 0.5`, with independent `2.0 * ATR(20,D1)` hard stops.
- Negative beta makes long-spread packages long both legs and short-spread
  packages short both legs.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Magic slots: USDCHF slot 0 / `202520000`; EURAUD slot 1 / `202520001`.

There is no learned model, banned indicator, online refit, grid, martingale,
live setfile, or deployment artifact.

Q01 evidence:

- Strict build check PASS with zero failures and zero warnings:
  `D:\QM\reports\framework\21\build_check_20260806_190426.json`.
- Compile PASS with zero errors and zero warnings:
  `D:\QM\reports\compile\20260806_190427\summary.csv`.
- Canonical Card schema lint PASS with zero missing sections and zero ML-ban
  hits.
- Targeted basket-manifest regression suite: 43 passed.
- Manual smoke or backtest run: none.

## Guarded Q02 dry run

The no-mutation command was:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20252
```

Evidence at `D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`
was generated at `2026-08-06T20:19:59Z` with `apply=false`. It recorded:

- target EA `QM5_20252` only;
- one `never_tested` priority-track selection for logical symbol
  `QM5_20252_USDCHF_EURAUD_COINTEGRATION_D1`;
- logical setfile
  `QM5_20252_usdchf-euraud_QM5_20252_USDCHF_EURAUD_COINTEGRATION_D1_D1_backtest.set`;
- one intentional physical-preset skip with reason
  `basket_manifest_logical_setfile_preferred`;
- zero stranded or deferred-promotion selections; and
- 1,468 pending rows before the dry run against the separate 7,000-row queue
  ceiling.

An immediate canonical `farmctl work-items --ea QM5_20252` query returned zero
rows, confirming that the dry run did not enqueue or duplicate anything.

## Binding CPU-ceiling stop

At `2026-08-06T20:19:59Z`, a path-exact process sample briefly observed six
factory terminals (`T1`, `T2`, `T3`, `T5`, `T8`, and `T9`). Before any apply,
the mandatory canonical recheck at `2026-08-06T20:20:56Z` observed all ten
factory terminals:

```text
T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
```

Only executable paths matching `D:/QM/mt5/T1..T10/terminal64.exe` counted.
The separately observed `T_Live` and FTMO terminals were excluded. The later
sample controls because it immediately precedes the proposed mutation. Ten
factory terminals exceed the binding ceiling of seven, so the enqueue apply
was not attempted.

The next valid paced-fleet action is to repeat the exact target-only dry run
and apply once a fresh immediate sample is below the ceiling:

```powershell
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20252
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20252 --apply
```

The apply must still produce exactly one logical-basket row and the physical
host skip. Normal workers, not this handoff, own dispatch and Q02 execution.

## Safety

- No Q02 row was inserted, claimed, dispatched, or duplicated.
- No MT5 process was launched, stopped, reserved, reaped, or controlled.
- `T_Live` and AutoTrading were not touched.
- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No live manifest, deploy manifest, or live setfile changed.
- The Strategy Card remains `pipeline_phase: Q01_PASS`, with Q02
  `NOT_ENQUEUED`.

## Existing commit chain

- `a4cd59efa`: approved source-backed Strategy Card.
- `7bc9530b4`: deterministic EA-ID allocation.
- `59566086b`: two deterministic magic rows and regenerated resolver.
- `7f070d1fd`: compiled basket build, manifest, fixed-risk presets, Card
  copies, regression coverage, and Q01 evidence.
