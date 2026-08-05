# QM5_20218 WTI Winter Reversal Build And Q02 Enqueue

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency energy candidate was researched, approved,
allocated, built, strictly validated, committed, and handed to paced Q02:

- EA: `QM5_20218_wti-winter-rev1`.
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202180000`.
- Mechanic: on the first tradable D1 bar of each November-May broker month,
  sell after a positive exact completed broker-month return and buy after a
  negative return; remain flat June-October.
- Lifecycle: close before monthly renewal, one consumed attempt per eligible
  month, forty-day stale guard, `3.5 * ATR(20,D1)` hard stop, and no target.
- Maximum cadence: seven decisions/year; retire below five completed
  packages/year after warm-up.
- Q01: PASS with zero compile errors/warnings and zero build-check
  failures/warnings.
- Backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Q02: exactly one priority-track work item enqueued. Screening remains
  unadjudicated; no profitability, decorrelation, certification, or portfolio
  verdict is claimed.

## Sources And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-YANG-WTI-WINREV1-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply the fixed November-May WTI
  seasonal partition from a named-author, peer-reviewed, complete open paper.
- Yang, Goncu, and Pantelous (2017), *Momentum and Reversal in Commodity
  Futures*, SSRN 3069253, supply the named-author academic commodity-reversal
  lineage.

Neither source tests this exact interaction. Burakov et al. report a positive
unconditional winter sample, so the candidate's price-conditioned short after
a positive month is a deliberate falsification risk rather than a transferred
source claim. The Darwinex CFD carrier, exact broker-month reconstruction,
monthly renewal, fixed risk, ATR stop, and QM portfolio objective are also QM
translations. No source performance, CFD basis, frequency, drawdown, or
correlation statistic transfers.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,275 registry rows and 391
cards. It found no exact identity and the two expected fuzzy siblings:

- `QM5_20209_wti-winter-mom1` shares the winter gate and exact prior month,
  but follows its sign; this candidate takes the opposite side.
- `QM5_20214_wti-sum-rev1` shares the opposite-sign map, but operates in the
  disjoint June-October window.

Manual review also separates the candidate from weekly winter bear-fade,
unconditional winter-long, 252-D1 winter-trend, year-round 120-D1 reversal,
weekly 20-D1 reversal, and `QM5_12567` two-day oscillator builds. The fixed
November-May gate, exact completed broker-month endpoints, opposite-sign map,
monthly renewal, and June-October flat state are jointly load-bearing.

## Allocation And Commits

- Research source packet, G0 decision, and canonical card: `478a3b740`.
- Registry row, magic row, regenerated resolver, and initial backtest set:
  `a9a7d40f7` (paced artifact-pump commit).
- EA source/binary, SPEC, approved/build card reference, Q01 status, and final
  fixed-risk set hash: `ba6b7bc7a`.
- EA registry: `20218,wti-winter-rev1`.
- Magic registry: `XTIUSD.DWX`, slot 0, magic `202180000`.
- Generated resolver: 15,487 rows kept, zero dropped, registry SHA-256
  `991834B3BB3AD77C437F4A28520B19FF101FAC4BC962516D30BD2489F8A12417`.

The paced artifact pump captured exactly the new registry, magic, regenerated
resolver, and initial generated setfile paths while the build was in progress.
The final source, binary, and set build hash were committed explicitly.

## Q01 Evidence

- Canonical and approved card schema lints: PASS; no missing sections or
  forbidden-library hits.
- G0 card guards: PASS.
- EA build authorization guard: PASS for EA ID 20218 and its magic row.
- Seven-section SPEC validator: PASS.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- Resolver tests: four passed.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_033105/QM5_20218_wti-winter-rev1.compile.log`.
- Compile summary:
  `D:/QM/reports/compile/20260805_033105/summary.csv`.
- Final strict V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260805_033247.json`.
- EX5 size: 371,070 bytes.

The repository-wide registry validator reports 1,412 pre-existing legacy
issues and exits nonzero. A target-filtered read found zero issue containing
EA 20218, `wti-winter-rev1`, or magic `202180000`; all candidate-specific
registry and build guards passed. No unrelated registry debt was modified.

Artifact SHA-256 values after the Q02 status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `DDD46B476A9B9AE2A296BD2594C50EE7BDAF420E96C10CF935CC2D34D1D102AF` |
| Canonical card | `89599C0060937B625A2E48FE96B605C8E7B665B91303E8ED47A37316D1E54516` |
| Approved card | `89599C0060937B625A2E48FE96B605C8E7B665B91303E8ED47A37316D1E54516` |
| MQ5 | `CD0AFB2F67B0D06F6FE360D4D1675C5642CAB61F1087CD51F41298725AF9D66A` |
| EX5 | `C644E8631584C4DEE2E25AB0B61FFFEE74FB07567866EDF551DD551B3213A10C` |
| SPEC | `3159DE289D35253A79C3FFCC39D9D6D954C029F074BEA6B7FB4C55F97388D9E4` |
| Backtest set | `184FA253995F94F1869233C028FCDBA80C4080B5EE8843241CEFA7CB7EF3009E` |

## Q02 Handoff

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20218 --symbols XTIUSD.DWX --max-part2-per-run 0

It selected exactly one `never_tested` item, zero stranded items, and one
priority-track item. The immediate factory-only process scan at
`2026-08-05T03:34:56.1180682Z` found three active terminals (`T2`, `T7`,
`T8`), below the seven-terminal CPU ceiling.

The identical scope plus `--apply` inserted exactly one row:

| Field | Value |
|---|---|
| Work item | `0838049f-0a49-48ca-8b4b-5a33bdcd0606` |
| Phase / kind | Q02 / backtest |
| EA | QM5_20218 |
| Symbol | XTIUSD.DWX |
| Setfile | `QM5_20218_wti-winter-rev1_XTIUSD.DWX_D1_backtest.set` |
| Created UTC | `2026-08-05T03:35:02+00:00` |
| Initial confirmation | pending, attempt 0, unclaimed |
| Later read-only observation | active, attempt 0, claimed by T3 |

The apply began below the 7,000-row queue ceiling; a later read-only query
counted 1,603 pending rows and exactly one `QM5_20218` row. The state change
from pending to active was performed by the paced fleet after enqueue, not by
a manual tester launch. `ENQUEUED` records the handoff only and does not claim
a Q02 verdict.

## Safety Boundary

- No manual backtest or downstream phase was launched.
- No live/demo/shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- No `T_Live` terminal, file, setting, health check, or manifest was opened or
  changed.
- The portfolio gate and T_Live manifest were not touched.
- No terminal was started, stopped, reserved, reaped, or altered.
- The factory mutation lock and queue ceiling were not bypassed.
- Existing unrelated working-tree changes were preserved and excluded from
  every task commit.
