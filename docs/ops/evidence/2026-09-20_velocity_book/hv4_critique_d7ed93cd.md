# H-V4 cross-vendor critique — task d7ed93cd

Router task: `d7ed93cd-c4f3-4329-adaf-14a8bca526ea`

Research source: `QM-RESEARCH-2026-0012`

Critic: Codex

Scope: read-only audit; this critique is the only task artifact written.

## Per-arm verdicts

| arm | verdict | reason |
|---|---|---|
| USDJPY C2 | **REVISE** | The absolute edge remains credible enough for a canary, but the source does not freeze the same trailing and news-delay semantics that the harness measured; its exact validation worst-year drawdown is 25.04R while the proposed hard bar says retire above 25R; and the claimed uplift over A3 is not significant after a paired, within-USDJPY multiplicity check. |
| USDJPY C3 | **REVISE** | The absolute result is robust and does not breach the stated drawdown bar, but it shares the unresolved build contract and the supplied per-cell null does not establish that C3 is materially better than A3 after dependent arm selection. |
| EURUSD C3 | **REVISE** | The result survives the implementation sensitivities, but it is a marginal secondary finding (SEL PF 1.181) whose block-bootstrap intervals touch zero in both periods and which has no family-level multiplicity test. Carry it only after the shared contract is frozen and a real-tick canary independently clears its bars. |

No arm is rejected: none of the defects or focused sensitivity runs flips the measured sign. No arm is `APPROVE_BUILD` yet because two competent builders can currently implement materially different strategies from the allegedly frozen section.

## 1. Harness and execution audit

### Clock and shifted grid — correct, with a small completeness defect

The clock functions implement `server = America/New_York + 7h` (`velocity_family_f1_sweep_0921.py:75-99`). Direct checks in winter, US-only DST, summer, and the autumn divergence window all map 08:30 New York to 15:30 server and 16:00 New York to 23:00 server. This supports `source.md:85-91` and `research.json:3`.

The shifted-hour aggregation is correctly aligned: `aggregate(..., 3600, 1800)` buckets 13:30-14:30, 14:30-15:30, and so on (`velocity_family_f1_sweep_0921.py:126-137`); the range uses `anchor - 3600*k`, and ATR is read at `anchor - 3600` (`:282-294`). For every shifted hour having both constituent M30 bars, an independent reconstruction from the two M30 OHLC bars matched the harness exactly: 48,870/48,870 USDJPY bars and 48,846/48,846 EURUSD bars, zero mismatches.

The harness nevertheless accepts an hour bucket containing only one M30 component, whereas the frozen source requires pairs of completed M30 bars and says all bars must exist (`source.md:92-100`). Across the candidate span, 3 USDJPY and 2 EURUSD candidate days had at least one required range/ATR hour with an incomplete M30 pair. This is too small to explain the edge, but the builder must reject such a day and the source must state that completeness test explicitly.

### Stop fills, OCO, and same-M1-bar treatment — conservative at entry, approximate thereafter

The pending phase checks whether each stop is still valid at placement, permits one-side-only placement, fills at the touched level, and assigns `-1R - cost` if both edges occur in the same M1 bar (`velocity_family_f1_sweep_0921.py:304-345`). That is a defensible conservative ordering for an otherwise unknowable intraminute path and is infrequent on SEL: 8 USDJPY C2, 5 USDJPY C3, and 1 EURUSD C3 trades. OCO is represented as atomic after the first fill. The incumbent removes the opposite pending order when the open position is observed (`QM5_13213...mq5:323-349`), so this is a reasonable closed-bar approximation, though it does not model an opposite order remaining live while the EA's news gate returns early.

The harness is still optimistic in ways not bounded by the same-bar rule: exact-level fills ignore gaps, spread, stop-level rejection, volume-step rounding, and slippage; trailing is sampled on M1 closes rather than on every tick (`velocity_family_f1_sweep_0921.py:365-377`). The source discloses most of this (`source.md:29-34`, `research.json:11,15-16`), so the real-tick canary is necessary rather than ceremonial.

