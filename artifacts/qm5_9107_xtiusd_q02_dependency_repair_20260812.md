# QM5_9107 XTIUSD.DWX Q02 dependency repair

Date: 2026-08-12
Farm claim: `b54013f8-ad1a-40bf-822b-3eada348bd56`
Source work item: `8424a3ba-47c3-46e5-9c08-0f252d1ffb86`
Append-only successor: `942384d1-4ebc-4a08-9cff-5ddd4c9765f3`

## Selection

`QM5_9107_aa-mom-filter111` is an approved, structural, monthly cross-sectional
momentum strategy sourced from Alpha Architect. The claimed `XTIUSD.DWX` D1
identity adds energy exposure beyond XNG and had no open work item or competing
farm task when claimed.

## Diagnosis

- The terminal Q02 evidence at
  `D:\QM\reports\work_items\8424a3ba-47c3-46e5-9c08-0f252d1ffb86\QM5_9107\20260728_190840\summary.json`
  records three invalid attempts with `BARS_ZERO` and `INCOMPLETE_RUNS`.
- The source EX5 and deployed EX5 matched during those attempts, as did the
  source and deployed setfile. This excluded stale deployment as the immediate
  cause.
- The matching T3 terminal log records Windows history-file error 32 on
  `EURGBP.DWX` during all three XTI-host attempts. The EA ranks XTI against 36
  peer symbols, but it had no `basket_manifest.json`; the worker therefore
  treated the job as ordinary single-symbol work and did not isolate every
  peer-history archive.
- A historical H1 `MIN_TRADES_NOT_MET` result existed for the same host symbol
  but a different setfile. The exact-row rerun guard incorrectly allowed that
  different identity to block the D1 infrastructure repair.

## Repair

- Added a dependency-only manifest containing the exact 37-symbol universe
  implemented by `Strategy_UniverseSymbol()`. It intentionally has no logical
  basket symbol, so normal real-host fanout is preserved.
- Made Q02 append-only repair bind a newly introduced dependency manifest into
  the successor payload. This activates heavy multisymbol admission, 44 GB
  commit reservation, terminal-affinity checks, and custom-history isolation
  for all declared peers.
- Scoped the existing non-infrastructure terminal guard to the exact setfile,
  while retaining its refusal for a strategy-terminal result on the same
  setfile.
- Replaced the legacy raw month-key calculation with
  `QM_CalendarPeriodKey(PERIOD_MN1)` and documented the remaining monthly peer
  reads as month-gated structural exceptions. Trading rules and parameters are
  unchanged.

## Artifact bindings

- MQ5 SHA-256: `1cf9d1894c0d109f6908620621fd1668b730d14e60e8a294bb7fcdc575a51200`
- EX5 SHA-256: `9c9f423b4dda60b14788b93e0036ba3809ff0d22a10d1340aa74b3a6320afe31`
- XTI D1 setfile SHA-256: `d1a5545d81bd205b4a5649d19222a53f010c44e99946a9c0b19b370c76988c00`
- Dependency manifest SHA-256: `add8de28a7f046b94ad023808ae2666bda214b6d0772581da2bd24970f97cde0`
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`

## Verification

- Strict compile: PASS, 0 errors, 0 warnings.
- Framework build check: PASS, 0 failures, 0 warnings;
  `D:\QM\reports\framework\21\build_check_20260812_010132.json`.
- SPEC validation: PASS.
- Symbol-scope validation: `BASKET_OK`, 0 violations.
- Manifest/source comparison: 37 symbols, ordered exact match.
- Focused farmctl regression suite: 29 tests passed.
- Terminal custom-history isolation and lock-storm suites: 25 tests passed.
- All 111 canonical setfiles were hash-refreshed mechanically; their fixed-risk
  contract remains `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- The successor row was verified pending with all 37 `basket_symbols`, host
  `XTIUSD.DWX`, period `D1`, current artifact hashes, and fixed-risk bindings.
- Three `metatester64` processes were present at enqueue time, below the paced
  fleet ceiling of seven. No manual backtest was launched.

## Safety

No T_Live path, AutoTrading setting, portfolio gate, portfolio manifest, or
live deployment artifact was touched.
