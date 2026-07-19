# DXZ-23 Cost-Adjusted Candidate Cohort — 2026-07-16

## Verdict

This is a fail-closed repair queue, not a promotion decision. It does not
approve a Strategy Card, EA, DARWIN book, resize, deploy, or live action.

- 21/23 sleeves have a selected, non-empty native report and a Darwinex Zero
  round-trip commission test at 0.005% of nominal (0.5 basis points).
- 18/21 economically evaluable sleeves remain at or above commission-adjusted
  PF 1.10, which is 18/23 of the full book; 14/21 reach PF 1.20. They are
  repair candidates only: Tier A 3, Tier B 5, Tier C 10.
- 5/23 are `REJECT/REPAIR`: three fall below PF 1.10 after the conservative
  commission charge, one has zero trades under the currently bound slot, and
  one has no technically valid non-empty native report.
- None of the 23 has complete spread, current swap, slippage, continuous
  B/C/D-segment, lineage, and execution-governance evidence. Consequently none
  is deployment-eligible and the table must not be read as “18 sustainable
  strategies”.

The economics below use the conservative commission result, not the native
gross PF. Values are in the EUR tester account. `Net` and `DD` are
close-to-close values after recorded tester swap and the conservative 0.005%
(0.5 bp)
commission bound. This is deliberately harsher than the central estimate.

## Bound evidence

The cohort was derived only from the following bound inputs. A later change to
any input requires regenerating this document.

| ID | Path | SHA-256 / binding |
|---|---|---|
| C0 | `D:\QM\reports\portfolio\dxz_cost_evidence_20260716_v3\report.json` | file `98ea8553f4fb6044d757e90c964c8b6fda4f8f40f653e75510833f8f49c694fd`; canonical payload `a3cd2748ddffd571152203bf6485eaeb8b1285614715929523e4e9ce2314fbb6`; implementation `fc37251fc519345ed80187e4ade15c7a84b4bc3e826b4f198c1b47a1d1833ec2` |
| H0 | `docs/ops/evidence/DXZ23_REFERENCE_HORIZON_AND_DATA_GAPS_2026-07-16.md` | `fe9b3d4d9d98ed529a7cba0ed2554a015d2dc8b42a067ac8d47b22a93886c914` |
| X0 | `framework/registry/dxz23_execution_contracts.json` | `b0f0550e9ff1baf237770fb3faf8cdaee63ee9d5db59b0bf67679fc1610e8798` |
| A0 | `D:\QM\reports\portfolio\dxz23_audit_requal_input_20260715T221618Z` | source manifest `ee47e67f8c9a006452ca39672f8165668381fa78e90999e05a249ac810868ac7`; reference manifest `ad2916865261435c6af0de168734e028714d71011ad1e5a0479105aa2c221940`; seal `4b2d84be0fccfd701e4ce94ced04c30402ca57ff9baa4cb4ec3a05f9bea2cf83` |
| E1 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_hardened\20260716T051551Z\summary.json` | `523b6e1ef9a96ec5e820ae039e5272b9673c65e492ac4d1bd93863d52a2be169` |
| E2 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_technical_retry\20260716T060039Z\summary.json` | `800037435d54bd1bc2a74146cbd08db8714bb9e8f454c03d93d156fff680b50d` |
| E3 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_effective_h1_staged_serial\20260716T071056Z\summary.json` | `d02d69d0e5915801791c6ed98ea77759be012c58c9998b2a7068d89d952467e4` |
| E4 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_effective_h4_staged_serial\20260716T075313Z\summary.json` | `5032cca4d58ba5ae4965560998b95adff8940072ac5bbb19c6cdfb8e55cc7925` |
| E5 | `D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_effective_d1_staged_serial\20260716T080201Z\summary.json` | `af55e04a33016aac2d7b582c37440c63c351944ec4fcdfe3a577055b76967181` |

