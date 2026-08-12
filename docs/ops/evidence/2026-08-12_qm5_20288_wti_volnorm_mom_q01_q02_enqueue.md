# QM5_20288 WTI Volatility-Normalized Trend — Q01 PASS / Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20288_wti-volnorm-mom` is a new low-frequency outright-WTI structural
trend candidate. It is built, Q01 is `PASS`, and exactly one current-binary
`XTIUSD.DWX` row was enqueued to Q02 below the path-anchored factory CPU
ceiling. Work item `9714bc6b-d11d-485e-b359-6e6cfa2c2ec5` was pending at
immediate readback, attempt 0, unclaimed, with no verdict. This mission issued
no dispatch tick and ran no manual backtest.

## Edge And Non-Duplicate Boundary

At the first processed D1 bar after each genuine broker-month transition, the
EA reconstructs thirteen consecutive completed WTI month-end closes and all
completed D1 close-to-close log returns connecting them. For each of the
twelve month intervals it divides the endpoint return by the undemeaned L2
norm of that month's daily-return path, gives every normalized month equal
weight, and trades the sign of their arithmetic mean. Every interval requires
15-25 daily returns, a positive norm, and daily-sum versus endpoint identity
within `1e-10`. Exact zero or any invalid state consumes the month flat.
Entries have a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, monthly
renewal, and a forty-day stale exit.

The canonical pre-card duplicate check scanned 4,353 EA-registry rows and 465
root cards. It found no exact identity and no fuzzy match above threshold.
Manual review separated the nearest WTI neighbors:

- `QM5_20274_wti-path-eff` divides one twelve-month endpoint return by the
  L1 sum of twelve absolute monthly returns and applies a threshold. This EA
  forms twelve separate endpoint-over-daily-L2 ratios, weights them equally,
  and has no threshold.
- WTI variance-ratio EAs estimate fixed-horizon memory states rather than
  separately normalizing twelve historical monthly paths.
- `QM5_13049_xti-1w-mom-vol` follows five-day momentum only behind a
  separate low-volatility gate.
- Cumulative, robust-location, regression, rank, sign/run/vote, block,
  recency, and skip-month systems use different observations or weights.

The independent reference vectors cover positive, negative, and exact-zero
direction; positive scale invariance; a single large shock against eleven
smooth opposite months; endpoint-identity rejection; 15-25 observation
bounds; and zero-norm rejection. Verdict:
`CLEAN_AFTER_MANUAL_PATH_AND_VOLATILITY_NEIGHBOR_REVIEW`.

WTI is a crude-oil carrier absent from the current XAU, SP500, NDX, and XNG
book. Carrier and statistic novelty do not establish realized decorrelation;
unchanged downstream gates, including Q09, own that conclusion if the
candidate survives Q02-Q08.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-VOLNORM-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The governed 23-page paper receipt records
PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`
and explicitly includes NYMEX WTI crude in its commodity-futures universe.

The source supports monthly own-price direction over the first twelve lags
and volatility scaling. It does not test this exact historical within-month
L2 estimator, the Darwinex continuous CFD, broker-month reconstruction,
lifecycle, or risk overlay; those are disclosed pre-result QM mechanizations.
Durable G0 authorization is
`decisions/2026-08-12_qm5_20288_wti_volnorm_mom_g0.md`.

R1-R4 pass: one peer-reviewed named trading source with DOI, complete governed
read and durable hash; exact mechanical rules; a registered WTI D1 route; and
deterministic native arithmetic without ML, trained output, prohibited signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20288` / `wti-volnorm-mom` /
  `MOP-TSMOM-2012_XTI_VOLNORM12_S36`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202880000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The target EA-ID and magic rows each occur exactly once. Resolver generation
  kept 15,893 rows and dropped zero. Its embedded registry SHA-256 is
  `B9328CA90E10C104D201AA94B85BEEB59BCAB67355E902C69D87D3C3CD407CAD`.
