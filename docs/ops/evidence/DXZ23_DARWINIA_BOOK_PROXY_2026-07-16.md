# DXZ-23 DarwinIA Book Proxy — 2026-07-16

## Decision

The corrected schema-v2 proxy evidence contains a credible book-improvement hypothesis, but
not a Darwinex Zero qualification, sustainable-book claim, or resize
authorization.

Two hash-bound diagnostics aggregate conservative Darwinex Zero
commission-adjusted exit P&L from the 21 technically non-empty EA/symbol
reports. Both remain `deployment_eligible=false`. They are not DARWIN quote
curves, do not simulate Darwinex's Risk Engine, do not reconstruct a shared
capital/margin/risk path, and do not repair the B/C/D `.DWX` discontinuities.

## Independent review corrections

The original schema-v1 artifacts and the first schema-v2 proxy files remain
immutable but are superseded for all future interpretation. Review found four
issues, followed by a commission-artifact terminology correction:

1. The v1 field named `close_to_close_max_drawdown` first netted all closing
   P&L by MT5-server calendar day. It was a daily-netted close-P&L drawdown, not
   an exit-event drawdown. V2 parses and sorts full exit timestamps and reports
   `exit_event_max_drawdown` separately from
   `daily_netted_close_pnl_max_drawdown`.
2. A `100% real ticks` tester label means historical spread is embedded in the
   tester prices. It is not a certificate of current or broker-parity spread.
   No sleeve receives a spread-certification pass from this proxy.
3. V1 inferred the SILVER activity proxy from exit months. V2 uses
   `entry_time_mt5_server` from completed round trips and keeps close counts
   separate. It still cannot see an entry that never appears in a completed
   round trip and therefore does not prove live-account participation.
4. The book is an unscaled sum of independent tester paths. There is no
   synchronized shared-equity sizing, capital, margin, overlapping-exposure, or
   risk-budget match. Comparisons between cohorts are not risk-matched portfolio
   comparisons.

The original cost artifact also used a misleading summary label that could be
read as spread certification. Its schema-v2 replacement fixed that label, but
retained a separate factor-ten terminology error: the correctly implemented
rate `0.00005` equals 0.005% or 0.5 bp, not 5 bp. Cost schema v3 makes all three
units explicit and preserves the economics exactly. The proxy rejects cost
schemas below v3 even when explicitly hash-bound. The canonical pair was
therefore regenerated as v6 against the cost-v3 hash and versioned proxy
implementation.

The review also confirmed that the mechanical walk-forward selector reads only
training-window exit P&L. This blocks direct evaluation-row leakage into the
selector, but does not remove strategy-development, preset, universe, split, or
threshold-selection leakage from the broader research programme.

## Bound inputs and artifacts

| Status | Artifact | Path | SHA-256 |
|---|---|---|---|
| canonical input v3 | Standalone commission evidence | `D:\QM\reports\portfolio\dxz_cost_evidence_20260716_v3\report.json` | `98ea8553f4fb6044d757e90c964c8b6fda4f8f40f653e75510833f8f49c694fd` |
| canonical proxy v6 | Full-sample book diagnostic | `D:\QM\reports\portfolio\dxz_darwinia_book_proxy_20260716_v6\report.json` | `f81a41cc0b59db5d22540269039e5985f1607016d2218acf5333a7b54ba5b27a` |
| canonical proxy v6 | Earlier-window selection / later-window evaluation | `D:\QM\reports\portfolio\dxz_darwinia_walkforward_proxy_20260716_v6\report.json` | `417402610043196dcdfd9e3f91977def9dc42cca89fdb5e17fcbd0f8e5a1fc7b` |
| superseded input v2 | Correct economics with erroneous 5-bp label | `D:\QM\reports\portfolio\dxz_cost_evidence_20260716_v2\report.json` | `ef33eb7615bc46fbffc2dcc5b82d5096dfd21d4b608e60dbcd4efc01130d1e08` |
| superseded proxy v5 | Cost-v2-bound full-sample diagnostic | `D:\QM\reports\portfolio\dxz_darwinia_book_proxy_20260716_v5\report.json` | `ea1a2d9cc6bcea29fd8a93e5723ec60d08dfafe2aece069ac9139e0e01d91c47` |
| superseded proxy v5 | Cost-v2-bound walk-forward diagnostic | `D:\QM\reports\portfolio\dxz_darwinia_walkforward_proxy_20260716_v5\report.json` | `a28ac3ab7ffb1bdb834abccea86953fee51c7999a08d273a0dfb6059208a109b` |
| superseded input v1 | Original standalone cost evidence | `D:\QM\reports\portfolio\dxz_cost_evidence_20260716\report.json` | `7333481780f4dff4f646de76fb783a6016a580ecdc7853d0b6b77dfa98afaab2` |
| superseded proxy v2 | Corrected proxy before cost-label rebind | `D:\QM\reports\portfolio\dxz_darwinia_book_proxy_20260716_v2\report.json` | `f81589be300e2435a3788f8c13395b853b098ba2885563b3efa3e5b4f0748c49` |
| superseded proxy v2 | Corrected walk-forward before cost-label rebind | `D:\QM\reports\portfolio\dxz_darwinia_walkforward_proxy_20260716_v2\report.json` | `20b32e1b3fb1b8cf6a2921e51a07209b4d1580b409c3ee857dd2203d21c954a1` |
| superseded proxy v3 | Cost-v2 bound before schema-v1 rejection became machine-enforced | `D:\QM\reports\portfolio\dxz_darwinia_book_proxy_20260716_v3\report.json` | `f6467add47ae92b972f2c5cab520f810b0a4f3e038c8f1a9b860162d94252f5e` |
| superseded proxy v3 | Walk-forward before schema-v1 rejection became machine-enforced | `D:\QM\reports\portfolio\dxz_darwinia_walkforward_proxy_20260716_v3\report.json` | `e8c7fd1a817e4c002e114fe7aecffcd9346b94906f0ce0b7deaba8efbf04338d` |
| superseded proxy v4 | Schema-v1 rejection fixed before tool-version bump | `D:\QM\reports\portfolio\dxz_darwinia_book_proxy_20260716_v4\report.json` | `541dbca209bf2197fb049937b2fd8f4bcb1f99b1681ffc833cd5e480c5ad1073` |
| superseded proxy v4 | Walk-forward before dependency-version bump | `D:\QM\reports\portfolio\dxz_darwinia_walkforward_proxy_20260716_v4\report.json` | `06264a62c16c43e4e5fd4fa48a153031fcb32320bd58de2e1893bd5acb64c8ed` |
| superseded v1 | Original full-sample diagnostic | `D:\QM\reports\portfolio\dxz_darwinia_book_proxy_20260716\report.json` | `66f7baed1620031312077c90dc7db2ca91e6fdfc65166ffc5ec8fe3e77e7ac31` |
| superseded v1 | Original walk-forward diagnostic | `D:\QM\reports\portfolio\dxz_darwinia_walkforward_proxy_20260716\report.json` | `4ab7d42e478d50bc5d97587f99fdb8b17a5007465a927ccc005b252f51ef0583` |

