# QM5_10571 FX Magic-Slot Repair And Q02 Requeue

Date: 2026-07-11
Agent: codex-board-advisor
Branch: agents/board-advisor

## Outcome

Recovered the approved H4 PriceChannel Stop strategy from a deterministic Q02
`ONINIT_FAILED` loop and placed three diverse FX cases back at Q02. The old
terminal failures were claimed before repair, and their replacements were
created through the farm's canonical Q02 enqueue path while the factory was
off.

| Symbol | Replacement Q02 work item | Status |
|---|---|---|
| `EURUSD.DWX` | `dea9a42b-a694-4c29-ad40-b023ab6a06ef` | `pending` |
| `GBPUSD.DWX` | `74fd1031-eb98-4d45-935d-90539674066c` | `pending` |
| `EURJPY.DWX` | `e809c752-5e9b-42b9-bc53-a744b8a45007` | `pending` |

`XAUUSD.DWX` was deliberately left to the farm's staged deferral sidecar
because metals are already saturated in the surviving book. It was not added
as a fourth active Q02 row.

## Selection And Diversity

The approved-card build preflight ruled out the two higher-diversity backlog
cards: `QM5_1457` requires unavailable rates/bond inputs, and `QM5_1459`
requires unavailable lumber and IEF inputs and has an unresolved data gate.
The next buildable card, `QM5_13031`, targets the already saturated XAU/index
class. The next mission priority was therefore used: repair a built but
infra-stuck strategy on three FX pairs.

`QM5_10571_mql5-pchan-stop` is an approved, structural, low-frequency H4
trend-change strategy sourced from Nikolay Kositsin's MQL5 CodeBase
`Exp_PriceChannel_Stop` implementation. Its card passes R1-R4, forbids ML,
grid, and martingale behavior, and specifies `RISK_FIXED = 1000`.

Approved card:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_10571_mql5-pchan-stop.md`

## Root Cause And Repair

The EA maps its four target symbols to slots `0..3`, and the canonical
setfiles passed those same offsets. The registry instead assigned slots
`100..103` and magics `105710100..105710103`. During framework initialization,
`QM_MagicChecked(ea_id, slot, _Symbol)` could not resolve the supplied slot and
symbol pair, producing the repeated Q02 `ONINIT_FAILED` results on every target
symbol.

The registry was corrected to the EA's actual symbol mapping:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `EURUSD.DWX` | 105710000 |
| 1 | `GBPUSD.DWX` | 105710001 |
| 2 | `EURJPY.DWX` | 105710002 |
| 3 | `XAUUSD.DWX` | 105710003 |

After the registry correction, the generated magic resolver was refreshed,
all four H4 backtest setfiles were regenerated with their matching slot and
`RISK_FIXED=1000`, the missing `SPEC.md` was restored, and the EA was compiled
strictly to a fresh EX5.

Artifact SHA256 values:

| Artifact | SHA256 |
|---|---|
| MQ5 source | `D701F60C19188476C683A7779A75AF83B68BF902F134F77083E10FBC12C9C815` |
| compiled EX5 | `6E760DFBCDCC512F03E01DAB04A1471A1DD9C660BB3EF181433111809FF660E5` |
| magic registry | `93FDBCF79C0950EEC61D9A86C17DEA3FA227353432E05CC9AE33071CA1EFAF8D` |
| generated resolver | `28DA6B7766F577618977C81A58E26ED3FB3681F9FA8AFFC0F8636EAEE44C2796` |

## Validation

- SPEC validation: `PASS` (`1` passed, `0` failed).
- Build check: `PASS`, `0` failures and `0` warnings.
  Report: `D:/QM/reports/framework/21/build_check_20260711_013846.json`.
- Strict compile: `PASS`, `0` errors and `0` warnings.
  Log:
  `C:/QM/repo/framework/build/compile/20260711_013859/QM5_10571_mql5-pchan-stop.compile.log`.
- One bounded EURUSD H4 2024 smoke invocation: `PASS`; both deterministic
  Model-4 runs completed with `75` trades, and
  `oninit_failure_detected=false`.
  Summary: `D:/QM/reports/smoke/QM5_10571/20260711_013949/summary.json`.

The smoke's strategy economics are not promoted by this infra repair; the
paced Q02 jobs remain responsible for the funnel verdict.

## Farm Coordination

Farm database: `D:/QM/strategy_farm/state/farm_state.sqlite`

Claimant:
`codex:agents/board-advisor:qm5-10571:20260711T013548Z`

Claimed terminal rows:

| Symbol | Prior work item |
|---|---|
| `EURJPY.DWX` | `646139ff-4534-424a-933e-927c43c7b8b6` |
| `EURUSD.DWX` | `49313201-9fcc-4eef-b418-cebcdc35507a` |
| `GBPUSD.DWX` | `87683e9f-7204-413f-8751-fea0ab219fde` |
| `XAUUSD.DWX` | `22e5a9d7-1383-4cf9-be62-adc0bce72c56` |

The claimed rows were marked completed with their replacement/defer outcome.
The queue mutation used build task tag
`qm5-10571-magic-repair-20260711T014339Z`.

Backups:

- Before claim/repair:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_10571_magic_repair_20260711T013548Z.sqlite`
- Before Q02 requeue:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_10571_q02_requeue_20260711T014339Z.sqlite`
- Deferred-symbol sidecar:
  `D:/QM/strategy_farm/state/q02_deferred_symbols_before_qm5_10571_20260711T014339Z.json`

The factory-off flag was present, so no manual Q02 dispatch was attempted.
No portfolio gate, `T_Live` manifest, `T_Live` terminal, or AutoTrading state
was touched.