C0 explicitly binds every selected report and receipt path and its SHA-256.
It supersedes immutable schema v1/v2. Those artifacts used the correct numeric
rate `0.00005` and therefore produced the same 21 economics, but incorrectly
labelled 0.005% as 5 bp; the correct conversion is 0.5 bp. Historical real-tick
spread embedding is not current broker-spread parity certification.
The `Ev` column below identifies the bound run and run directory. For the two
C0 exclusions, the failing E1 receipts are bound separately in their row.

## Classification rule

The hierarchy is deterministic and intentionally does not rank by PF alone:

1. `REJECT/REPAIR` if conservative PF is below 1.10, the selected run has zero
   trades, or no technically valid non-empty report exists.
2. `TIER C` if PF is at least 1.10 but the evidence demonstrates a substantive
   strategy-defining Card, preset, source-exit, threshold, calendar, stop, or
   deployed-binary lineage conflict. A generic requalification requirement by
   itself is not enough to infer drift.
3. `TIER A` if PF is at least 1.30, there are at least 50 trades, signal or
   native-close reproduction is strong, no host-horizon defect is present, and
   the remaining identity work is comparatively direct.
4. `TIER B` for the remaining PF-at-least-1.10 sleeves whose primary defect is
   reference horizon, legacy instrumentation, weak margin, or a small sample.

Evidence quality is considered before PF margin, then trade count and repair
complexity. Tier A means “repair first”, not “approve”.

## Exact 23-row cohort

`C` is commission evidence: `P` complete, `B` conservatively bounded but still
fail-closed, and `—` unavailable. `HQ` is tester history quality and is not by
itself a spread certificate. Run folders are relative to the E1-E5 paths above.

