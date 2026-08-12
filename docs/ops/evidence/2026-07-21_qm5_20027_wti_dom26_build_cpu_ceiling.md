# QM5_20027 WTI DOM26 Build / CPU Ceiling

`QM5_20027_wti-dom26-short` mechanizes the negative WTI session dated 26
reported by Borowski (2016): exact-date D1 short, next-D1 flat, no date shift,
ATR(20) x 2.75 hard stop, and fixed-risk backtest setfile.

Strict compile passed with zero errors and zero warnings. Evidence:
`framework/build/compile/20260721_064939/QM5_20027_wti-dom26-short.compile.log`.
Magic `200270000` was present after resolver regeneration.

Q01/Q02 stopped at the explicit CPU ceiling. `farmctl mt5-slots` at
2026-07-21T06:52:23Z showed active factory/pipeline terminals T1-T4 and T6-T10;
T10 was a pipeline run and only T5 was momentarily idle. No manual smoke was
started. The first attempted direct Q02 command correctly refused because Q02
requires the approved-review path; the subsequent build-record path correctly
blocked because no Q01 smoke result was fabricated. Therefore there is no Q02
work item and the card records `q02_status: NOT_QUEUED`.

No T_Live file, process, AutoTrading setting, deploy manifest, T_Live manifest,
or portfolio gate was touched.
