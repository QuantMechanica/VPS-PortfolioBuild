# DXZ-23 As-Live Requalification — 2026-07-16

Status: **NO QUALIFIED BOOK CANDIDATE / DEPLOY AND RESIZE FREEZE**  
Scope: 23 DarwinexZero sleeves, literal `.DWX` test symbols, exact read-only
T_Live EX5/preset identities, isolated `DXZ_Truth_*` execution sandboxes.

## Current answer

The earlier conclusion “we cannot find a valid strategy” was too broad. The
current evidence says something more useful:

- 21/23 sleeves have a technically usable, non-empty native MT5 report.
- After the DarwinexZero round-trip commission estimate of **0.005% of nominal
  (0.5 basis points)**, **18/21 remain at
  PF >= 1.10 and 14/21 remain at PF >= 1.20**.
- The historical-reference problem decomposes into **6 exact signal-identity
  passes, 6 exact native-close reproductions blocked by legacy Q08, 3 proven
  truncated reference horizons, and 8 substantive lineage/configuration cases**.
- None is yet a sustainable or deployable strategy because Card/EA/preset
  lineage, continuous B/C/D data segments, spread/swap/slippage and portfolio
  Risk Engine evidence are not all closed.

This is progress toward a valid book: the edge is visible, and the remaining
work is now an explicit repair queue instead of 18 undifferentiated failures.

## Why the first FULL run failed

The first hardened schema-v1 FULL run finished `FAIL` with 5/23 evidence passes.
A partial retry closed 12989 diagnostically. Those outcomes remain immutable
historical evidence; they are not relabeled after the fact.

| Run | Scope | Result | Summary file SHA-256 |
|---|---|---|---|
| `20260716T051551Z` | FULL 23 | 5 PASS / 18 FAIL | `523b6e1ef9a96ec5e820ae039e5272b9673c65e492ac4d1bd93863d52a2be169` |
| `20260716T060039Z` | technical retry | 12989 individually PASS; no book pass | `800037435d54bd1bc2a74146cbd08db8714bb9e8f454c03d93d156fff680b50d` |

The later effective-window runs proved that several initial failures were caused
by reference and instrumentation defects:

| Run | Main result | Summary file SHA-256 |
|---|---|---|
| H1 `20260716T071056Z` | 10476 horizon defect; 11165/AUD native exact; 10706 signals exact but old risk contract wrong | `d02d69d0e5915801791c6ed98ea77759be012c58c9998b2a7068d89d952467e4` |
| H4 `20260716T075313Z` | 10939 native close sequence exact | `5032cca4d58ba5ae4965560998b95adff8940072ac5bbb19c6cdfb8e55cc7925` |
| D1 `20260716T080201Z` | 11421/AUD and 12778 horizon defects; 12567/XAU native exact | `af55e04a33016aac2d7b582c37440c63c351944ec4fcdfe3a577055b76967181` |

The authoritative 23-row adjudication is
`docs/ops/evidence/DXZ23_REFERENCE_HORIZON_AND_DATA_GAPS_2026-07-16.md`.

## Reference and data truth

Three old references are demonstrably truncated, not evidence that the later
trades are invalid:

- `10476:USDCAD` — 257 old closes versus 299 current; 42 additional 2025 closes.
- `11421:AUDUSD` — the complete first 81 old closes reproduce, followed by 9
  additional 2025 closes.
- `12778:AUDUSD/EURJPY` — the first 194 identities reproduce. The original host
  D1 series ended in 2024 despite a 2025 tester end date, leaving the December
  2024 pair open until 2025. Legacy Q08 also omitted the AUDUSD forced exit.

Literal `.DWX` histories contain three independent discontinuity classes:

- B: approximately 2023-12-12/13 through 2023-12-18, market-wide;
- C: approximately 2025-10-08/10 through 2025-11-03, FX and conversion legs;
- D: approximately 2025-12-17/18 through 2025-12-22, market-wide.

Missing history before a symbol's first available date is not a strategy failure
and is not a blocker by itself. Qualification must instead score session-valid
continuous segments separately, rebuild warmup within every segment, forbid
positions or indicator state across a gap, and intersect all host/leg/conversion
segments for baskets.

## Economic evidence

The immutable standalone cost artifact is:

`D:\QM\reports\portfolio\dxz_cost_evidence_20260716_v3\report.json`  
file SHA-256
`98ea8553f4fb6044d757e90c964c8b6fda4f8f40f653e75510833f8f49c694fd`.

It evaluates 21 explicit receipt/report/Q08 tuples. Commission evidence is
complete for 19 and conservatively bounded for 2; none is unbounded. A known
EUR 12778 Q07 report independently validates the 0.005% (0.5 bp) notional
formula: native
settled commission EUR 281.77 versus EUR 281.4382 unrounded, inside the
conservative EUR 280.4255-283.7235 bound.

