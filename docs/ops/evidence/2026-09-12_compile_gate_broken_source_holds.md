# Compile-gate refusal holds and 24-hour cluster classification

**Task:** `57fc8b42-361c-4d9e-8533-4a65047c3a6a`  
**Evidence time:** 2026-09-12T09:58:20Z  
**Disposition:** REVIEW -- Default-OFF implementation complete; activation is an orchestrator staggered-reload decision.

## Finding

The 12 `compile_gate:COMPILE_FAILED` terminal rows updated since
2026-09-11T09:00:00Z are one infrastructure class, not twelve demonstrated
source-code failures. Every immutable compile summary reports
`reason_class=INCLUDE_MIRROR_REFUSED` and `errors=-1`: the dispatch-time compile
gate attempted `compile_ea.py` without a governed terminal claim / `COMPILE_EA`
work item, so the include-mirror writer guard correctly refused it. Existing
failed rows and their verdict evidence were not changed.

The task title named eight EAs. The exact database query found four additional
EAs in the same 24-hour class (`QM5_39006`, `QM5_39007`, `QM5_41005`, and
`QM5_41006`).

| EA | Failed row | Phase/symbol | Updated UTC | Latest governed compile evidence | Rework state | Cause |
|---|---|---|---|---|---|---|
| QM5_10214 | `423c3b88` | Q02 / XAUUSD | 09-11 12:12:55 | none | none found | INCLUDE_MIRROR_REFUSED |
| QM5_10216 | `5d9881df` | Q02 / XAUUSD | 09-11 16:23:28 | none | pending Q04 `8cc6401e` | INCLUDE_MIRROR_REFUSED |
| QM5_10505 | `7f4fb7d4` | Q02 / XAUUSD | 09-12 06:17:02 | none | TODO `b76e30fd` (OnInit recovery) | INCLUDE_MIRROR_REFUSED |
| QM5_11533 | `676f9094` | Q02 / EURUSD | 09-12 06:59:19 | none | none found | INCLUDE_MIRROR_REFUSED |
| QM5_1408 | `63521f6c` | Q02 / EURUSD | 09-12 06:54:13 | none | none found | INCLUDE_MIRROR_REFUSED |
| QM5_1579 | `490b763c` | Q02 / XAUUSD | 09-11 22:37:04 | none | none found | INCLUDE_MIRROR_REFUSED |
| QM5_1624 | `4c09abe7` | Q02 / EURUSD | 09-12 06:54:27 | none | none found | INCLUDE_MIRROR_REFUSED |
| QM5_39005 | `dc6ea025` | Q02 / EURUSD | 09-12 06:59:55 | pending `COMPILE_EA` `10749d8d`; older `fadbaff1` = CANDIDATE_RECHECK_REFUSED | compile pending | INCLUDE_MIRROR_REFUSED |
| QM5_39006 | `c82a513a` | Q02 / EURUSD | 09-12 06:57:10 | none | none found | INCLUDE_MIRROR_REFUSED |
| QM5_39007 | `4921484d` | Q02 / EURUSD | 09-12 06:56:53 | none | none found | INCLUDE_MIRROR_REFUSED |
| QM5_41005 | `1ff79936` | Q02 / EURUSD | 09-12 06:57:27 | none | none found | INCLUDE_MIRROR_REFUSED |
| QM5_41006 | `0b344d2a` | Q02 / XAUUSD | 09-12 07:01:57 | none | none found | INCLUDE_MIRROR_REFUSED |

Only `QM5_10216` currently has a pending Q02/Q03/Q04 row, and it is Q04. The
other eleven historic refusal rows are terminal evidence. They must remain
untouched; after a valid compile, any retry must use the existing governed
append-only rerun mechanism.

## Default-OFF control

`farmctl.py` now defines the exact hold `COMPILE_GATE_BROKEN_SOURCE`, activated
only when `QM_COMPILE_GATE_HOLD_ENABLED=1`.

When enabled:

1. A stale/missing EX5 is classified `COMPILE_EA_REQUIRED`; dispatch does not
   invoke MetaEditor or the include-mirror writer inline.
2. A compile-gate spawn refusal restores the caller's pre-claim payload and
   evidence pointer, retracts its terminal ledger claim, returns the row to
   `pending` without a verdict, and installs the exact hold on all pending
   Q02/Q03/Q04 rows for the same EA.
3. At the next dispatch, release is permitted only by a newer same-EA
   `COMPILE_EA` row with `COMPILE_OK` and an authenticated immutable
   `qm.compile-ea-evidence/v1` receipt whose work-item and EA identities match
   and whose compile and build checks both say PASS.
4. Hold release is compare-and-swap and evented. It never changes a verdict.

When the flag is absent (current production state), legacy behavior is
unchanged.

## Verification and dry run

- `python -m pytest tools/strategy_farm/tests/test_compile_gate_holds.py tools/strategy_farm/tests/test_phase_runner_process_lineage.py tools/strategy_farm/tests/test_q09_live_news_diagnostic.py -q`
  -- **32 passed**.
- `python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/tests/test_compile_gate_holds.py`
  -- PASS.
- Production dry run, flag absent:
  `enabled=false`, `apply=false`, `held_count=0`, `release_ready_count=0`,
  `released_count=0`.

No production hold, verdict, row, terminal, or archive was mutated. Activation
and any historic append-only reruns remain with the orchestrator.