| # | Sleeve | Cohort | Trades | PF 0.005% | Net EUR | DD EUR | HQ / C | Ev | Decisive evidence and open sleeve-specific gate |
|---:|---|---|---:|---:|---:|---:|---|---|---|
| 1 | 10403 XAUUSD D1 | `TIER C` | 209 | 1.306 | 3183.78 | 1543.31 | 91% / P | E1/`01_10403_XAUUSD_DWX` | Exact Q08 identity, but Friday 21:00 replaces the Card's continuous-channel exit in 187/209 trades; Card/Friday ablation and binary requal required. |
| 2 | 10440 NDX H1 | `REJECT/REPAIR` | 193 | 0.486 | -10007.26 | 12365.06 | 83% / P | E1/`02_10440_NDX_DWX` | Economic reject under current preset; additionally live `.07/.65/3.25` differs from Card `.10/.50/2.50` and the legacy NDX news binary is unresolved. |
| 3 | 10476 USDCAD H1 | `TIER B` | 299 | 1.260 | 4880.15 | 1487.10 | 100% / P | E3/`03_10476_USDCAD_DWX` | Proven truncated host reference: 257 old closes versus 299 current, with 42 added 2025 closes; rebase continuous segments, repair Q08 identity, repeat twice. |
| 4 | 10513 XAUUSD D1 | `TIER C` | 104 | 1.958 | 7003.40 | 1069.30 | 100% / P | E2/`04_10513_XAUUSD_DWX` | Strong economics cannot choose the strategy: live `6/18/68, ATR18` conflicts with Card/default `9/26/52, ATR14`; owner-approved lineage and same-data ablation required. |
| 5 | 10692 NDX H1 | `REJECT/REPAIR` | 529 | 0.370 | -30596.62 | 31395.05 | 83% / P | E1/`05_10692_NDX_DWX` | Economic reject; legacy NDX news-binary drift and later NDX history copy `R` remain separate repair questions. |
| 6 | 10715 USDJPY M15 | `REJECT/REPAIR` | 0 | — | — | — | — / — | E1/`06_10715_USDJPY_DWX`; receipt `36dc9873e50aef9518606b1f8049e5969de14245de76291263ba32a1160ec2bf` | Zero-trade run; sealed slot 2 is magic/symbol-misbound to GDAXI while the correct USDJPY slot is 4. Rebind before any economics test. |
| 7 | 10911 GDAXI H1 | `REJECT/REPAIR` | — | — | — | — | — / — | E1/`07_10911_GDAXI_DWX`; receipt `a32dedf1b8616738afd768619169c27dc4c39d1d6f9a0f1d5ba420fc931f87f5` | No technically valid non-empty native report. Approximate triage counts are not admissible; repair binary/Q08 and create a fresh sealed receipt. |
| 8 | 10919 XTIUSD H4 | `TIER B` | 30 | 4.784 | 6662.32 | 1405.58 | 91% / P | E1/`08_10919_XTIUSD_DWX` | Exact native-close sequence and large margin, but only 30 trades; legacy Q08, Card-v2 interpretation, Friday, and commodity spread/swap gates remain. |
| 9 | 10939 GBPUSD H4 | `TIER A` | 92 | 1.583 | 3888.27 | 1139.91 | 100% / B | E4/`09_10939_GBPUSD_DWX` | Exact native-close sequence; repair legacy Q08/Card-v2 and six bounded commission rows. Current source is additionally blocked because active news returns precede mandatory Friday close and no session-aware early-close fallback exists. |
| 10 | 11132 SP500 D1 | `TIER C` | 75 | 1.424 | 3327.88 | 1618.76 | 83% / P | E1/`10_11132_SP500_DWX` | Edge is plausible and `SP500.DWX -> SP500` is routable, but Card/default versus live parameters, source exit, Friday, active news axes, stale Card routing text, and binary lineage are unresolved. |
| 11 | 11165 AUDCAD H1 | `TIER C` | 133 | 1.146 | 1299.30 | 1902.11 | 100% / P | E3/`11_11165_AUDCAD_DWX` | Exact native-close sequence but thin margin; deployed binary hash and canonical stream are not bound to repo source, with Q08 and Friday still open. |
| 12 | 11165 EURUSD H1 | `REJECT/REPAIR` | 260 | 1.066 | 838.88 | 1530.67 | 100% / P | E2/`12_11165_EURUSD_DWX` | Falls below PF 1.10 after conservative commission; binary/stream lineage and Friday remain unresolved but do not rescue the current economics. |
| 13 | 11421 AUDUSD D1 | `TIER B` | 90 | 1.160 | 1502.52 | 2112.16 | 100% / P | E5/`13_11421_AUDUSD_DWX` | Proven truncated D1 reference: 81 old versus 90 current closes; rebase continuous segments and replace legacy Q08 before retesting the thin margin. |
| 14 | 11421 EURUSD D1 | `TIER B` | 92 | 1.151 | 1346.20 | 2102.29 | 91% / P | E1/`14_11421_EURUSD_DWX` | Exact native-close sequence but legacy Q08, Friday, binary repeat, sub-100% history quality, and a thin PF margin remain. |
| 15 | 11708 EURUSD D1 | `TIER C` | 178 | 1.320 | 2975.44 | 2032.16 | 91% / P | E1/`15_11708_EURUSD_DWX` | Exact Q08 identity and adequate sample, but the approved Card has conflicting R1 status, is marked incomplete, and does not qualify the Friday override. |
| 16 | 12567 XAUUSD D1 | `TIER A` | 73 | 1.574 | 3540.06 | 1717.32 | 100% / P | E5/`16_12567_XAUUSD_DWX` | Exact native-close sequence with good margin; repair full Q08/binary identity and commodity costs. Current source is blocked because active news returns precede mandatory Friday close and no session-aware early-close fallback exists. |
| 17 | 12567 XNGUSD D1 | `TIER C` | 49 | 1.715 | 2791.22 | 1207.54 | 91% / P | E1/`17_12567_XNGUSD_DWX` | Current threshold 30 conflicts with Card/reference 35; small sample plus commodity spread/swap, Friday, and binary gates remain. |
| 18 | 12778 AUDUSD/EURJPY D1 | `TIER B` | 210 | 1.193 | 2265.91 | 1646.03 | 100% / P | E5/`18_12778_AUDUSD_DWX` | Proven host-D1 horizon defect with 194 exact-prefix identities; rebase intersected basket segments, fix Q08 forced-exit omission and wrong-currency annex, repeat twice. |
| 19 | 12969 USDJPY M30 | `TIER C` | 331 | 1.545 | 6136.93 | 876.36 | 91% / B | E1/`19_12969_USDJPY_DWX` | Exact Q08 identity and strong sample, but Card says no fixed stop while the EA's active 120-pip stop triggers 2/331 times; one zero-move cost ambiguity and Friday remain. |
| 20 | 12989 XAUUSD H4 | `TIER C` | 51 | 1.708 | 3489.12 | 1536.48 | 100% / P | E2/`20_12989_XAUUSD_DWX` | Exact Q08 identity and good margin, but no canonical approved Card exists and Friday/commodity execution semantics are unqualified. |
| 21 | 13128 NDX H1 | `TIER C` | 56 | 2.260 | 4282.38 | 943.73 | 83% / P | E1/`21_13128_NDX_DWX` | Exact Q08 identity, but Card calendar ends in 2025 while source extends through 2026; Friday, binary, event table, and changed NDX history `R` require synchronized requal. |
| 22 | 1556 XAUUSD D1 | `TIER C` | 53 | 1.883 | 3952.28 | 1267.56 | 91% / P | E1/`22_1556_XAUUSD_DWX` | Exact Q08 identity, but Friday close changes the monthly source exit semantics; native-exit versus override ablation plus commodity execution certification required. |
| 23 | 10706 GBPUSD H1 | `TIER A` | 367 | 1.329 | 3899.95 | 895.78 | 100% / P | E3/`23_10706_GBPUSD_DWX` | Entries/outcome signs reproduce. Before a new reference, repair the active-news-before-Friday ordering and session-aware early-close fallback, then bind the selected as-live percent/EUR risk contract and repeat the new binary. |

