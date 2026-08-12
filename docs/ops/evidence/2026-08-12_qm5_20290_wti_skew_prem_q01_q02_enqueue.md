# QM5_20290 WTI Skewness Premium — Q01 PASS / Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20290_wti-skew-prem` is a new low-frequency outright-WTI structural
third-moment candidate. It is built, Q01 is `PASS`, and exactly one
priority-track `XTIUSD.DWX` row is enqueued at Q02. Work item
`661b4c77-8fed-41ff-92e2-d4851ebcaad0` was pending at immediate readback,
attempt 0, unclaimed, with no verdict. This mission issued no dispatch tick
and ran no manual backtest. Q02 enqueue is not certification, efficacy, or
portfolio admission.

## Edge And Mechanical Contract

On the first processed D1 bar of a genuine broker-month transition, the EA
selects adjacent completed WTI closes whose two timestamps are wholly inside
the twelve complete broker months preceding the decision month. It computes:

```text
r[d] = ln(close[d] / close[d-1])
mu   = mean(r[d])
m2   = mean((r[d] - mu)^2)
m3   = mean((r[d] - mu)^3)
skew = m3 / (m2^(3/2))
```

The estimator requires all twelve month keys, 180-280 contained returns,
finite arithmetic, and `m2 > 1e-12`. Skew below `-1e-12` buys WTI, skew above
`+1e-12` sells WTI, and near-zero or invalid state consumes the month flat.
Entries use a frozen `3.5 * ATR(20,D1)` hard stop, no take-profit, broker-month
renewal, and a forty-day stale exit. One attempt per month is persisted before
history and entry gates, so missing data or a rejected order cannot create an
intramonth retry.

The only backtest set is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News and Friday-close behavior are OFF. There is no ML,
trained output, prohibited signal indicator, external runtime feed, grid,
martingale, scale-in, or pyramid.

## Source, Hypothesis Boundary, And Non-Duplicate Review

The primary source is Fernandez-Perez, Frijns, Fuertes, and Miffre (2018),
"The Skewness of Commodity Futures Returns," *Journal of Banking & Finance*
86, 143-158, DOI `10.1016/j.jbankfin.2017.06.015`. It defines twelve-month
Pearson skewness, documents a negative cross-sectional commodity-skewness
premium, and explicitly includes crude oil. The governed complete-read packet
is `strategy-seeds/sources/FERNANDEZ-SKEW-2018/source.md`, SHA-256
`D9C9BDD383956A0190490E4977CAC5D247E9B250342B88577BF7439019C893F7`.

The outright WTI time-series zero pivot is a disclosed, pre-result QM
hypothesis. The paper does not test that pivot, Darwinex continuous CFD,
broker-month reconstruction, lifecycle, or risk overlay. The bounded packet is
`strategy-seeds/sources/FERNANDEZ-WTI-SKEW-2026/source.md`; durable G0
authorization is
`decisions/2026-08-12_qm5_20290_wti_skew_prem_g0.md`.

The deterministic pre-card duplicate check scanned 4,355 EA-registry rows and
467 root cards. It found no exact identity and two expected source-family fuzzy
neighbors. Manual review separated the closest mechanics:

- `QM5_13118` ranks simultaneous XTI and XNG twelve-month skewness states and
  manages a two-leg cross-sectional basket. QM5_20290 has one WTI carrier, no
  rank, no second leg, and an absolute time-series zero pivot.
- `QM5_20233` is a paired XAU/XAG cross-sectional skewness-rank basket, not an
  outright energy rule.
- `QM5_20289` uses one month of normalized signed semivariance and reverses its
  sign. It does not use centered third moments or a twelve-month formation.
- `QM5_12567` is a short-horizon long-only cumulative-RSI pullback behind a
  slow filter.

Verdict: `CLEAN_AFTER_MANUAL_CROSS_SECTIONAL_TO_TIME_SERIES_REVIEW`.

WTI supplies a crude-oil carrier absent from the stated XAU, SP500, NDX, and
XNG book. Carrier and information-object novelty are diversification
hypotheses only. Unchanged downstream gates, including Q09, own any realized
correlation conclusion.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20290` / `wti-skew-prem` /
  `FERNANDEZ-SKEW-2018_XTI_TS_S03`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202900000`.
