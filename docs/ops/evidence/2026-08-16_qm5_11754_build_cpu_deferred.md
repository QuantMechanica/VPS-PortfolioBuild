# QM5_11754 diversity build — CPU-deferred Q01 smoke

- UTC date: 2026-08-16
- Branch: `agents/board-advisor`
- Farm claim: `c46de7c2-9a6c-4a82-a1cf-85d9eec4231c`
- EA: `QM5_11754_continuation-ema50-williamsr-mtf`
- Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11754_continuation-ema50-williamsr-mtf.md`
- Source: Cecil Robles, "The Continuation Method," in *6 Simple Strategies for Trading Forex*, pages 35–54, circa 2015
- Outcome: `CPU_DEFERRED_Q01_SMOKE`

## Selection and collision control

The diversity-priority backlog was ranked before editing. `QM5_11754` was the
highest-diversity eligible approved card with complete deterministic registry
allocation and no exact open claim. It adds the same low-frequency H4
continuation mechanism across six FX majors, while the current Q08 survivors
are concentrated in indices, metals, and energy.

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `EURUSD.DWX` | 117540000 |
| 1 | `GBPUSD.DWX` | 117540001 |
| 2 | `USDJPY.DWX` | 117540002 |
| 3 | `USDCHF.DWX` | 117540003 |
| 4 | `AUDUSD.DWX` | 117540004 |
| 5 | `USDCAD.DWX` | 117540005 |

The farm claim was created atomically after exact EA/card/slug/path collision
checks. The pre-claim database backup is
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11754_build_claim_20260816T200530Z.sqlite`.

## Implemented unit

- Preserved the approved D1 EMA(50) trend, H4 EMA(50) pullback, and H4 Williams
  %R(14) re-entry rules, with signal-bar structure stops and a 5x ATR(14) hard
  target inside the card's authorized 4–7x range.
- Implemented the card's explicit trailing state: reaching 2R permanently arms
  the SMA(5) trail for the current ticket; two completed closes beyond SMA(5)
  then tighten the stop to the more conservative of those closes.
- Replaced the prior direct `iClose`/`iHigh`/`iLow` calls with `QM_ReadBar` and
  cached closed-bar SMA state, resolving the exhausted build's
  `EA_FRAMEWORK_RAW_SERIES_CALL` failure without adding per-tick indicator work.
- Restored current V5 lifecycle wiring: MAE sampling first, kill/Friday guards,
  management and exits before the entry-only news gate, one consumed new-bar
  event, equity streaming, and a zero-initialized entry request.
- Copied the approved card exactly into `docs/strategy_card.md`, revised
  `SPEC.md`, and generated canonical H4 backtest setfiles for all six symbols.
  Every set uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Verification

- `skill_build_ea_guard.py`: `status=ok`; EA registry, magic registry, and EA
  directory checks all true.
- `validate_build_guardrails.py`: `PASS`, with no findings.
- `validate_spec_doc.py`: `PASS`, 1/1.
- Strict framework/compile gate: `PASS`, 0 errors and 0 warnings from
  MetaEditor. Report:
  `D:\QM\reports\framework\21\build_check_20260816_201732.json`.
- Final post-setfile framework gate: `PASS`, 0 failures, 0 warnings. Report:
  `D:\QM\reports\framework\21\build_check_20260816_201832.json`.
- Compile summary: `D:\QM\reports\compile\20260816_201732\summary.csv`.
- MQ5 SHA-256: `9DA93F216C687D1D710C3F86DD11165A750ECC7009D30B4939C63D6158B0ABC4`.
- EX5 SHA-256: `EFB89AC8E535789A81274580FC62CA525C3FB67119BEFF40B9231974A1BA2F03`.
- Approved-card copy: exact SHA-256 match,
  `9AD5A703FD4CA230EC11FE63B2D08978B9EF11B271C939A2A0ACF02355225E83`.
- Farm build result:
  `D:\QM\strategy_farm\artifacts\builds\c46de7c2-9a6c-4a82-a1cf-85d9eec4231c.json`.

Final setfile SHA-256 values:

| Symbol | SHA-256 |
|---|---|
| `EURUSD.DWX` | `1AFD4B6513F45E0A8508E2BB66205EC9958D4B1157B1D2107B44BABF36BB92B4` |
| `GBPUSD.DWX` | `B416BC9980EC5AC96EF6B61C1B2F967A1B66FED627AF2E07DED64D196FB09E39` |
| `USDJPY.DWX` | `8F7B07F0F54C6F96262EE480F5B9C97A3250E1499EC6E022272CC2C09443D098` |
| `USDCHF.DWX` | `B80E0115D5023FE53418DC1AC7284366D7761503D620EE1C3BCC4C96B4130795` |
| `AUDUSD.DWX` | `D8D525945EE1A85EC59BB83A42A7C3FA8FF980A72C12D75FB900B3147017544B` |
| `USDCAD.DWX` | `DF22BB3374FCA0E8E62C882DBCF46D65E4E1C683AABCFCDB16413277D19E73FF` |

## Card inconsistency retained for review

The authorization-bearing frontmatter says `g0_status: APPROVED` and
`r1_track_record: PASS`, but the card body still says `R1 Track Record: FAIL`
and its pipeline table says `G0: PENDING`. The frontmatter also retains stale
`card_body_incomplete` metadata despite the cited source and target symbols
being present. The build followed the OWNER-approved frontmatter and did not
rewrite the durable source card; downstream review must resolve this conflict
before treating R1 as independently revalidated.

## Capacity stop and handoff

Immediately before the required single smoke, five one-second total-CPU samples
were `100, 100, 100, 100, 99.1` percent. The farm slot scan at
`2026-08-16T20:20:46Z` showed active Q02 terminal runs on T1, T2, T3, T5, T7,
T9, and T10, with terminal workers present for all T1–T10 slots. This met the
mission's backtest CPU-ceiling stop condition.

No smoke was started, no retry was attempted, and no Q02 work item was
enqueued. When capacity is available, the next operator should run exactly one
2024 `EURUSD.DWX` H4 smoke using `-MinTrades 1 -SmokeMode` and the generated
EURUSD setfile. Q02 fanout for all six symbols is authorized only after that
smoke passes and the card's R1 status conflict is acknowledged by review.

No portfolio-gate, `T_Live`, AutoTrading, deploy-manifest, or live-manifest
state was touched.