## Independent open gates

These gates are intentionally separate. Passing one must never imply another:

1. **Commission (`C`)** — 19 selected sleeves are `COMPLETE`; 10939 and 12969
   are conservatively bounded but remain fail-closed because 6 and 1 trades,
   respectively, have zero move/zero P&L ambiguity. 10715 and 10911 have no
   usable cost evidence. The registry's mixed USD-flat/EUR-notional `max()` was
   excluded as dimensionally uncertified.
2. **Spread (`S`)** — open for all 23. A `100% real ticks` tester label means
   spread was embedded in that particular run; it does not independently bind
   broker spread parity. Any `91%` or `83%` row additionally fails the
   prerequisite for claiming full real-tick spread evidence.
3. **Swap and slippage (`W`)** — open for all 23. Recorded tester swap is
   included in the figures, but current broker swap-rate parity is not
   certified. Slippage is `NOT_EVALUATED`.
4. **Continuous history (`G`)** — open for all 23. No pooled B/C/D-spanning PF
   may qualify. Score session-aware continuous segments independently, warm up
   inside each segment, prohibit positions across gaps, intersect all host/leg/
   conversion histories for baskets, and require two hash-identical repeats.
5. **Identity and instrumentation (`I`)** — an exact native close sequence is
   not full signal identity. Legacy Q08 rows need non-empty entry/exit identity,
   independent outcome-sign evaluation, and a content-addressed replacement
   reference. Horizon-defect references must be rebased, not forced to match.
6. **Card/source/preset/binary (`L`)** — every substantive conflict in X0 needs
   an owner-approved resolution and a same-data ablation where semantics can
   change trades. No approved Card is silently edited.