Every JSON has an exclusive `.sha256` sidecar. The old reports were neither
overwritten nor deleted. The canonical proxy-v6 implementation bindings are:

| File | SHA-256 |
|---|---|
| `tools/strategy_farm/dxz_cost_evidence.py` | `fc37251fc519345ed80187e4ade15c7a84b4bc3e826b4f198c1b47a1d1833ec2` |
| `tools/strategy_farm/dxz_darwinia_book_proxy.py` | `b75398d87442cfc19496e7242898a562d1af9ea55211af2d71837ada473afc76` |
| `tools/strategy_farm/dxz_darwinia_walkforward_proxy.py` | `02354e9834b9b36e4c78e2d246bfa9148b74b62144cccc4ff7bff80ae4e3dd23` |
| `tools/strategy_farm/tests/test_dxz_cost_evidence.py` | `88ce7ff83bde354a52b25dd0b4ae07098f42ac7075cdb0a6b8f98cec6782e7e1` |
| `tools/strategy_farm/tests/test_dxz_darwinia_book_proxy.py` | `4bfa95d555c14a647a4d986fc3367f1634963a7b61dcce7a2689aab270fc6be5` |
| `tools/strategy_farm/tests/test_dxz_darwinia_walkforward_proxy.py` | `dc59237982bb1eb862b6a30bb24b23f361164ed38bf11429cb9044f97ec40cc2` |

## Diagnostic 1: full-sample sensitivity

Common diagnostic window: 2018-07-01 through 2025-12-31; fixed reporting scale
EUR 100,000. The 18-sleeve row is explicitly ex-post because its PF threshold
is measured on this same complete sample.

| Cohort | Sleeves | Closed trades | Net exit P&L | Exit-event max DD | Daily-netted max DD | Positive rolling 6m | Minimum rolling 6m net |
|---|---:|---:|---:|---:|---:|---:|---:|
| all technically non-empty | 21 | 3,331 | EUR 23,765.12 | EUR 11,501.63 | EUR 11,490.16 | 63/85 | EUR -8,707.52 |
| ex-post conservative PF >= 1.10 | 18 | 2,371 | EUR 63,641.09 | EUR 3,555.29 | EUR 3,543.82 | 81/85 | EUR -1,358.50 |

This does not authorize dropping `10440:NDX`, `10692:NDX`, or
`11165:EURUSD`. It shows that those three current variants explain a large share
of the historical unscaled aggregate damage and deserve reject/repair treatment.
It does not show what a capital- and risk-matched 21-versus-18 comparison would
have produced.

## Diagnostic 2: earlier selection, later holdout

The second screen keeps direct 2023-2025 exit P&L rows out of its mechanical
selector:

- training: 2018-07-01 through 2022-12-31;
- selection: at least 20 closed trades and finite conservative commission PF
  >= 1.10 on training-window exit P&L;
