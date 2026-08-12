# QM5_20295 WTI Historical-Kurtosis Premium — Q01 PASS / Q02 Enqueued

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20295_wti-kurt-prem` is a new low-frequency outright-WTI
fourth-moment candidate. It is built, Q01 is `PASS`, and exactly one fixed-risk
`XTIUSD.DWX` D1 row is enqueued at Q02. Work item
`0ed36c55-2a83-49ad-a5f0-71b25700ff18` was pending at immediate readback,
attempt 0, unclaimed, with no evidence path or verdict. This mission issued no
dispatch tick and ran no manual backtest. Enqueue is not efficacy,
certification, decorrelation, or portfolio admission.

## Edge And Mechanical Contract

At the first processed WTI D1 bar after a genuine broker-month transition,
the EA loads exactly 253 completed closes, forms 252 chronological simple
returns, and computes the source-defined Pearson historical-kurtosis statistic:

```text
r[d] = close[d] / close[d-1] - 1
mu = sum(r[d]) / 252
s2 = sum((r[d] - mu)^2) / 251
m4 = sum((r[d] - mu)^4) / 252
kurtosis = m4 / (s2^2)
```

It buys WTI above `3.0 + 1e-12`, sells below `3.0 - 1e-12`, and consumes a
numerical tie or invalid state flat. It rejects the current D1 bar, anything
other than 252 returns, non-increasing timestamps, nonpositive/nonfinite
closes, a completed endpoint at or after the decision bar, an endpoint more
than ten days stale, nonfinite arithmetic, or sample variance at or below
`1e-12`. There is no excess-kurtosis conversion, bias correction, fitted
pivot, rank, magnitude-scaled risk, or alternate estimator.

One terminal-persistent month-attempt marker is written before history, news,
spread, quote, sizing, or order gates. The EA permits exactly one owned WTI
position, attaches a frozen `3.5 * ATR(20,D1)` broker hard stop, has no take
profit, exits at the next broker month, and closes stale after forty days.
Malformed owned state is flattened before entry logic. The only setfile is
`environment=backtest`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News axes and Friday close are OFF. There is no trained
output, prohibited signal indicator, external runtime feed, grid, martingale,
scale-in, or pyramid.

## Source And Non-Duplicate Review

The primary source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in
Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The governed parent packet records a
complete read of the accepted manuscript and online appendix and is bound by
SHA-256
`66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47`.
The bounded WTI extraction is
`strategy-seeds/sources/HOLLSTEIN-WTI-KURT-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20295_wti_kurt_prem_g0.md`.

The paper defines prior-year Pearson historical kurtosis, includes WTI, uses
monthly sorts, and reports a positive full-sample cross-sectional relation.
It does not test an absolute benchmark-three WTI timing rule. Its two-portfolio
result and regression slope are insignificant, while the post-financialization
sign reverses insignificantly. Those adverse facts are binding low-prior Q02
kill risks. No paper return, alpha, cost, CFD equivalence, efficacy, or
correlation transfers to this candidate.

The canonical pre-card check scanned 4,360 EA-registry rows and 471 cards. It
found no exact slug, strategy-ID, or mechanic identity and returned seven
expected fuzzy source-family neighbors. Manual review separated them:

- `QM5_13131` and `QM5_20291` are two-leg cross-sectional kurtosis ranks;
  this is an absolute one-symbol WTI state with one magic and no orphan leg.
- `QM5_20290` uses third-moment skewness around zero, not fourth-moment
  kurtosis around three.
- `QM5_13130` and `QM5_20294` use only the five largest returns, not all 252
  returns in a fourth central moment.
- Legacy kurtosis composites combine other states or cadences rather than
  trading this pure monthly WTI statistic.
- `QM5_12567` is a short-horizon long-only cumulative-RSI pullback.

Verdict: `CLEAN_AFTER_MANUAL_CROSS_SECTIONAL_TO_TIME_SERIES_REVIEW`. WTI
carrier separation and different signal logic are diversification hypotheses
only; Q09 alone may establish realized overlap with the XAU/SP500/NDX/XNG
book.

## Deterministic Allocation And Q01 Evidence

- EA / slug / strategy: `QM5_20295` / `wti-kurt-prem` /
  `HOLLSTEIN-MAX-2021_XTI_TS_S05`.
- Symbol / slot / magic: `XTIUSD.DWX` / 0 / `202950000`.
- Resolver generation kept 15,907 rows and dropped zero; embedded registry
  SHA-256:
  `B2565228959B9938DB27D55B96277B58E4AFB8BD6ECF4C52D49AA83E3C4F9484`.
- Strict compile: `D:/QM/reports/compile/20260812_231711/summary.csv`, PASS
  with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260812_231711/QM5_20295_wti-kurt-prem.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260812_231710.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20295/P1/P1_QM5_20295_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20295_wti-kurt-prem/docs/test_kurtosis_reference.py`,
  five tests PASS for source denominators, low-/high-kurtosis directions,
  scale invariance, benchmark ties, simple-return chronology, exact count,
  ordering, and freshness.
