# QM5_20289 WTI Signed-Semivariance Reversal — Q01 PASS / Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20289_wti-rsj-rev` is a new low-frequency outright-WTI structural
reversal candidate. It is built, Q01 is `PASS`, and exactly one
current-binary `XTIUSD.DWX` row was enqueued to Q02 below the path-anchored
factory CPU ceiling. Work item
`41d6f237-cc5e-46ec-8048-1722c398a110` was pending at immediate readback,
attempt 0, unclaimed, with no verdict. This mission issued no dispatch tick and
ran no manual backtest.

## Edge And Non-Duplicate Boundary

On the first processed D1 bar of a genuine broker-month transition, the EA
selects adjacent completed WTI closes whose two timestamps are wholly inside
the immediately preceding broker month. It computes log returns, separates
squared positive and negative returns, and forms:

```text
RV_plus  = sum(r[d]^2 where r[d] > 0)
RV_minus = sum(r[d]^2 where r[d] < 0)
RSJ      = (RV_plus - RV_minus) / (RV_plus + RV_minus)
```

It requires 15-25 returns, positive finite total variance, and normalized RSJ
inside `[-1,1]` within `1e-12`. Zero returns count as observations but add
to neither semivariance. Negative RSJ buys, positive RSJ sells, and exact zero
or any invalid state consumes the month flat. Entries have a frozen
`3.5 * ATR(20,D1)` hard stop, no take-profit, monthly renewal, and a
forty-day stale exit.

The canonical pre-card duplicate check scanned 4,354 EA-registry rows and 466
root cards. It found no exact identity and two expected source-family fuzzy
matches. Manual review separated the closest neighbors:

- `QM5_13129_energy-rsj` ranks simultaneous XTI and XNG RSJ states, buys one
  leg, shorts the other, and manages a two-leg package. This EA has one WTI
  state, no rank or orphan logic, and reverses absolute RSJ around zero. The
  parent's negative Q02 economics and Q04 failure are disclosed, not repaired
  or inherited.
- `QM5_20234_xauxag-rsj` is a paired precious-metal rank carrier with two
  magics and equal-risk legs, not an outright WTI zero-pivot time-series rule.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only RSI pullback
  behind a slow filter.
- Ordinary WTI cumulative, return-reversal, calendar, event, breakout,
  robust-location, rank, and variance-ratio candidates use different
  information objects, directions, or clocks.

A Hodges-Lehmann WTI momentum candidate was rejected before card creation
because deterministic review found the already-built
`QM5_20276_wti-hl-mom` mechanic. Verdict for the selected edge:
`CLEAN_AFTER_MANUAL_CROSS_SECTIONAL_TO_TIME_SERIES_REVIEW`.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier and statistic novelty do not establish realized decorrelation;
unchanged downstream gates, including Q09, own that conclusion if the
candidate survives Q02-Q08.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/KISS-WTI-RSJ-REV-2026/source.md`. Its complete-read
parent is Kiss and Ferreira Batista Martins (2025), *Good Volatility, Bad
Volatility and the Cross Section of Commodity Returns*, *Finance Research
Letters* 86 Part D, 108656, DOI `10.1016/j.frl.2025.108656`. The governed
twelve-page parent read explicitly includes WTI among 36 commodity futures.
Parent `source.md` SHA-256:
`87679A706DA34734A845C5BC932DEB75603B3B9B03D56BC88A8CFEC779ACACC8`.

The source defines normalized signed semivariance and documents a negative
cross-sectional commodity premium. It does not test the absolute zero-pivot
time-series rule, the Darwinex continuous CFD, broker-month reconstruction,
lifecycle, or risk overlay; those are disclosed pre-result QM hypotheses and
mechanizations. Durable G0 authorization is
`decisions/2026-08-12_qm5_20289_wti_rsj_rev_g0.md`.

R1-R4 pass: one peer-reviewed named trading source with DOI, complete governed
read and durable hash; exact mechanical rules; a registered WTI D1 route; and
deterministic native arithmetic without ML, trained output, prohibited signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20289` / `wti-rsj-rev` /
  `KISS-RSJ-2025_XTI_TS_S03`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202890000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The target EA-ID and magic rows each occur exactly once. Resolver generation
  kept 15,894 rows and dropped zero. Its embedded registry SHA-256 is
  `B19987BECFDD700BE545E396FC02C580B7C38D4D53384FF80325C7FF6E143F2C`.
