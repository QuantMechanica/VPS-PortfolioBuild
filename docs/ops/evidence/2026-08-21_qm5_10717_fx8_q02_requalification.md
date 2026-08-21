# QM5_10717 FX8 logical-basket Q02 requalification

Date: 2026-08-21  
Branch: `agents/board-advisor`  
Farm task: `299db612-8a6b-4040-9725-8f4f1f42344b`

## Outcome

`QM5_10717_edgelab-xsec-fx-momentum` was rebuilt and enqueued as one logical
`FX8_BASKET_D1` Q02 work item. This is a diverse, low-frequency, 28-pair FX
cross-sectional momentum sleeve sourced from Menkhoff et al., *Journal of
Financial Economics* (2012). It uses the owner-ratified EURUSD.DWX/D1 host and
does not fan out into per-pair Q02 jobs.

Fresh approved diversity builds with the highest backlog priority were already
in flight (`QM5_36005`, `QM5_36007`, and `QM5_41002`), so this unit followed
mission priority 2: recover a diverse built EA stuck at Q02 for infrastructure
reasons.

No Q02 result is claimed here. The new work item is queued for the normal farm
worker and gate process.

## Diagnosis and repair

The preserved source work item
`221dba0e-3ed3-490b-8cf0-99345b7b4407` is a legacy `backtest_p2` logical-basket
row that failed with `INFRA_FAIL` during the earlier shared custom-history
contention incident. The current worker already provides private custom-history
isolation, single-active-multisymbol serialization, full archive admission, and
heavy-memory reservation, but `seed-fresh-q02` rejected the legacy work-item
kind. In addition, 26 stale physical-pair recovery rows were pending despite the
owner decision requiring exactly one logical basket job.

`tools/strategy_farm/farmctl.py` now permits a legacy `backtest_p2` source only
when its payload proves a valid logical-basket identity. In the same database
transaction it:

- refuses an existing logical duplicate or any active sibling;
- refuses unexpected or malformed sibling rows;
- supersedes only pending, unclaimed rows whose symbols are declared basket
  members; and
- inserts exactly one hash-bound logical Q02 seed.

The 26 stale physical rows were retained for audit and transitioned to
`done / SUPERSEDED_BY_LOGICAL_BASKET`. The original failed logical source row was
not modified.

## Build and validation evidence

- Implementation commit: `d8ba179a6c97ccdfb7fd11ba9a385918476fe35f`
- EX5 SHA-256: `72c118b0a30fc32d0b6bcf921a632bfd8175048431b0547b87f249b841053f0a`
- MQ5 SHA-256: `1fa4d2fdceaba1fb727ca5d8962964be400490a9546fcb77a8b8579d345e9f7e`
- Logical setfile SHA-256: `4d34f1a3ab50cee7154f979977428e8462b5a9d3ab0f84c41be3b453dc81087c`
- Compile: PASS, 0 errors, 0 warnings
- Strict build check: PASS, 0 failures, 0 warnings
- Farm enqueue tests: 42 passed
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Archive admission: ACTIVE for all 28 symbols, 3024 rows
- Archive manifest SHA-256:
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`
- Archive activation SHA-256:
  `61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`
- Compile log:
  `C:/QM/repo/framework/build/compile/20260821_150328/QM5_10717_edgelab-xsec-fx-momentum.compile.log`
- Strict build report:
  `D:/QM/reports/framework/21/build_check_20260821_150328.json`

## Farm handoff

New Q02 work item: `7dd70134-a2a0-4ecf-a706-5f4609a094be`

- kind / phase: `backtest / Q02`
- logical symbol: `FX8_BASKET_D1`
- host: `EURUSD.DWX / D1`
- initial state: `pending`, unclaimed, attempt 0
- date range: 2018-07-02 through 2025-12-31
- timeout: 450 minutes
- expected artifact hashes: bound to the committed EX5, MQ5, and logical setfile

After the transaction, this is the only open Q02/P2 work item for `QM5_10717`.

## Resource and safety notes

The final pre-enqueue CPU sample averaged approximately 61.0% and peaked at
85.2%; the 97% backtest CPU ceiling was not reached. Commit-memory headroom was
well above the multisymbol reservation requirement during preflight. No terminal
was manually reserved or started. `T_Live`, AutoTrading, the portfolio gate, and
the live manifest were not touched.