The schema-v3 cost artifact fixes a factor-ten terminology error in schema v1/v2:
the numerical rate was already the correct `0.00005`, but it was incorrectly
called 5 bp instead of 0.5 bp. All 21 economics are exactly unchanged. Schema
v3 also preserves the earlier spread-label correction. Ten reports contain historical tester
prices based on 100% real ticks; **zero certify current broker-spread parity**.
Current swap-rate parity and slippage also remain open.

The five fail-closed repair/reject rows are:

- `10440:NDX` PF 0.486;
- `10692:NDX` PF 0.370;
- `11165:EURUSD` PF 1.066;
- `10715:USDJPY` zero trades under a misbound magic slot;
- `10911:GDAXI` no technically valid non-empty native report.

All 23 economic and evidence rows are in
`docs/ops/evidence/DXZ23_COST_ADJUSTED_CANDIDATE_COHORT_2026-07-16.md`.

## Repair-first cohort

The deterministic first repair queue is not the final DARWIN composition:

1. `10706:GBPUSD H1` — 367 trades, PF 1.329; entries/outcome signs reproduce;
   rebuild under the correct percent-risk/EUR contract.
2. `10939:GBPUSD H4` — 92 trades, PF 1.583; exact native closes; repair Q08 and
   resolve six bounded zero-move cost rows.
3. `12567:XAUUSD D1` — 73 trades, PF 1.574; exact native closes; repair identity
   and commodity execution economics.
4. `10476:USDCAD H1` — 299 trades, PF 1.260; proven truncated reference;
   rebase on continuous segments.
5. `11708:EURUSD D1` — 178 trades, PF 1.320; exact identity; repair the
   contradictory/incomplete Card and Friday policy.
6. `12969:USDJPY M30` — 331 trades, PF 1.545; exact identity; decide Card no-stop
   versus active 120-pip EA stop and resolve one bounded cost row.

High PF alone does not move a sleeve ahead of an unresolved strategy identity.
For example, 10513, 11132, 11165/AUD and 12567/XNG use unqualified live parameter
variants; 12989 lacks a canonical APPROVED Card.

## Card / EA / preset reality

The explicit lineage audit finds 19 real strategy-input overrides across five
sleeves:

- 10440: 3 overrides;
- 10513: 4 overrides;
- 11132: 5 overrides;
- 11165/AUDCAD: 6 overrides;
- 12567/XNG: 1 override.

Authoritative audit output:
`D:\QM\reports\portfolio\dxz23_lineage_audit_20260716_v2\report.json`,
file SHA-256
`41b540a2bfd78969494ecb03580e2ff0f7965694a717e267149717cabed6a3dd`;
human matrix:
`docs/ops/evidence/DXZ23_CARD_EA_PRESET_REPORT_LINEAGE_AUDIT_2026-07-16.md`.

For 11132, the APPROVED Card/EA default is `35/65/SMA200/ATR14x2.5`; the effective
as-live report confirms `38/66/SMA165/ATR12x2.0`. The Card also does not qualify
the effective Friday and two-axis news policy. This is documented in
`docs/ops/evidence/DXZ_11132_CARD_SOURCE_PRESET_DRIFT_2026-07-16.md`.

Twenty-one legacy presets also contain `qm_filter_*` fields which are not inputs
of the current EA sources. They do not appear as effective MT5 report inputs and
must not be treated as active controls. Enum/bool equivalences such as
`PERIOD_H1 == 16385` and `false == 0` are normalized to avoid false drift.

## Risk-application defect and repair

The historical 23-sleeve draft is not a valid deploy or requalification source
manifest. It wrote the already allocated absolute sleeve risk to `RISK_PERCENT`
and also wrote the relative book share to EA-facing `PORTFOLIO_WEIGHT`, although
the V5 risk sizer multiplies both values. Across all 23 rows this would turn a
declared 9.749998 account percentage points into only 0.633498663662 effective
percentage points if those draft expectations were applied.

This defect was in the draft contract, not in the observed live preset state.
Read-only inspection found all 23 current DXZ presets at
`PORTFOLIO_WEIGHT=1`, with 9.7501 aggregate `RISK_PERCENT` after preset
rounding. The generic and one-off manifest generators now emit the explicit
contract `absolute RISK_PERCENT * PORTFOLIO_WEIGHT 1`; resize rejects legacy
double-scaling before mutation. The requalification runner now rejects any
source-manifest/preset mismatch before launching MT5.

Exact hashes, arithmetic and qualification consequences are in
`docs/ops/evidence/DXZ23_RISK_APPLICATION_CONTRACT_AUDIT_2026-07-16.md`.
The old draft remains immutable defect evidence but must be replaced by a
pre-run sealed source manifest that matches the actual preset contract.

## No-weekend OWNER directive and runtime blocker

The OWNER has selected a strict no-weekend-holdings policy. Earlier explicit
Card exits remain valid; broker hour 21 is the latest normal framework safety
cutoff. A holiday/early-close deadline must instead use the last tradable
pre-weekend session with an approved positive safety buffer. The directive is
recorded but remains unsealed until an external OWNER trust receipt binds it.

