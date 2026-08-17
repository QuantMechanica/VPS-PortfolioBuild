# QM5_32008 FX triplet build and Q02 handoff — 2026-08-17

## Outcome

Built the approved `QM5_32008_euro-triplet-statistical-arbitrage-eurostable`
card as one logical three-leg M15 basket and handed exactly one pending Q02
work item to the farm. This adds an FX market-neutral candidate rather than
another index, metal, or XNG build.

No smoke backtest was started. At the post-compile capacity check, T1–T7 were
already running farm work and five total-CPU samples averaged 99.7%, so the
first MT5 execution was deferred to the paced Q02 worker path.

## Farm coordination

- Build task: `478c7e37-4692-4e7f-a244-24ec443a9596`
- Claim: `codex:agents/board-advisor` on branch `agents/board-advisor`
- Build result: `D:\QM\strategy_farm\artifacts\builds\478c7e37-4692-4e7f-a244-24ec443a9596.json`
- Build task terminal status: `done`
- Q02 work item: `54aea8ef-3a61-4eb7-a0db-f176a408e7cc`
- Q02 identity: `QM5_32008_EUR_TRIPLET_STATARB_M15`, status `pending`, attempt 0
- Q02 setfile: one logical basket preset; no per-leg fan-out

The initial auto-enqueue exposed a timeframe-token ambiguity: the generic
physical-set parser read the first token in the suffix `_M15_M15_backtest.set`
as a symbol and rejected it as non-DWX. The handoff now binds an exact basket
manifest/setfile match before generic filename parsing. The repair is covered
by an M15 regression test and the same canonical enqueue function created the
single pending row above.

## Strategy and risk contract

- Residual: `ln(EURUSD.DWX) - ln(EURGBP.DWX) - ln(GBPUSD.DWX)`.
- Signal data: aligned, closed M15 bars only; newest residual is scored against
  the strictly preceding 60 observations.
- Entry: `z <= -2.2` buys EURUSD and sells EURGBP/GBPUSD; `z >= 2.2` reverses
  the package.
- Exit/stop: complete-package close at `abs(z) <= 0.2` or `abs(z) >= 3.8`.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, equal one-third allocation across
  fixed unit coefficients.
- Safeguards: partial-package rollback, orphan-leg flatten, rollover/spread
  entry gates, account drawdown caps, Friday package close, news entry-only
  ordering, and Q08 MAE tracking as the first `OnTick` action.
- No ML, learned weights, banned indicators, grids, averaging, pyramiding,
  T_Live changes, AutoTrading changes, portfolio-gate changes, or live preset.

The approved card specifies a package z-stop but not a leg-level broker-price
mapping. `SPEC.md` records the conservative implementation assumption: each
leg receives the full remaining residual log-distance as a server-side
catastrophe rail, while closed-bar z-state governs correlated package exits.

## Verification

- Static build preflight: PASS, 0 failures, 0 warnings.
- Strict compile/build check: PASS, 0 errors, 0 warnings.
- Build report: `D:\QM\reports\framework\21\build_check_20260817_152150.json`.
- SPEC validator: 1 PASS, 0 FAIL.
- Basket enqueue test module: `17 passed`; related farm handoff suite:
  `53 passed, 4 subtests passed`.
- Magic resolver dry-run: 17,296 rows kept, 0 dropped; registry hash matched.
- Farm DB verification: exactly one `QM5_32008` work item, `Q02_pending=1`.

## Artifact hashes

| Artifact | SHA-256 |
|---|---|
| MQ5 | `553a1f27762325bea01d2a1960d0a2ea5d2bccef1eaa2e8667a14bc4fcee4714` |
| EX5 | `e47be317a8e3a288e9574512950fa98517fd36ae8b507519ec4161a85db575b8` |
| Logical Q02 setfile | `48b5a16197483ed238f1950d80e9c213a3df6d20c1a2c0ccee53b75b9158645f` |
| Physical host smoke setfile | `7900ba24a40fcfd4e049cb1e054bb32a4a0c4fc23045fa8e9c579c9f11a72670` |
