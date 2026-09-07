# QM5_41377 WTI Disjoint Weekly Momentum Agreement — Build And Q02 CPU Stop

`QM5_41377_wti-wmom142-agree` is a new low-frequency WTI structural sleeve.
At the first tradable bar of week `t`, it follows WTI only when the immediately
completed `t-1` weekly return and the disjoint `t-4` through `t-2` cumulative
return have the same strict sign. It stays flat on disagreement or equality,
uses a frozen `3.5*ATR(20,D1)` stop, and exits at the next broker-week boundary.

This conjunction is mechanically distinct from `QM5_41375` (`t-1` only) and
`QM5_41376` (`t-4..t-2` only). It adds oil exposure outside the certified
XAU/SP500/NDX/XNG book; realized decorrelation remains a Q09 question.

## Build Result

- Source and card provenance: Kwon, Kang, and Yun (2020), *Weekly Momentum in
  the Commodity Futures Market*, with the governed complete-read record reused
  after the fresh source-router attempt was policy-deferred.
- Mandatory PACER audit: PASS, 0 `EA_FRAMEWORK_INPUT_PINNED` findings, run on
  the final source before compile enqueue.
- Deterministic reference tests: 12/12 PASS.
- Card schema/ML lint: PASS.
- Governed compile work item:
  `0a670cc3-b225-4089-95a4-8a89a7515af6`.
- Compile: `COMPILE_OK`, 0 errors, 0 warnings; strict build check PASS.
- Binary SHA-256:
  `3bbc570bc1697f51e18746955e72a7d89ef885e205f307f1c6e081908a10ba2c`.
- The sole baseline preset binds `XTIUSD.DWX`, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`.

## Q02 Admission Stop

The canonical first-Q02 dry-run was eligible for the exact XTIUSD.DWX D1
fixed-risk preset. Before apply, five one-second whole-host CPU samples were
96.780724%, 98.340419%, 98.829518%, 91.999949%, and 91.895483%. The maximum
was 98.829518%, above the binding 97% ceiling, so Q02 was not enqueued and no
backtest was started. Five non-live `terminal64` processes were present.

Resume only after a fresh CPU window is strictly below 97%, then run:

`python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 0a670cc3-b225-4089-95a4-8a89a7515af6 --apply`

## Safety Boundary

No portfolio gate, `T_Live`, deploy/live manifest, AutoTrading, manual
backtest, optimization, terminal restart, priority boost, or live surface was
touched.