- evaluation: strictly later, 2023-01-01 through 2025-12-31;
- explicit universe: all 21 technically non-empty reports.

The rule selects 11 sleeves:

`1556:XAUUSD`, `10403:XAUUSD`, `10476:USDCAD`, `10513:XAUUSD`,
`10706:GBPUSD`, `10939:GBPUSD`, `11421:AUDUSD`, `11708:EURUSD`,
`12567:XNGUSD`, `12969:USDJPY`, and `13128:NDX`.

| Later evaluation | Sleeves | Closed trades | Net exit P&L | Exit-event max DD | Daily-netted max DD | Positive rolling 6m | Minimum rolling 6m net |
|---|---:|---:|---:|---:|---:|---:|---:|
| training-selected cohort | 11 | 702 | EUR 19,576.91 | EUR 2,869.31 | EUR 2,854.10 | **31/31** | **EUR 363.03** |
| full 21-sleeve universe | 21 | 1,383 | EUR 9,587.47 | EUR 9,916.09 | EUR 9,318.02 | 21/31 | EUR -6,006.09 |

All 36 evaluation months satisfy the entry-activity proxy for both rows. That is
historical tester cadence, not proof that a live DARWIN met the participation
rule.

This split is stronger than a same-sample PF ranking only in the narrow sense
that the selector does not read later exit outcomes. It is still one split
designed after the research programme began, not untouched prospective
evidence. Multiple selected sleeves also retain substantive Card/preset lineage
defects.

## Independent arithmetic verification

The review recomputed metrics directly from the bound cost JSON without
importing either proxy implementation:

- 21/21 full-sample sleeve keys and the ex-post 18-key rule match C0.
- All 21 training trade counts, gross-profit/loss sums, PFs, and selection flags
  reproduce; the same 11 sleeves are selected.
- Full-sample and evaluation trade counts, net P&L, rolling-window counts,
  positive-window counts, and minimum six-month nets reproduce exactly within
  floating-point tolerance.
- Full exit-timestamp drawdowns independently reproduce the four canonical
  values in the tables above.
- Both proxy-v6 payload hashes and exclusive file sidecars verify, and both
  artifacts bind the current implementation hashes.

There are many same-second closes, especially framework Friday exits. Because a
global execution order across independently tested sleeves does not exist, the
schema-v2 proxy uses the deterministic tie-break `exit timestamp -> sleeve key
-> source row index` and records that limitation. Even the exit-event result
remains a proxy.

## Why the DarwinIA objective differs from an FTMO objective

Current official DarwinIA SILVER rules weight current calendar-month return,
current plus prior five calendar months' cumulative return, and maximum drawdown
across those six months. The cumulative six-month return has the largest
published weight. Participation requires an opened trade in the current or
immediately preceding month. The proprietary rating itself is not reconstructed.

Darwinex's Risk Engine independently sizes the DARWIN toward a dynamic monthly
VaR target in the 3.25%-6.5% range and uses the last 45 exposed days for strategy
VaR. Consequently, individual sleeve PF and the fixed-EUR sums here are research
inputs, not the final book objective. Stable risk (Rs), limited Risk Engine
intervention (Ra), rolling DARWIN return/drawdown, and live trade cadence must be
evaluated on the combined DARWIN.

Official references:

- https://help.darwinex.com/what-is-darwinia
- https://www.darwinexzero.com/docs/rating
- https://www.darwinexzero.com/docs/en/risk-engine
- https://help.darwinex.com/risk-stability-attribute
- https://help.darwinex.com/risk-adjustment-attribute

## What remains invalid or missing

1. Exit-event P&L omits intratrade/open mark-to-market and is not Darwinex's
   DARWIN quote drawdown.
2. Risk Engine VaR scaling, D-Leverage limits, partial interventions, Rs and Ra
   are not simulated.
3. A 100% real-ticks label only establishes that historical tester prices embed
   spread. Current broker-spread parity, current swap-rate parity, and slippage
   remain open for every cohort.
4. Independent sleeve backtests are not a synchronized executable account:
   shared equity, dynamic lot sizing, capital, margin, correlated exposure, and
   risk budgets are unmatched.
5. The evaluation window crosses the known B/C/D raw-data discontinuities. No
   pooled statistic across those gaps is qualification evidence.
6. Card, preset, source, EX5, Friday, news/calendar, routing and basket identities
   remain independent fail-closed gates.
7. Entry activity is reconstructed only from completed round trips; it is not a
   live participation receipt.

## Correct next experiment

Preserve the training rule and 11 selected keys without tuning them on later
outcomes. Re-evaluate the cohort separately inside every session-valid
continuous segment, with warmup rebuilt after each gap and no position crossing
a gap. Then repeat on synchronized mark-to-market equity streams with an
explicit shared capital/margin/risk budget, conservative spread, current swap,
slippage, and Risk Engine proxy stress. Only a prospective shadow period after
all Card/EA lineage gates close can turn this into sustainability evidence.