- Strict compile:
  `D:/QM/reports/compile/20260812_060749/summary.csv`, PASS with zero errors
  and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260812_060749/QM5_20288_wti-volnorm-mom.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260812_060748.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20288/P1/P1_QM5_20288_result.json`, PASS.
- Independent statistic test:
  `framework/EAs/QM5_20288_wti-volnorm-mom/docs/test_volnorm_reference.py`,
  PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation,
  and canonical/intake/build-card identity: PASS.
- Setfile header build hash:
  `de0bc99f9d36fa1fbb8fa33a26a0fd453e43063dc07da02109b734282e9e4b01`.
- Manual smoke/backtest: none.

Final repository artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `6F4FE277B2DD876CF9CE8D3A168D6DF5C213F6FFE09AC46018485ED8170B7923` |
| Bounded source packet | `1A3394CCD06CD30FFFEE5F5E3D2DC2C2D6AD2B5F79E1681851B6845C6686058E` |
| Canonical/intake/build card | `1764DD88272F42B2968C6F14865C8FA552BD166A4AD7A9E7D54D37E0BDC76D8F` |
| MQ5 | `B2406732BC3C80026984FDD2BCBA8F6345FD80A0A197A0A7F27D2BF85AD9B640` |
| EX5 | `029F92478D0298269E963FAC410DC023C07FF28DDE950F961BD6CF44BDFD6FAB` |
| SPEC | `C2B4B7362442487113E81258A1160EA14629CB70F2626364E0F26DBCA9AF478C` |
| Backtest set | `79A0559AE189530345316E236DB5FB6783ED190A547D32D7641DD3086B1BE906` |
| Reference test | `2202FAD5D3DEB46AC64C6F3C5BF8F581156CEE4A167FC6FC49C7F46257600B88` |

## Q02 Capacity And Enqueue Evidence

The initial `farmctl mt5-slots` sample at
`2026-08-12T06:10:37+00:00` found three exact factory tester processes:
T2, T6, and T10. A paired target readback returned zero existing work items for
`QM5_20288`.

The target-only dry run selected exactly one never-tested priority-track row
for `QM5_20288 / XTIUSD.DWX`, with zero skipped, stranded, or deferred rows.
Two early apply attempts were refused by the canonical factory mutation lock
and made no queue change. The lock was not bypassed or removed.

After a bounded wait for a normal acquisition window, the binding sample at
`2026-08-12T08:13:03+02:00` again found three exact T1-T10 tester processes
against the ceiling of seven. The apply therefore proceeded and enqueued
exactly one row. Its receipt reports 1,069 pending items at start against the
7,000 queue ceiling:

- `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`
- `generated_at=2026-08-12T06:13:08+00:00`
- `apply=true`
- SHA-256
  `B1EE13E9EB0CFE69E467066EC3582AE59C7BAD9145398725A1D33FBF65E5C3A2`

Immediate `farmctl work-items --ea QM5_20288` readback returned:

| Field | Value |
|---|---|
| Work item | `9714bc6b-d11d-485e-b359-6e6cfa2c2ec5` |
| Phase | Q02 |
| Kind | backtest |
| Symbol | `XTIUSD.DWX` |
| Status | pending |
| Attempt | 0 |
| Claimed by | none |
| Verdict | none |

The item was created at `2026-08-12T06:13:08+00:00`. Q02 is enqueued, not
screened or passed.

## Commits Before This Closing Evidence

- `019694c25` — OWNER mission authorization and exact G0 decision.
- `0da87ad02` — bounded source packet plus approved/intake cards.
- `2baa4341b` — deterministic EA-ID reservation.
- `3f713281e` — target SPEC scaffold.
- `7f8b5176e` — slot-0 WTI magic allocation and resolver generation.
- `d4f0f5411` — EA source, EX5, reference test, fixed-risk setfile, and Q01
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
