# QM5_1168 Q02 METATESTER_HUNG Repair

## Status

`QM5_1168_qp-oil-preholiday` was claimed as a distinct infrastructure-repair
target, repaired, rebuilt, and re-enqueued to Q02 on the priority track.

- EA: `QM5_1168_qp-oil-preholiday`
- Instrument: `XTIUSD.DWX`, D1
- Edge: low-frequency U.S. pre-holiday oil drift
- Source card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1168_qp-oil-preholiday.md`
- Q02 work item: `4d0f7141-c7c0-4bac-9b51-76c0168f862a`
- Claim: `codex:agents/board-advisor` at `2026-07-10T00:05:44+00:00`
- Requeue: `pending` at `2026-07-10T00:09:34+00:00`

## Diagnosis

The prior result was infrastructure failure, not a strategy verdict. Real-MT5
evidence at
`D:/QM/reports/work_items/7828b556-8afb-44c6-81aa-7d9d7249d50f/QM5_1168/20260622_053336/summary.json`
shows:

- MetaTester initialized the EA successfully; no `ONINIT_FAILED` was detected.
- XTI history and real ticks synchronized from 2017 onward.
- The EA opened and closed real tester positions during 2018.
- The run then stopped advancing, emitted no report, and was classified
  `REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`.

The code rebuilt the full U.S. holiday calendar on every real tick while a
position remained open. Each call to `Strategy_ExitSignal` searched future
dates and repeatedly reconstructed observed, nth-weekday, and Easter holidays.
Across multi-day holds and a ten-year real-tick window, this was the dominant
runtime defect.

The prior `.ex5` was newer than the source, so stale compilation was excluded
as the primary cause.

## Repair

- Cache the holiday-derived exit date once for each distinct position open
  time, and clear the cache after the position closes.
- Replace raw daily-series cadence/history calls with framework calendar keys,
  leaving holiday resolution on the daily path instead of the per-tick path.
- Keep zero-spread `.DWX` behavior permissive while sampling only positive
  historical spreads for the optional median-spread cap.
- Move news blackout checks below position management and mandatory exit logic;
  news now gates entries only.
- Regenerate the canonical D1 backtest setfile. It remains `risk_mode: FIXED`,
  `RISK_FIXED=1000`, and `RISK_PERCENT=0`.

## Verification

- Strict build check: `PASS`, zero failures and zero warnings.
  Evidence: `D:/QM/reports/framework/21/build_check_20260710_000812.json`.
- Compile: `PASS`, zero errors and zero warnings.
  Evidence:
  `C:/QM/repo/framework/build/compile/20260710_000747/QM5_1168_qp-oil-preholiday.compile.log`.
- EA/source/setfile artifact commit: `d03d2f867` (deterministic farm
  auto-commit after the verified rebuild).
- Source SHA256:
  `DD4AA9B1882D29F4D63D2F3A70C81C1010ACA779D61E09EB06C916E14078CD4B`.
- EX5 SHA256:
  `83960E59AC0CB07C9B7EBED1FE7A841949A22698A4A501CEBF8771CC240C0178`.
- Requeue payload uses the current OWNER Q02 floor: 5 trades/year over the
  requested ten years, `effective_min_trades=50`. Card frequency remains
  diagnostic and does not redefine the gate.

Five factory MT5 tests were already active during verification. No manual
smoke/backtest was added at the CPU ceiling; the paced Q02 work item owns the
real performance and strategy verdict.

## Boundaries

No portfolio gate, T_Live file, deploy manifest, terminal process, or
AutoTrading state was touched.