Read-only source review found a reachable defect in all three first repair
packets: active `PRE30_POST30`/DXZ news checks can return from `OnTick` before
`QM_FrameworkHandleFridayClose`, and the framework only tests a fixed Friday
hour rather than a bound session/holiday cutoff. Therefore 10706, 10939 and
12567/XAU are now `BLOCKING_REMEDIATION_REQUIRED` even if their identities and
cost axes later pass. Mandatory risk-reducing exits must precede news/entry
returns, session-aware flattening must be implemented, then Card/source/EX5
and all segment references must be rebuilt. Exact source hashes and the repair
contract are in
`docs/ops/evidence/DXZ_NO_WEEKEND_RUNTIME_ORDERING_GAP_2026-07-16.md`.

## SP500 correction

Broker-side SP500 direct routability is no longer the blocker:

| Purpose | Symbol |
|---|---|
| literal test/history alias | `SP500.DWX` |
| DarwinexZero broker order symbol | `SP500` |

Read-only T_Live logs bind accepted entry and close orders on `SP500` with
retcode 10009. The evidence is
`docs/ops/evidence/DXZ_11132_SP500_DIRECT_ROUTABILITY_2026-07-16.md`.
The end-to-end `SP500.DWX -> SP500` execution contract is still unqualified:
11132 remains blocked for Card/default-versus-live parameters, source exit,
Friday, news, binary and full alias requalification. NDX/WS30 proxy screens are
optional derivative research, not a required SP500 substitute.

## DarwinIA book evidence

A same-sample sensitivity screen shows why the three economic reject variants
matter, but is explicitly not qualification evidence. More useful is a fixed
earlier-window selector:

- train 2018-07 through 2022-12;
- require at least 20 trades and conservative commission PF >= 1.10;
- evaluate the selected 11 sleeves strictly later, 2023-2025.

The selected cohort produces 702 later closes, EUR 19,576.91 net exit P&L,
EUR 2,869.31 deterministic exit-event DD (EUR 2,854.10 after daily netting),
and 31/31 positive rolling six-month windows. The full 21-sleeve benchmark has
EUR 9,587.47 net, EUR 9,916.09 exit-event DD (EUR 9,318.02 daily-netted), and
21/31 positive rolling windows.

This is a promising holdout hypothesis, not a DARWIN quote reconstruction. It
omits open-position mark-to-market, Risk Engine sizing/interventions, current
spread/swap parity and slippage, shared capital/margin/risk synchronization,
and it still crosses B/C/D. Full limitations and canonical cost-v3/proxy-v6
hashes for canonical cost-v3/proxy-v6 artifacts are in
`docs/ops/evidence/DXZ23_DARWINIA_BOOK_PROXY_2026-07-16.md`.

## Runner v2 contract

The requalification runner, adjudicator and truth chain now fail closed on:

- exact AS_LIVE source root versus explicit non-qualifying discovery modes;
- requested versus effective windows and reference rows outside them;
- frozen reference-root/stream-path identity;
- independent non-empty signal identity and outcome-sign identity;
- report History Quality, Bars, Ticks and Symbol count;
- certified versus degraded cost evidence;
- EX5, preset, source manifest, cost registry and override-manifest mutations.

Schema-v1 runs above remain historical evidence but cannot produce a new
candidate under the schema-v2 contract. A technically reproducible run with
degraded costs may remain technical `PASS`, but its qualification status is
`COST_UNCERTIFIED`; adjudicator and truth chain reject it. Relevant suite:
159 tests passing.

## Required next execution

1. Repair mandatory Friday/session flattening so it precedes news/entry gates,
   handles holiday/early-close sessions and forbids post-cutoff entries; update
   the approved execution contract and clean-build the selected sources.
2. Issue and seal a replacement source manifest whose exact risk/set-file
   expectations match the selected percent-risk presets.
3. Close the Top-6 Card/lineage decisions without silently editing APPROVED Cards.
4. Rebuild full identity instrumentation where only native closes are currently
   available.
5. Generate sealed, session-aware continuous-segment references; repeat every
   segment twice with identical hashes.
6. Re-run costs with spread-certified real ticks, current swap parity and
   declared slippage stress.
7. Reconstruct synchronized mark-to-market portfolio equity and Darwinex Risk
   Engine/Rs/Ra proxies; evaluate rolling SILVER return, drawdown and cadence.
8. Only after those gates pass, create a new FULL schema-v2 book candidate and
   pass Adjudicator -> Truth Chain -> Freeze Gate. Resize/deploy remain OWNER
   decisions.

## Safety statement

This audit did not change T_Live presets, binaries, charts, risk, AutoTrading or
orders. No test was executed on T1-T10 or T_Live. T_Live was a read-only identity
and log source; all MT5 evidence runs used isolated `DXZ_Truth_*` sandboxes.