### Trail contract — internally inconsistent but not sign-flipping

The source freezes activation after profit reaches one **initial** risk and then trails the last two completed shifted-grid bars (`source.md:105-107`; `research.json:3`). The incumbent and the harness instead recompute risk from the **current** SL on every evaluation (`QM5_13213...mq5:350-367`; `velocity_family_f1_sweep_0921.py:365-376`). “Everything is 13213” and “initial SL” therefore specify different algorithms.

An in-memory sensitivity replacing harness line 367 with the initial width `W` left every arm above its proposed E[R]/PF bars:

| arm | period | recorded E[R] / PF / DD | initial-risk trigger E[R] / PF / DD |
|---|---|---|---|
| USDJPY C2 | SEL | .1414 / 1.302 / 20.83R | .1416 / 1.300 / 20.99R |
| USDJPY C2 | VAL | .1441 / 1.295 / 25.04R | .1442 / 1.294 / 24.38R |
| USDJPY C3 | SEL | .1231 / 1.288 / 20.65R | .1240 / 1.289 / 21.43R |
| USDJPY C3 | VAL | .1408 / 1.319 / 22.20R | .1367 / 1.308 / 21.39R |
| EURUSD C3 | SEL | .0756 / 1.181 / 24.68R | .0734 / 1.176 / 24.86R |
| EURUSD C3 | VAL | .1048 / 1.225 / 15.75R | .1034 / 1.222 / 16.51R |

This ambiguity does not invalidate the discovery, but it must be resolved before a card or build. The cleanest “no other logic change” interpretation is the incumbent's current-SL behavior; if initial-risk latching is intended, reseal that as an explicit delta.

### News, Friday, and holiday behavior — disclosed approximation, but not the frozen EA behavior

At an anchor blackout, the harness advances placement to the chained blackout end and blocks only when that is at least one hour after the anchor (`velocity_family_f1_sweep_0921.py:180-198,296-303`). Neither the one-hour order-validity window nor its minute boundaries appear in the frozen source. The framework also caches tester news verdicts per chart bar (`QM_NewsFilter.mqh:1974-1987`), while the harness retries at minute resolution. This matters because the candidate anchor is the dense 08:30 New York release slot: the recorded whole-span states include 280 delayed/91 blocked days for USDJPY C2, 264/87 for C3, and 225/86 for EURUSD C3 (`research.json:16,70-72`; sweep cells).

A strict sensitivity that blocks every day whose anchor is already inside a blackout — rather than executing any delayed placement — did **not** flip the result:

| arm | SEL n / E[R] / PF / DD | VAL n / E[R] / PF / DD |
|---|---|---|
| USDJPY C2 | 865 / .1893 / 1.413 / 15.77R | 577 / .1641 / 1.338 / 21.54R |
| USDJPY C3 | 797 / .1721 / 1.416 / 20.17R | 543 / .1479 / 1.334 / 21.83R |
| EURUSD C3 | 612 / .0948 / 1.229 / 16.79R | 463 / .0977 / 1.207 / 15.72R |

Thus the news approximation is not a sign-flipping defect, and even the stricter SEL trade counts clear the proposed Q02 floors. It still must be frozen as one of: anchor-bar-only, `[15:30,16:30)` retry, or retry-until-flat. The current artifacts imply the second without saying so.

Friday handling itself is correct in the simulation: hard end is `min(23:00, Friday 21:00)` (`velocity_family_f1_sweep_0921.py:262-281,353-358`), matching `source.md:108-110`. Holiday-gap handling does not match “first tick at or after flat”: for a gap over six hours the harness exits retrospectively at the final pre-flat bar close (`velocity_family_f1_sweep_0921.py:353-357`). It affects only one VAL trade in each requested arm (and one EURUSD SEL trade), so it is not sign-flipping, but a live EA cannot take that close without a governed early-close calendar. Freeze either next-tick behavior or such a calendar.

### Control-cell calibration — valid local reconciliation, not a universal +0.02R correction