- Card schema/ML lint, G0 lint, build prerequisite guard, SPEC validation,
  target runtime guardrails, registry formula/uniqueness, and synchronized
  canonical/intake/build-card content: PASS.
- Setfile header build hash:
  `3edbd13f9fc57d68972faea2515793750b148b1210f69981321bb5dcf1707d9a`.
- Manual smoke/backtest: none.

The repository-wide legacy registry validator still reports pre-existing
historical row defects unrelated to this allocation. The target row count,
slot uniqueness, `ea_id * 10000 + slot` magic formula, generated resolver,
build guard, and strict compile all passed for `QM5_20295`.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `A0FAAA111D6CD006D7F5D7F70AADB8E06FC01FF3DA92BA71C38B1EB456335910` |
| Bounded source packet | `C98C1D3FA4C844C3FDBAEF05588431DDCB8834B9A7EF933BA829AA9CE422EDA5` |
| Canonical / intake / build card | `E9CE401434869622F58CD2250D50AA7E820D6E72323AE20CC526279A0DAB5BBF` |
| MQ5 | `24CA1C0486AC9F3E0434ECF04FD5EAE60A849117C967F33B727C82744FAEC2A6` |
| EX5 | `834C49014E92562A9E21BCCF1A9CB4A386FB043214A35F7627D05F7C85A38C49` |
| SPEC | `9D4722E45B5E21F01BAE3281100E6BB8FCABCCF73843CDE75BC65EFF99F7C2EC` |
| Backtest set | `5DEBF2507C6697E07C773517E2E2F6396A9D2EECCC54F51F4C559E0DCDB576AD` |
| Reference test | `A6111657FD5274796135E7E5CDDA00CD9AC9A368FA0A1A2BC71F52F03A0D0E36` |

## Q02 Capacity And Enqueue Evidence

The path-anchored capacity sample at
`2026-08-12T23:19:28.3016223Z` found zero executables rooted exactly under
`D:/QM/mt5/T1..T10/terminal64.exe`, below the seven-job CPU ceiling. The
post-enqueue sample at `2026-08-12T23:20:10.6390497Z` also found zero.
`T_Live` and all non-factory paths were excluded from the count and were not
controlled or modified.

Before apply, `farmctl work-items --ea QM5_20295` returned zero rows. The
target-only dry run selected exactly one fresh Q02 row and zero stranded rows.
The apply receipt reported 954 pending rows at start against the 7,000-row
queue ceiling and inserted that same one row with no recovery work:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20295 --queue-ceiling 7000 --max-part2-per-run 0
```

An earlier non-applying discovery invocation evaluated the available fleet
because this script does not implement a conventional `--help` exit; it
changed no queue rows. The authoritative dry run and apply were both scoped
to `QM5_20295`.

| Field | Value |
|---|---|
| Work item | `0ed36c55-2a83-49ad-a5f0-71b25700ff18` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / host | `XTIUSD.DWX` / D1 |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20295_wti-kurt-prem/sets/QM5_20295_wti-kurt-prem_XTIUSD.DWX_D1_backtest.set` |
| Enqueued by | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track | priority |
| Status | pending at immediate readback |
| Attempt / claim / verdict | 0 / none / none |

The rolling enqueue receipt was
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`75AE972618E2E3502280F6215CCDE42043CEB65896958B0F52D7F55383243E15`
at immediate readback. Because that receipt is shared and rolling, the durable
proof is the unique SQLite work-item row above.

## Scoped Commits Before Closing Evidence

- `8b595c3b8` — durable G0 decision, bounded source packet, and synchronized
  approved/intake cards.
- `8bdb1d710` — deterministic EA-ID reservation.
- `e4c93dbd4` — target SPEC, slot-0 WTI magic, and generated resolver.
- `0716b46bd` — EA source, EX5, fixed-risk setfile, independent reference,
  synchronized cards, and Q01 bindings.

All scoped staging remained on `agents/board-advisor`. The pre-existing
untracked Brent-to-WTI review artifact was left untouched.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, `T_Live` file, or T_Live manifest
  was changed.
- The portfolio gate was not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
