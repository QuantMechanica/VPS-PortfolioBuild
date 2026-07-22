# QM5_20035 XNG Day-27 Short — Q02 Enqueue

Date: 2026-07-22  
Branch: `agents/board-advisor`

Built one new low-frequency energy sleeve from the already OWNER-approved,
fully reviewed Borowski (2016) peer-reviewed commodity-calendar paper. The
paper reports calendar day 27 as its minimum natural-gas numbered-day mean,
`-0.7265%`, but does not report that date as statistically significant. The
card therefore labels this a weak extreme-mean falsification hypothesis.

The EA sells `XNGUSD.DWX` only on an exact broker D1 bar dated the 27th,
never shifts a missing date, persists one attempt per month, and exits at the
next D1 boundary. ATR(20) at 2.75 ATR is the fixed broker stop. The sole setfile
uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and weight 1.

Repository-wide search found no XNG day-27 carrier. The mechanic differs from
`QM5_12567` cumulative-RSI2, day-15 long, weekday, storage-event, momentum and
monthly-channel XNG sleeves. Realized decorrelation remains a downstream gate.

Validation and queue evidence:

- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Compile log: `framework/build/compile/20260722_113633/QM5_20035_xng-dom27-short.compile.log`.
- Build-check report: `D:/QM/reports/framework/21/build_check_20260722_113708.json`.
- MQ5 SHA256: `433408DF86A608443092F2E7A172A6D916EBA85C0457AE9D01EFC0E040E8FC5C`.
- EX5 SHA256: `39E26EDC4BA4CE2DFA8B811E78A17B3E6B33754A8C603CD8A262FB5348C81BDB`.
- Build task: `06786283-a09c-4c38-88d2-3aca11b13c62`, done.
- Q02 work item: `85e22900-57bc-425c-8452-d665fc262cd5`, pending,
  unclaimed, attempt 0, `XNGUSD.DWX` D1.

No smoke or backtest was launched because the preflight observed the CPU
ceiling (9 `terminal64`, 6 `metatester64`). The build recorded
`deferred_p2_smoke`; Q02 remains queued for fleet capacity.

No live setfile, T_Live/AutoTrading action, deploy manifest, portfolio
manifest, portfolio admission, or portfolio-gate change was made.