The USDJPY A3 reconciliation is authentic and within the pre-registered tolerance: 904 vs 888 trades, E[R] .0703 vs .0525, median hold 421.0 vs 419.3 minutes, and 881/886 common days in the same direction (`source.md:29-34`; `research.json:60-62`; `velocity_family_f1_sweep_0921.py:497-548`). The decomposition is important: the mean common/same-direction difference is only +.007R, while 18 simulation-only days add +9.376R. That validates sign and broad mechanics for A3.

It does **not** establish a constant +.02R bias for C2/C3 or EURUSD. Those cells trade another session, interact far more often with news delay, and have different intraminute paths. Treat +.02R as a planning heuristic; only Q02 tester evidence may establish the actual arm-specific gap. The proposed Q02 retire bars appropriately leave more room than .02R, so this is a reason to revise the calibration language, not to reject the arms.

## 2. Multiplicity and the “2× incumbent” claim

The source is candid that 314 cells were searched and that the per-cell bootstrap is not a family-level test (`source.md:133-142`; `research.json:11,13,25,65-67`). The implementation confirms the limitation: it bootstraps each cell separately, then sums marginal probabilities and multiplies SEL and VAL probabilities (`velocity_family_f1_sweep_0921.py:462-494,585-604`). With only 200 resamples, probabilities move in .005 increments. The 13 observed survivors are clustered: eight are USDJPY cells, so `13 vs 5.481 expected` cannot be read as 13 independent confirmations.

There is also a registration-accounting discrepancy. The committed registration says 369 cells = 41 symbols x 3 x 3 and describes 33 FX symbols (`VELOCITY_FAMILY_F1...md:47-63`), while the delivered harness enumerates 28 FX + 2 metals + 6 indices (`velocity_family_f1_sweep_0921.py:51-56`). It evaluates 314 cells with trades after JPN225 has no history and GDAXI A4 has no trades. `research_trial_count=314` is honest for computations actually run, but the source should reconcile why the pre-registered 41-symbol universe became 36 rather than silently calling both grids frozen.

To test the claim the supplied null does not test, I independently formed paired daily-R differences between each USDJPY cell and A3, preserved cross-cell dependence, and resampled 5,000 circular blocks of 20 business days. This was a critic sensitivity, not a replacement for a governed pre-registered test:

| candidate vs A3 | observed delta R/bd | paired 95% interval | within-USDJPY multiplicity sensitivity |
|---|---:|---:|---:|
| C2 SEL | +.0660 | [-.0302, +.1599] | max-of-8 p=.1644 |
| C2 VAL | +.0395 | [-.0953, +.1817] | max-of-8 p=.5468 |
| C3 SEL | +.0429 | [-.0446, +.1316] | second-order p=.2458 |
| C3 VAL | +.0304 | [-.0866, +.1504] | second-order p=.4702 |

Therefore the descriptive arithmetic “roughly twice R/bd” is true, but the evidence does not establish a statistically material improvement over A3 after choosing among eight alternatives. The stronger claim needs a pre-registered paired C2-A3/C3-A3 daily-difference test or a joint symbol-family max statistic. This matters for the **replacement** claim, not for whether an inexpensive canary may be run.

Unadjusted 20-business-day block intervals for absolute R/bd distinguish the arms:

| arm | SEL R/bd (95% interval) | VAL R/bd (95% interval) |
|---|---:|---:|
| USDJPY C2 | .1201 [.0487, .1911] | .1163 [-.0006, .2468] |
| USDJPY C3 | .0970 [.0363, .1570] | .1072 [.0152, .2113] |
| EURUSD C3 | .0469 [-.0077, .1015] | .0685 [-.0118, .1589] |

This supports retaining both USDJPY arms for revision/canary, while keeping EURUSD explicitly secondary. It does not cure the 314-cell family multiplicity.

## 3. Buildability audit

The price logic is mechanically expressible from M30 data, and the verified shifted-grid reconstruction shows no obstacle. The frozen section is not yet single-valued, however. Before build authorization, revise and reseal `source.md` to state:

