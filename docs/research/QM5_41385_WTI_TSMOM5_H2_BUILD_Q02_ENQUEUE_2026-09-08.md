# QM5_41385 WTI Five-Month Momentum / Two-Month Hold — Build And Q02 Enqueue

`QM5_41385_wti-tsmom5-h2` is a new low-frequency structural WTI sleeve. It
follows the sign of the exact prior five completed broker-month return only at
odd-month boundaries and holds the package through the intervening even month.
This supplies direct crude-oil exposure outside the incumbent
XAU/SP500/NDX/XNG carriers. Realized decorrelation remains a Q09 question.

## Source And Non-Duplicate Boundary

The complete-read, peer-reviewed source is Moskowitz, Ooi, and Pedersen
(2012), *Time Series Momentum*, Journal of Financial Economics 104(2),
228–250, DOI `10.1016/j.jfineco.2011.11.003`. It defines the own-return
formation/holding family and includes WTI; standalone WTI `k=5,h=2` efficacy
and continuous-CFD transfer remain explicitly unproven.

The corrected-root canonical checker found no exact identity and only
expected family matches. Monthly-renewal WTI siblings use a different
lifecycle; `QM5_20281` uses the same two-month clock with a twelve-month
return; `QM5_41379` through `QM5_41384` use three-, one-, nine-, six-, four-,
and two-month returns. This identity requires both the exact five-month
endpoints and fixed odd-month two-month lifecycle.

## Q01 Evidence

- EA ID and magic: `QM5_41385`, slot 0, `413850000` on `XTIUSD.DWX`.
- PACER audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- Deterministic reference vectors: 13/13 PASS; strategy-card schema PASS;
  prohibited-ML hits 0.
- Governed compile work item: `937e946d-39a0-4b92-8a83-ba5e06c330ef`
  on non-live `T10`.
- Compile result: `COMPILE_OK`; compiler errors 0, compiler warnings 0; strict
  build check PASS with three non-failing card-resolution advisories.
- Source SHA-256:
  `54177da692a8299e266fe19163d08bdbb7f314a1be5f4bcb9b78bf9bce4869ae`.
- Binary SHA-256:
  `d9cbd484e1c9509c1b4b15b6fb0225966c611d0f4524504a477bb9629f798029`.
- Backtest set SHA-256:
  `9e43eae25ad33e9d0bccd6b32808b4a2fc023b4b126840450f0a98eaf92430e2`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Q02 Enqueue

The exact fixed-risk `XTIUSD.DWX` D1 intake dry run was eligible. The first
apply attempt followed a five-sample CPU window with maximum 50.1% and made no
queue change because it lost a transient SQLite write-lock race. The guarded
retry used a fresh CPU window of 56.6%, 63.6%, 62.7%, 63.9%, and 62.9%; its
63.9% maximum remained below the binding 97% ceiling, and D: had 125.244 GB
free against the 100 GB floor.

The canonical intake appended exactly one pending Q02 work item:
`c1fc79e1-4d3d-485b-a184-f285a46a5aac`. Receipt:
`D:\QM\strategy_farm\artifacts\receipts\first_q02_intake\937e946d-39a0-4b92-8a83-ba5e06c330ef_c1fc79e1-4d3d-485b-a184-f285a46a5aac.json`,
SHA-256 `20637da35f0f344183cd0f3f41af03c9aa9c9a7b3b0320664ca25346ba02f30f`.
No priority boost or manual backtest was used.

## Safety Boundary

No terminal control, portfolio gate, `T_Live`, deploy/live manifest,
AutoTrading, or live surface was touched.
