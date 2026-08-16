# QM5_11661 diversity build — CPU-deferred Q01 smoke

- UTC date: 2026-08-16
- Branch: `agents/board-advisor`
- Farm claim: `c3507ac8-0628-4236-ae09-7a90710325ff`
- EA: `QM5_11661_pp-double-tb`
- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11661_pp-double-tb.md`
- Source: Keith Orange, PatternPy `detect_double_top_bottom`: <https://github.com/keithorange/PatternPy/blob/main/tradingpatterns/tradingpatterns.py>
- Outcome: `CPU_DEFERRED_Q01_SMOKE`

## Selection and collision control

The diversity-priority backlog was checked before editing. Higher-ranked new cards without deterministic EA/magic allocations were ineligible for a V5 build, and `QM5_21514` was already claimed by another paced agent. `QM5_11661` was the highest eligible, non-duplicate approved low-frequency structural card found for this slot. Its active registry allocation covers two FX symbols plus metal and European/US index portability:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `EURUSD.DWX` | 116610000 |
| 1 | `GBPUSD.DWX` | 116610001 |
| 2 | `XAUUSD.DWX` | 116610002 |
| 3 | `GDAXI.DWX` | 116610003 |
| 4 | `NDX.DWX` | 116610004 |

The farm claim was created atomically after checking for an existing open claim. The pre-claim database backup is `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11661_build_claim_20260816T190958Z.sqlite`.

## Implemented unit

- Preserved the approved H4 PatternPy double-top/double-bottom mechanics: closed-bar detection, next-bar entry, opposite-pattern/pattern-break/12-bar exits, ATR(14) 2.0x emergency stop, and one position per magic.
- Replaced direct `Bars`/`iHigh`/`iLow`/`iClose` use with bounded `QM_ReadBar` reads for closed shifts 1–4, resolving the prior `EA_FRAMEWORK_RAW_SERIES_CALL` Q01 failure.
- Restored current V5 skeleton wiring: MAE sampling before early returns, position management and exits before the central entry-only news gate, and zero-initialized entry requests.
- Copied the approved card into `docs/strategy_card.md` and revised `SPEC.md`.
- Generated canonical H4 backtest setfiles for all five registered symbols. Each setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the approved strategy defaults.

## Verification

- `skill_build_ea_guard.py`: `status=ok`; EA registry, magic registry, and EA directory checks all true.
- `validate_spec_doc.py`: `PASS`.
- `build_check.ps1`: `PASS`, 0 failures. Report: `D:\QM\reports\framework\21\build_check_20260816_191726.json`. Its single no-setfile warning preceded the prescribed setfile-generation step.
- Explicit `compile_one.ps1`: `PASS`, 0 errors, 0 warnings. Summary: `D:\QM\reports\compile\20260816_191812\summary.csv`.
- MQ5 SHA-256: `2DC368DB669414E080156149E8438898D01FF81A3BE58C46DA7BAF439B6CEC15`.
- EX5 SHA-256: `EAB440B715558BD032D89D411B17B83E521723B3A1342EA81BE9C2DE5D4ECE6C`.

Generated setfile SHA-256 values:

| Symbol | SHA-256 |
|---|---|
| `EURUSD.DWX` | `926484BCA5E70A25CBF63F36CD9D88528F80831AD1A569B35958823D58B15601` |
| `GBPUSD.DWX` | `2757F93CD24367A1639A2131A727DD4D26CCB4407CCB007D820599DE2ABB8B88` |
| `XAUUSD.DWX` | `C4CEDBE263E442B945A5824984AEA58ACF1374125ABE8DC127E570BD196C42FC` |
| `GDAXI.DWX` | `1DB9A193E463A4B354364F53FCB0CAEAC1064BF037C93C85C2DE030E4EC84002` |
| `NDX.DWX` | `0F34187DACDBA6CF3DC33EB78F97A29F100A47796314B03AA3E145CB90325604` |

## Capacity stop and handoff

Immediately before the required single smoke, five one-second total-CPU samples were `100,100,100,100,100` percent. The farm process scan at `2026-08-16T19:19:33Z` showed nine active pipeline terminals (`T2` through `T10`, excluding `T1`). This met the mission's backtest CPU-ceiling stop condition.

No smoke was started, no retry was attempted, and no Q02 work item was enqueued. When capacity is available, the next operator should run exactly one 2024 `EURUSD.DWX` H4 smoke with `-MinTrades 1 -SmokeMode` and the generated EURUSD setfile. Q02 fanout for all five symbols is authorized only after that smoke passes.

No portfolio-gate, `T_Live`, AutoTrading, or live-manifest state was touched.
