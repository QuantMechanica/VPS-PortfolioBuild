# QM5_20057 Q02 timeout recovery

Date: 2026-07-24

Branch: `agents/board-advisor`

EA: `QM5_20057_xauxag-xmom1`

Farm claim: `5622a3db-ce61-4a91-9daa-215826922424`

## Selection

`QM5_20057` is an approved, low-frequency D1 market-neutral precious-metals
sleeve. It ranks XAU and XAG on one-month momentum and holds the winner long
and the loser short, rebalancing monthly. Its Strategy Card cites the
peer-reviewed commodity-momentum evidence of Fuertes, Miffre, and Rallis
(2010), and its backtest set is `RISK_FIXED` (`RISK_FIXED=1000`,
`RISK_PERCENT=0`).

The unclaimed approved build backlog did not contain a feasible higher-diversity
build: the non-index alternatives required unavailable external series
(IEF/BIL/DBC/lumber), while the only available forex item was already claimed.
`QM5_20057` had no downstream result and its sole Q02 attempt was blocked by
infrastructure, so it was selected under mission priority 2.

## Original failure and diagnosis

- Q02 work item: `96c14d4d-0a62-4935-85ec-dd75f570aafa`
- Parent task: `524f2762-aac1-4127-bd95-5ff0bf2828f4`
- Review predecessor: `a08d6327-cde7-46c6-9bff-8b599eabb4fa`
- Terminal: `T2`
- Result: `INFRA_FAIL`
- Reason classes: `TIMEOUT`, `METATESTER_HUNG`, `INCOMPLETE_RUNS`
- Run duration before timeout: 7,200 seconds
- Report size: 0 bytes
- Evidence:
  `D:\QM\reports\work_items\96c14d4d-0a62-4935-85ec-dd75f570aafa\QM5_20057\20260723_110605\summary.json`

The original source, binary, and setfile bindings matched their T2 deployments
and remained stable for the run. The runner detected neither an `OnInit`
failure nor a log bomb. Static inspection found bounded monthly `CopyRates`
work, and the same framework shape completes normally in the sibling
`QM5_20050` implementation. The failure is therefore classified as a
terminal/tester infrastructure timeout, not a strategy-mechanics or
initialization defect.

The checked-in source subsequently received telemetry-only corrections, so the
failed work item's binary binding was also stale relative to the current source.
No strategy mechanics were changed in this recovery.

## Strict rebuild and checks

The current source was rebuilt to produce a fresh binary and setfile binding.
The farm's deterministic artifact pump captured those two generated artifacts
in commit `1ff0d7005aeddecdbc1c3fa4cc2983b8cfe977dc`.

- Strict compile: PASS, 0 errors, 0 warnings
  - `C:\QM\repo\framework\build\compile\20260724_060027\QM5_20057_xauxag-xmom1.compile.log`
  - `D:\QM\reports\compile\20260724_060027\summary.csv`
- Framework build check: PASS, 0 failures, 0 warnings
  - `D:\QM\reports\framework\21\build_check_20260724_060043.json`
- MQ5 SHA-256:
  `8DDD5EF72263811B987DBCCAECD5E439975F643BD022EA9975C95AB347F6F2C6`
- EX5 SHA-256:
  `84D67859758AE84E27E44A11A74A630FDFE11E5EC71D92E7E7A61BD25DCA7300`
- Setfile SHA-256:
  `BA8D6E18904A8B3B03766677D7B5323FD8C8EB1744A1FE8AD9515FF2B7DC2A04`

## CPU-ceiling stop

At `2026-07-24T06:03:52Z`, the final `farmctl mt5-slots` check showed seven
active factory terminals: `T1`, `T2`, `T4`, `T6`, `T8`, `T9`, and `T10`.
This equals the documented backtest CPU ceiling. `T_Live` and the FTMO terminal
were excluded from that count.

Per the mission stop condition, no replacement Q02 work item was enqueued or
dispatched. The farm claim was released with the recovery marked ready for a
future paced agent to enqueue once active factory capacity is below the
ceiling. That replacement should avoid `T2`, the terminal of the timed-out run.

No manual tester, `T_Live`, AutoTrading, portfolio gate, or live manifest was
touched.
