# QM5_20099 WTI Same-Calendar Sign — Build And Q02 Enqueue

Date: 2026-07-24
Branch: `agents/board-advisor`

## Scope

One new low-frequency WTI carrier was extracted from the complete,
OWNER-approved Keloharju, Linnainmaa, and Nyberg (2016) source packet. At each
broker-month boundary it averages WTI's completed return for the same calendar
month over the preceding ten years, requires at least five observations, and
trades the average's sign until the next month boundary.

This is not the existing `QM5_13115_energy-samecal` two-leg XTI/XNG
relative-rank basket. It compares WTI's own same-month mean with zero and owns
only one `XTIUSD.DWX` position. It is also distinct from fixed month-direction
rules and recent-return WTI trend carriers.

No profitability or decorrelation result is claimed before the governed
pipeline evidence.

## Build evidence

- EA ID and slug: `QM5_20099_wti-samecal`.
- Strategy ID: `KELOHARJU-RETSEAS-2016_XTI_S02`.
- Magic: `200990000`, slot 0, `XTIUSD.DWX`.
- Card schema lint: PASS; no missing sections or prohibited ML hits.
- G0 card lint: PASS.
- Build prerequisite guard: PASS.
- SPEC validator: PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
- Framework build check: PASS, 0 failures, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260724_113212\QM5_20099_wti-samecal.compile.log`.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260724_113212.json`.
- MQ5 SHA256:
  `29789CA132A428F0D90346B42D90F848051786C7DA1C2C81E374CB2309B8A22E`.
- EX5 SHA256:
  `BB1BE8E4828761974138D8CB0038A22C79BB0D15CB03B9817D635747B25D301B`.
- Backtest setfile SHA256:
  `575F25B5E76FE40E6E2C48BD2BF79ADFF316886DEA9D939CE6B6D5261F154D27`.
- Setfile build hash:
  `7d905c7eec1610a1c0a59996cdcf14a7575f12c61b018b5eeaef9fb1b69cf003`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

The global strict resolver dry-run still reports the pre-existing missing
legacy EA directories `1001`, `1015`, and `1016`; the scoped 20099 guard
passes and the generated resolver contains `200990000`.

## Paced Q02 enqueue

At `2026-07-24T11:33:48+00:00`, `farmctl mt5-slots` showed five active
factory terminals: `T2`, `T3`, `T6`, `T8`, and `T10`. This was below the
paced seven-factory-terminal ceiling. The separate T_Live and FTMO GUI
processes were excluded and were not touched.

A target-scoped dry-run selected exactly one new row. The applied sweep was
restricted to `QM5_20099`, `XTIUSD.DWX`, with stranded retry fan-out disabled.

- Work item: `cc304262-dbfa-410d-b273-7318751374e5`.
- Phase: `Q02`.
- State after insertion: `pending`, unclaimed.
- Duplicate guard: exactly one work item exists for `QM5_20099`.
- No dispatch tick or manual backtest was run.

## Safety boundary

No live setfile, T_Live access, AutoTrading action, deploy/T_Live manifest,
portfolio manifest, portfolio admission, portfolio-gate edit, or correlation
waiver occurred.
