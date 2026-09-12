# Paced Fleet Diversity — CPU Ceiling Stop

Date: 2026-09-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `NO CLAIM; NO BUILD; NO COMPILE RELEASE; NO Q02 ENQUEUE — BACKTEST CPU CEILING`

## Diversity and collision preflight

The canonical farm database at
`D:/QM/strategy_farm/state/farm_state.sqlite` and the approved build backlog
were read before any mutation.

- No unclaimed, unblocked `build_ea` task simultaneously had no EX5 and no
  existing pipeline work item. Therefore there was no clean priority-1
  greenfield diversity build to claim.
- `QM5_12351_alp-ema12-26` has no EX5, but already has pending governed
  `COMPILE_EA` work item `92797bae-0f0d-45cb-872d-6f0bcccb258d`; duplicating
  that compile was refused.
- The structural FX candidates `QM5_32007_london-fix-wm-reuters-currency-drift`
  and `QM5_41011_tokyo-london-bank-flow-handover` are not infrastructure-stuck:
  both completed Q02 PASS and subsequently received economic Q04 FAIL verdicts.
- The highest-value ready continuation is the already-claimed diverse FX
  infrastructure repair `19a2692f-020e-4d5c-a0fd-76011c9b51f4` for
  `QM5_10038_ff-4x25ema-mtf-h4`. Its three current-binary Q02 requalification
  dry runs are eligible for `NZDUSD.DWX`, `USDCAD.DWX`, and `USDCHF.DWX`, but
  its durable next-action contract requires execution only below the CPU
  ceiling.

No new claim was taken because the only actionable diversity unit was already
claimed by `codex:agents/board-advisor` and the capacity gate below refused its
continuation.

## Capacity evidence

At `2026-09-12T11:33:07Z`, five consecutive whole-host processor samples were:

```text
83, 100, 99, 96, 97 percent
```

Average load was `95.0%`; peak load was `100.0%`. The binding ceiling is
`97.0%`, so the observed peak hit the stop condition.

The immediately following canonical `farmctl.py mt5-slots` census found four
governed tester runs active:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| T4 | `QM5_41322` | `OPT_CENSUS` | `XAUUSD.DWX` |
| T6 | `QM5_41323` | `OPT_CENSUS` | `NDX.DWX` |
| T8 | `QM5_10485` | `Q04` | `XAUUSD.DWX` |
| T9 | `QM5_41398` | `OPT_CENSUS` | `USDJPY.DWX` |

The census reported no duplicate terminal workers and no orphaned terminal
processes. `T_Live` and the FTMO terminal appeared only in the read-only
process census and were not accessed or changed.

## Safety and continuation

This run did not create or alter a farm claim, build task, registry row, magic
resolver, EA source, EX5, setfile, compile work item, backtest work item,
portfolio gate, deploy manifest, `T_Live` state, or AutoTrading state.

On the next below-ceiling paced run, recheck the claim and work-item identities
for `QM5_10038`. If unchanged, repeat the mandatory framework-input-pin audit
and the governed requalification dry runs, then apply the exact three
current-binary Q02 successors. Do not create another compile row.