1. Runtime/new-bar contract: M30 chart/set-file timeframe or an explicit `QM_IsNewBar(_Symbol, PERIOD_M30)` gate; exact shift-1 pairing and rejection of either missing M30 half-bar.
2. Entry eligibility after a news block, as minute-of-day bounds. The harness currently uses an anchor-relative one-hour window; the source merely says “first tick at or after 15:30.”
3. Trail activation state: incumbent current-SL distance or latched initial `W`; do not say both “unchanged” and “initial risk.”
4. Holiday/market-gap exit: next available tick, or a named governed early-close calendar. The harness's retrospective previous close is not directly buildable.
5. OCO guarantee and failure handling: retain both stop-send results, remove the peer immediately on the fill transaction/next tick, and define the fail-closed action if only one send succeeds. This must remain one position per symbol/day.
6. Venue clock contract: 15:30/23:00 may be fixed only for DXZ; FTMO must use the named session-clock helper described at `source.md:85-91` before any FTMO set is admitted.

Those are contract clarifications, not permission for parameter search or another sweep.

## 4. Falsification bars

- **Q02 trades/E[R]/PF:** the bars at `source.md:146-152` are explicit and directionally consistent with the calibration margins. The stricter blackout sensitivity still clears the SEL trade-count floors (865>800, 797>740, 612>580) and all E[R]/PF floors. Keep the calibration alarm distinct from retirement.
- **70% holdout:** the arithmetic passes on the recorded harness and on the strict-blackout sensitivity. But the 70% rule was added in the sealed source after the 2023-25 results were observed; it is absent from the pre-sweep registration at `VELOCITY_FAMILY_F1...md:71-89`. It is now a pre-registered build regression bar, not fresh holdout evidence. Label it that way.
- **Q05 25R:** C3 and EURUSD C3 are below the bar. C2's recorded VAL worst-year drawdown is **25.04R** (`research.json:35-37`), while `source.md:155-156` says retire above 25R. Do not round 25.04 to 25.0 to pass. Specify whether the rule applies only to the Q05 report and which exact Q05 drawdown field/window is authoritative; otherwise C2 is already over its literal cap.
- **Q08 replacement rule:** `|r| >= .5` correctly makes H-V4 a replacement candidate rather than an additive sleeve (`source.md:157-161`; `research.json:14`). Until Q08 measures it, no artifact should claim independent book capacity. The rule needs no loosening.
- **Activity:** the >=10 entry-days/year bar is comfortably supported by the harness (`source.md:162`).

## 5. Focused verification record

- Relevant source, extract, and sweep paths were clean in git before this critique.
- Bound hashes verified:
  - full sweep SHA-256 `c9ad5d139e8e77d514d9811806ee5178ef3f4704b5892bb89053d8956d82c6a5`;
  - extract SHA-256 `247c595106904451c162f5ed6296abe09790d46f01195d26e8b8bde7a1b6e6ea`;
  - `research.json` SHA-256 `de6f882c697f6d469801ad53ab79f070771fe762ca31e1dcbf00e973dbc09f2d`;
  - `lineage.json` SHA-256 `e335665710b9f746a142ca008f681fc980388ba04f4270867aa630c58db4ed25`.
- `research_source.py verify --id QM-RESEARCH-2026-0012` reports only `LEDGER_STATUS_BAD:draft`; no hash/provenance failure.
- Baseline USDJPY C2/C3 and EURUSD C3 were rerun in memory and reproduced the stored metrics shown in `research.json:30-57`.
- Focused independent checks performed: DST clock round trips, M30-pair equivalence/completeness, strict anchor-blackout sensitivity, initial-risk trail sensitivity, absolute block intervals, and paired/dependent comparison against A3.
- No source, card, ledger, farm row, EA, set file, or sweep artifact was edited by the critic.

## Required disposition

Return all three arms to the research author for one bounded source revision covering the six build-contract items and the C2 25R conflict. Reseal without parameter changes, then obtain a fresh cross-vendor decision. If accepted after that revision, build/test USDJPY C2 and C3 as separate frozen arms; keep EURUSD C3 secondary and do not treat any arm as additive to QM5_13213 before Q08.