7. **Friday (`F`)** — adjudicate independently from the strategy signal. 10706
   is Card-declared; 12778 declares framework Friday close but still needs the
   canonical basket requal. All other overrides or semantic conflicts remain
   open exactly as X0 records.
8. **News/calendar (`N`)** — open only where used or disputed, notably legacy
   NDX news binaries, 11132's active news axes, and 13128's event table. A
   `calendar.policy=NONE` row does not inherit a news pass from another sleeve.

## Top-6 repair sequence

This order maximizes the chance of closing evidence quickly while retaining PF
margin and sample size. It is not the composition of a final DARWIN book.

1. **10706 GBPUSD H1** — 367 trades, PF 1.329, reproduced entries/outcome
   signs and complete commission bound. First repair news-before-Friday and
   session-aware flattening; then create a correct percent-risk/EUR reference, emit full identity, and run two
   independent segment-safe repetitions.
2. **10939 GBPUSD H4** — 92 trades, PF 1.583, exact native closes. Repair Q08,
   resolve six bounded cost ambiguities, migrate the Card interpretation,
   implement mandatory session-aware close before news returns, then repeat on B/C/D-safe segments.
3. **12567 XAUUSD D1** — 73 trades, PF 1.574, exact native closes and complete
   commission evidence. Add full identity, repair mandatory session-aware close
   ordering, bind the Friday directive/binary, then close commodity spread and current-swap evidence.
4. **10476 USDCAD H1** — 299 trades, PF 1.260, and a proven reference endpoint
   defect rather than unexplained signal drift. Rebase the host reference on
   continuous segments, repair instrumentation, and repeat twice.
5. **11708 EURUSD D1** — 178 trades, PF 1.320, exact Q08 identity. Resolve the
   contradictory/incomplete Card and Friday policy before any ablation and
   serial requalification.
6. **12969 USDJPY M30** — 331 trades, PF 1.545, exact Q08 identity. Obtain an
   explicit owner decision on no-stop versus active 120-pip stop, run the
   two-variant ablation, resolve the one bounded cost ambiguity, and requalify.

High raw ranks deliberately omitted from the first six include 10513 (which
strategy is canonical is unresolved), 13128 (calendar plus changed NDX history),
1556 (Friday changes source exit semantics), 12989 (no approved Card), and
10919 (only 30 trades plus commodity and Card-v2 work). Their high PF cannot
substitute for lineage or sample evidence.

## Later DARWIN book-level gate

Sleeve PF is only an upstream filter. A proposed book must subsequently be
evaluated on rolling DARWIN outcomes and portfolio interactions. The current
official DarwinIA SILVER rating uses current-calendar-month return (22%), the
previous five months plus current-month cumulative return (67%), and maximum
drawdown across the same six calendar months (11%); participation also requires
at least one trade in the current or prior month. The official page states that
a month-end rating of 75 is the allocation threshold:
<https://help.darwinex.com/what-is-darwinia> and
<https://www.darwinexzero.com/docs/rating>.

The book must also be assessed for Risk Stability (`Rs`) and Risk Adjustment
(`Ra`), because stable sleeve PF does not prove stable underlying VaR or low
Risk Engine intervention. Darwinex defines Rs as risk stability across
positions and Ra as the intervention required from its Risk Engine:
<https://help.darwinex.com/risk-stability-attribute> and
<https://help.darwinex.com/risk-adjustment-attribute>.

Therefore the Top-6 is a repair priority only. It cannot become the final book
until a sealed portfolio simulation passes rolling SILVER return/drawdown/trade
cadence, cross-sleeve correlation/concentration, Rs/Ra proxies, and all
execution-economics gates above.

## Decision

Proceed serially with the Top-6 repair queue while keeping every sleeve
fail-closed. Do not resize, promote, deploy, or claim DarwinIA readiness from
this cohort. Recompute the matrix after each Card/lineage decision or new
segment-safe reference; never carry the current PF forward across a changed
strategy contract.