- Strict compile:
  `D:/QM/reports/compile/20260812_074558/summary.csv`, PASS with zero errors
  and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260812_074558/QM5_20289_wti-rsj-rev.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260812_074442.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20289/P1/P1_QM5_20289_result.json`, PASS.
- Independent statistic test:
  `framework/EAs/QM5_20289_wti-rsj-rev/docs/test_rsj_reference.py`, PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/intake/build-card content synchronization: PASS.
- Setfile header build hash:
  `6c0ee82d0e7fad72d9b66a947e7c0d22fbf1430ffc9dcb2f97fc5c1a36cadf56`.
- Manual smoke/backtest: none.

Final repository artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `F799A19A5EA36E81A78AE9917206817431D7081545A924270A0F49E98DC8042F` |
| Bounded source packet | `4C5A9388D9870125A84CECECE9BBEDA7A3CE7DCB953EA3BB6464DB9AC4DC9AF4` |
| Canonical/intake/build card | `EC058F7DDD280F58210D5B955F0C408324754B21A449BC676F46C5C2F26A92B0` |
| MQ5 | `487B85A0146FB2C87DC11E62120160F5CF462D7C9AEEF90D99E79E96C4E9EE98` |
| EX5 | `E2B6D0493D19067719D03CBB12D7DBB37E148631464BEEA5B3A152F9347B50FF` |
| SPEC | `1823E07748C02FC8B89D68C722CBD379A2B13C4AD54757A1F0202727729450F6` |
| Backtest set | `8E0C880D38C62DD69BAF39AA2C7B27D3D15CBB97677978D1A796B1D25D2E298C` |
| Reference test | `E8D3B74D08081335CE28F07B9F23C8319330C5C4C25F8227423EB793B7D71083` |

## Q02 Capacity And Enqueue Evidence

The initial `farmctl mt5-slots` sample at
`2026-08-12T07:48:45+00:00` found two exact factory tester processes, T2 and
T5. A paired target readback returned zero existing work items for
`QM5_20289`.

The target-only dry run selected exactly one never-tested priority-track row
for `QM5_20289 / XTIUSD.DWX`, with zero skipped, stranded, or deferred rows.
Two early apply attempts were refused by the canonical factory mutation lock
and made no queue change. The lock was not bypassed, removed, or reaped.

The successful binding sample at `2026-08-12T07:50:08+00:00` found three
exact T1-T10 tester processes, T2, T5, and T9, against the ceiling of seven.
The apply therefore proceeded and enqueued exactly one row. Its receipt
reports 1,052 pending items at start against the 7,000 queue ceiling:

- `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`
- `generated_at=2026-08-12T07:50:11+00:00`
- `apply=true`
- SHA-256
  `D8CA45E0E5549E995E74FF94CCEE906BDD7EE9B776867D8BDF5DC54A792DD9C7`

Immediate `farmctl work-items --ea QM5_20289` readback returned:

| Field | Value |
|---|---|
| Work item | `41d6f237-cc5e-46ec-8048-1722c398a110` |
| Phase | Q02 |
| Kind | backtest |
| Symbol | `XTIUSD.DWX` |
| Status | pending |
| Attempt | 0 |
| Claimed by | none |
| Verdict | none |

The item was created at `2026-08-12T07:50:11+00:00`. Q02 is enqueued, not
screened or passed.

## Commits Before This Closing Evidence

- `bc01dc01b` — OWNER mission authorization and exact G0 decision.
- `a6c14aa77` — bounded source packet plus approved/intake cards.
- `cfd3daea0` — deterministic EA-ID reservation.
- `e7185d5b4` — target SPEC scaffold.
- `44b511546` — slot-0 WTI magic allocation and resolver generation.
- `b4c78eed0` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.

Commits were scoped to `agents/board-advisor`; unrelated pre-existing and
concurrent worktree changes were preserved.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run
  by this mission.
- No terminal was started, stopped, reserved, reaped, or altered by this
  mission.
- The factory mutation lock was respected throughout contention.
- Non-factory T_Live and FTMO processes were observed only through the
  read-only capacity scan so they could be excluded from the T1-T10 count;
  neither was controlled or modified.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, T_Live file, or T_Live manifest
  was changed.
- The portfolio gate was not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