- The EA-ID and magic rows each occur exactly once. Resolver generation kept
  15,895 rows and dropped zero. Its embedded registry SHA-256 is
  `09BB78B4779B1CE52479D95B6DE44E7DA8AFE285C581A93DB3836805262BF79B`.
- Strict compile: `D:/QM/reports/compile/20260812_085247/summary.csv`, PASS
  with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260812_085247/QM5_20290_wti-skew-prem.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260812_085247.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20290/P1/P1_QM5_20290_result.json`, PASS.
- Independent statistic test:
  `framework/EAs/QM5_20290_wti-skew-prem/docs/test_skew_reference.py`, PASS.
- Card schema/ML lint, G0 lint, build-prerequisite guard, SPEC validation, and
  canonical/intake/build-card content synchronization: PASS.
- Setfile header build hash:
  `f186bc6d715eb39e3e2cb6151a0a0d3aec4e0bea38abbb95d6ae4ccce3a9f7a9`.
- Manual smoke/backtest: none.

Final repository artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `002CB0E3B834E0D3E326D8D60A82263B914D5CEB5AAF4AD67EAD35C113838143` |
| Bounded source packet | `08281072955DD188F7758EE11AF5AA68F9D2ED3723B60A123F2B9B32866C1423` |
| Canonical/intake/build card | `5EC0C5BD2F07C83FD0C0D0AEABABD0CD0B4035F9A22A0D49A4B4F8ADC91C9B9A` |
| MQ5 | `629C0968ADE859CDBBB1443D08718635F0F425760C0F451B712747A78B5A4B11` |
| EX5 | `622DA2A16A9BAF987FFFF3C2484139F62C33592FDD53BE69F8D23AE4DE94C894` |
| SPEC | `56B1783AA859DDEC298EECCE0C5EEE1E6B48A2555CEB153113EEB3CC7DDB2501` |
| Backtest set | `0E4EBF1A8C7D194B97ED423503C3B9654FD74999C856C097CD9D05AF269E2162` |
| Reference test | `4226B7CAE0F3FB75F2E9213390F62933EED27F438A3985F5083110BFF764EF8D` |

## Q02 Capacity And Enqueue Evidence

The canonical scheduled never-tested sweep created exactly one row at
`2026-08-12T08:52:59+00:00` while Q01 was finishing. The durable row names:

| Field | Value |
|---|---|
| Work item | `661b4c77-8fed-41ff-92e2-d4851ebcaad0` |
| Phase / kind | `Q02` / `backtest` |
| EA / symbol | `QM5_20290` / `XTIUSD.DWX` |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20290_wti-skew-prem/sets/QM5_20290_wti-skew-prem_XTIUSD.DWX_D1_backtest.set` |
| Enqueued by | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track | priority |
| Status | pending |
| Attempt / claim / verdict | 0 / none / none |

The target-only dry run at `2026-08-12T08:56:37+00:00` used
`--ea QM5_20290 --symbols XTIUSD.DWX`. It saw 1,048 pending rows against the
7,000 queue ceiling and selected zero new rows because the target already had
durable work-item state. No apply was issued, preventing a duplicate. The
rolling dry-run receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`A635EC568EA49ACDC16F03757A8DECCABA5C9CA1C57C8922266C53E16033FD05`.
Because that shared receipt is rolling and now records the dry run, the durable
enqueue proof is the work-item row and immediate `farmctl work-items --ea
QM5_20290` readback above.

The path-anchored capacity sample at `2026-08-12T08:57:54+00:00` found four
exact T1-T10 tester processes: T2, T6, T7, and T8, below the ceiling of seven.
The CPU ceiling was not hit. T_Live and FTMO processes were observed only so
they could be excluded from the factory count; neither was controlled or
modified.

## Commits Before This Closing Evidence

- `44ebc35c5` — OWNER mission authorization and exact G0 decision.
- `64406a665` — bounded source packet plus approved/intake cards.
- `626257905` — deterministic EA-ID reservation.
- `86c63f006` — target SPEC scaffold.
- `2de008b15` — slot-0 WTI magic allocation and resolver generation.
- `b3519102d` — EA source, EX5, reference test, fixed-risk setfile, and Q01
  evidence bindings.

All commits are scoped to `agents/board-advisor`; unrelated pre-existing and
concurrent worktree changes were preserved.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run
  by this mission.
- No terminal was started, stopped, reserved, reaped, or altered by this
  mission.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, T_Live file, or T_Live manifest was
  changed.
- The portfolio gate was not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
