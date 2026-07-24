# QM5_20100 XNG Same-Calendar Sign — Build And Q02 Enqueue

Date: 2026-07-24
Branch: `agents/board-advisor`

## Scope

One new low-frequency XNG carrier was extracted from the complete,
OWNER-approved Keloharju, Linnainmaa, and Nyberg (2016) source packet. At each
broker-month boundary it averages XNG's completed return for the same calendar
month over the preceding ten years, requires at least five observations, and
trades the average's sign until the next month boundary.

This is not the incumbent `QM5_12567_cum-rsi2-commodity` XNG sleeve, which
fades a short-horizon cumulative-RSI2 pullback behind a 200-day trend filter.
It is also not the two-leg `QM5_13115_energy-samecal` relative-rank basket:
QM5_20100 compares XNG's own same-month mean with zero, never reads WTI, and
owns only one `XNGUSD.DWX` position. It is a disclosed XNG carrier port of the
same estimator used by `QM5_20099_wti-samecal`, not a claim to a globally new
signal family.

No profitability or decorrelation result is claimed before governed pipeline
evidence.

## Source and card evidence

- Strategy ID: `KELOHARJU-RETSEAS-2016_XNG_S03`.
- Primary source: Keloharju, Linnainmaa, and Nyberg (2016), "Return
  Seasonalities," *The Journal of Finance* 71(4), DOI
  `10.1111/jofi.12398`; complete NBER Working Paper 20815 reviewed end to end.
- Source scope: 24 commodity futures, explicitly including natural gas, with
  at least five years of history. The paper reports a broad cross-sectional
  rank, not this standalone XNG time-series-sign reduction.
- Deterministic dedup check surfaced the expected same-calendar sibling for
  manual review; repository-wide mechanic review found no single-XNG
  historical same-calendar-average-sign carrier.
- Card schema lint: PASS; no missing sections or prohibited ML hits.

## Build evidence

- EA ID and slug: `QM5_20100_xng-samecal`.
- Magic: `201000000`, slot 0, `XNGUSD.DWX`.
- Build prerequisite guard: PASS.
- SPEC validator: PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
- Framework build check: PASS, 0 failures, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260724_131448\QM5_20100_xng-samecal.compile.log`.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260724_131511.json`.
- MQ5 SHA256:
  `E9FF3C911DD762CF875A79FD6956FADC9BEEB2502944E04ECA31B215576A22AB`.
- EX5 SHA256:
  `65C2F4BEB052C01EADEA762D7C65FBF3E819F5009389464EA340C12B5AAF8FFB`.
- Backtest setfile SHA256:
  `BFD35D460D5177B4A7675C864EBA990C681C53282A7A80782824CE674E66F1B4`.
- Setfile build hash:
  `68bafe1fe15c8ee93e3e36c902ac18f3eb9406e2130fb9fc94a1775e176204f0`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The generated resolver contains EA 20100 and magic `201000000`; the scoped
identity/build guard passed.

## Paced Q02 enqueue

At `2026-07-24T13:15:35+00:00`, `farmctl mt5-slots` showed five active
factory terminals: `T2`, `T3`, `T6`, `T7`, and `T8`. This was below the paced
seven-factory-terminal ceiling. The separate T_Live and FTMO GUI processes
were excluded and were not touched.

A target-scoped dry run selected exactly one new row. The applied sweep was
restricted to `QM5_20100`, `XNGUSD.DWX`, with stranded retry fan-out disabled.

- Work item: `67dff6ba-5b40-4a7e-bbf5-98bef9b9043e`.
- Phase: `Q02`.
- State after insertion: `pending`, unclaimed.
- Duplicate guard: exactly one work item exists for `QM5_20100`.
- No dispatch tick or manual backtest was run.

## Safety boundary

No live setfile, T_Live access, AutoTrading action, deploy/T_Live manifest,
portfolio manifest, portfolio admission, portfolio-gate edit, or correlation
waiver occurred.
