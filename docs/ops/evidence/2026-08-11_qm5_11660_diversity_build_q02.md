# QM5_11660 diversity build and Q02 handoff — 2026-08-11

## Outcome

Built `QM5_11660_pp-wedge` as the highest-scoring fresh, registry-complete,
approved structural card remaining after the official farm priority scan and
claim-guard filtering. The EA adds two FX hosts (`EURUSD.DWX`, `GBPUSD.DWX`)
alongside metal/index portability hosts, compiles cleanly, and has entered Q02.

This is one Q01 build/Q02-handoff unit. No pipeline phase was run locally.

## Selection and coordination

- Official scorer: 3,174 cards scored, 712 unbuilt.
- Selected card score: `12.05`; approved R1–R4, H4, expected 32 trades/year/symbol.
- Source: Keith Orange's PatternPy `detect_wedge` implementation.
- Build task: `7960bf7e-034d-4038-905a-f96d66feb517`.
- Agent task: `574b5036-996f-4b2a-bb1c-44ad9bf94518`.
- Claim owner: `codex:agents/board-advisor`.
- Claim key: `manual:codex:agents/board-advisor:QM5_11660:q01-build-q02-handoff:2026-08-11T08:55:44+00:00`.
- Pre-claim backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11660_build_claim_20260811T085458Z.sqlite`.
- Pre-record backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11660_record_build_20260811T090745Z.sqlite` (`PRAGMA quick_check=ok`).

The prior tracked `.mq5/.ex5` pair was an orphan outside the governed farm: it
had no SPEC or setfiles and replaced the cited rolling detector with a custom
pivot/convergence/breakout reversal. The Q01 rebuild removes that semantic
drift and implements the approved card literally.

## Mechanisation

- `Wedge Up`: PatternPy rolling-high/rolling-low mask plus positive high and
  low trends over the source window; enter long at the next H4 open.
- `Wedge Down`: the source's inverse mask plus negative high and low trends;
  enter short at the next H4 open.
- Exit on the opposite label, a completed close beyond the immediately prior
  bar's adverse extreme, or 12 H4 bars.
- Emergency stop: `2.0 * ATR(14)` through the framework stop helper.
- One position per registered magic; no TP, extra confirmation, grid,
  martingale, banned indicator, or ML mechanic.
- Direct OHLC reads are bounded, explicitly marked structural exceptions, and
  run only after `QM_IsNewBar()` accepts a completed bar.
- Entry requests explicitly bind `req.symbol_slot = qm_magic_slot_offset`, so
  every non-zero host slot resolves its own registered symbol/magic pair.

The five previously allocated registry rows were promoted from `reserved` to
`active`; no EA ID, slot, magic, or symbol was newly allocated.

## Artifacts

- EA: `framework/EAs/QM5_11660_pp-wedge/QM5_11660_pp-wedge.mq5`
- Binary: `framework/EAs/QM5_11660_pp-wedge/QM5_11660_pp-wedge.ex5`
- Spec: `framework/EAs/QM5_11660_pp-wedge/SPEC.md`
- Durable approved-card copy: `framework/EAs/QM5_11660_pp-wedge/docs/strategy_card.md`
- Backtest sets: five files under `framework/EAs/QM5_11660_pp-wedge/sets/`
- Farm result: `D:\QM\strategy_farm\artifacts\builds\7960bf7e-034d-4038-905a-f96d66feb517.json`

## Verification

| Check | Result |
|---|---|
| `skill_build_ea_guard.py` | PASS |
| `validate_spec_doc.py` | PASS, 1/1 |
| Static framework gate before compile | PASS, 0 failures, 0 warnings |
| One-pass strict MetaEditor compile | PASS, 0 errors, 0 warnings |
| Final framework/setfile gate | PASS, 0 failures, 0 warnings |
| EX5 SHA-256 | `5db350ac57411c2b6d81987db4e2f5ec8598eabb05c058f2df6da2dcfe70610e` |
| Farm DB pre-record backup | `quick_check=ok` |

Every generated setfile uses H4, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and its
registered slot:

| Symbol | Slot | Magic |
|---|---:|---:|
| `EURUSD.DWX` | 0 | 116600000 |
| `GBPUSD.DWX` | 1 | 116600001 |
| `XAUUSD.DWX` | 2 | 116600002 |
| `GDAXI.DWX` | 3 | 116600003 |
| `NDX.DWX` | 4 | 116600004 |

## Q02 handoff

`record-build` completed the build task and created a diverse stage-one wave:

| Work item | Symbol | State observed after enqueue |
|---|---|---|
| `54370a3d-8226-493a-88e5-2f8aac693321` | `EURUSD.DWX` | pending |
| `aae1ae40-b283-4b08-a635-0258d8a06060` | `GDAXI.DWX` | active on T2 |
| `eefc00ee-6c57-4cb6-9fe9-4e0a14a6e047` | `XAUUSD.DWX` | pending |

`GBPUSD.DWX` and `NDX.DWX` are preserved in the canonical staged-deferred
sidecar with `priority_track=true`, build task linkage, and cohort size 5.

No Q01 smoke was launched. At the dispatch check, four `metatester64` workers
were already active on T3, T4, T6, and T8. The build skill is build-only, so
the farm result uses sanctioned `deferred_p2_smoke` and Q02 owns runtime
evidence. Capacity evidence is stored in `smoke_capacity_evidence`; the
recorded build has an empty `blocked_reason`, no `fail_code`, and
`needs_p2_smoke_via_pump=true` so normal health/review routing remains clean.

## Safety boundary

- No `T_Live` file, manifest, or terminal was touched.
- AutoTrading was not toggled.
- No portfolio gate or deploy manifest was changed.
- No local backtest or tester process was started.
- This evidence and the implementation are committed only on
  `agents/board-advisor`.
