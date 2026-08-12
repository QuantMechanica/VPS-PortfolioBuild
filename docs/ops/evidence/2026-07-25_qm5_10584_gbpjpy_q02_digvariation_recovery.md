# QM5_10584 GBPJPY Q02 DigVariation recovery

Date: `2026-07-25`

Branch: `agents/board-advisor`

EA: `QM5_10584_mql5-digvar`

Instrument / timeframe: `GBPJPY.DWX` / `H8`

Farm repair claim: `b54371c4-74b8-4f1e-8fee-8688c8217b27`

Q02 work item: `d5c5afbb-08b6-4e8b-8356-7a1b51fb9179`

## Selection

No unclaimed diversity-first card in the approved build backlog cleared all
deterministic build gates. The apparent FX pair/cointegration cards had
card-to-registry slug mismatches, while the remaining preflight-clean FX card
exceeded the governed compiled-label limit. No card was forced through those
gates.

`QM5_10584` was selected under mission priority 2. It is a structural,
low-frequency direction-reversal strategy whose approved card plans about 25
trades per year per symbol. `GBPJPY.DWX` is both the source test carrier and a
useful FX-cross sleeve for instrument diversity.

The repair was claimed atomically before mutation. The pre-change online
SQLite backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10584_gbpjpy_q02_recovery_20260725T005928Z.sqlite`

Pre- and post-mutation `PRAGMA quick_check` both returned `ok`.

## Failure evidence

The existing Q02 row had no strategy verdict:

- status: `done`
- verdict: `INFRA_FAIL`
- durable DB reason: `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`
- evidence provenance: `real_mt5`
- recorded summary pointer:
  `D:\QM\reports\work_items\d5c5afbb-08b6-4e8b-8356-7a1b51fb9179\QM5_10584\20260529_064013\summary.json`

That Q02 run occurred on 2026-05-29. The active magic rows for slots 0-3
were registered only on 2026-06-02, explaining the historical initialization
failure. The current generated resolver contains the four active mappings,
including `105840000` for `GBPJPY.DWX`.

Two additional deterministic defects prevented a valid retry:

1. The work item and approved card require H8, but the repository contained
   only H4 backtest setfiles. The exact H8 path stored by the farm did not
   exist.
2. The legacy `e4900b2c` no-source rebuild did not implement DigVariation.
   It selected shared `strategy_model=11`, whose implementation is a
   12-period rate-of-change zero crossover.

Re-enqueueing the old artifact would therefore have tested the wrong strategy
even after the historic magic failure had disappeared.

## Source-bound repair

The official [MQL5 CodeBase entry for Exp_DigVariation](https://www.mql5.com/en/code/13554)
and its linked source files establish:

- H8 as the source EA default;
- SMA period 12;
- digital smoothing power `dig_1`;
- a closed-bar long signal when oscillator direction turns from falling to
  rising and a short signal on the inverse turn.

The EA now implements the source calculation directly from bounded Darwinex
H8 close data:

`raw = 1000 * (close - (SMA12(close) + SMA12(close - SMA12(close))))`

The source `dig_1` 20-tap digital filter is then applied to shifts 1-3. A
shift-2 trough signals long and a shift-2 peak signals short. No custom
indicator binary or external runtime data is required.

The repair also:

- replaces the four stale H4 setfiles with H8 setfiles for the registered
  basket;
- adds an explicit strategy specification;
- retains the approved V5 2.0 ATR stop and 1.5R target;
- retains one-position-per-symbol/magic behavior;
- uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` in every backtest setfile;
- rebuilds the EX5 against the current generated magic resolver.

No ML, banned indicator, grid, martingale, averaging-down, or adaptive sizing
was introduced.

## Validation

- Build skill guard: PASS; EA registry, magic rows, and EA directory present.
- Specification validation: PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260725_010825\QM5_10584_mql5-digvar.compile.log`
- Framework build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260725_010843.json`
- P1 artifact validation: PASS.
- Deterministic math parity: PASS. A fixed synthetic close series compared
  chronological source-indicator indexing with the EA's `CopyClose`
  shift mapping; maximum absolute difference was
  `1.0345502232667059e-11`.
- `git diff --check`: PASS for the recovery scope.

Artifact bindings:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `f54aa315ec24fd8d80f94e9a88e1fdb7fc719572108b8c5f79f26372ff06edc3` |
| EX5 | `b6bb33bae14f7a242b997ae6109953ec5ff16becb62c62e14773ecf6683c095a` |
| GBPJPY H8 setfile | `7d2b6d9995c09f4d56c946c4fb38759721153a63f77c9161682644d281c0137b` |
| Approved card | `943ce1328745f1e754b0fa4bddc6aa29a79fbd60aee13229e0f1280df20b2a6e` |

## Farm handoff

The existing failed work item was reactivated in place; no duplicate was
inserted. At handoff it was:

- phase: `Q02`
- status: `pending`
- verdict: `NULL`
- attempt count: `0`
- claimed by: `NULL`
- symbol / period: `GBPJPY.DWX` / `H8`

Its payload binds the MQ5, EX5, approved card, and GBPJPY setfile hashes above
and preserves the prior infrastructure verdict and evidence pointer.

`D:\QM\strategy_farm\state\FACTORY_OFF.flag` was authoritative. A read-only
slot scan found zero running factory terminals; the one visible terminal64
process was a pre-existing `T_Live` process outside this task. No smoke test,
backtest, dispatch, terminal control, AutoTrading action, or `T_Live` file
operation was performed.

No portfolio gate, deploy manifest, live setfile, or live authorization was
touched.
