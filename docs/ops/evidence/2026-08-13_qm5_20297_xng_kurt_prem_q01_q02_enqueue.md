# QM5_20297 XNG Historical-Kurtosis Premium — Q01 PASS / Q02 Enqueued

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20297_xng-kurt-prem` is a new low-frequency outright-natural-gas
fourth-moment candidate. It is built, Q01 is `PASS`, and exactly one
fixed-risk `XNGUSD.DWX` D1 row is enqueued at Q02. Work item
`8a3e73ec-caca-4306-89fb-4941d953a05a` was pending at immediate readback,
attempt 0, unclaimed, with no evidence path or verdict. This mission issued no
dispatch tick and ran no manual backtest. Enqueue is not efficacy,
certification, decorrelation, or portfolio admission.

## Edge And Mechanical Contract

At the first processed D1 bar after a genuine broker-month transition, the EA
loads exactly 253 completed XNG D1 closes and forms 252 chronological simple
returns. It computes the source-defined Pearson historical-kurtosis estimator:

```text
r[d]     = close[d] / close[d-1] - 1
mu       = sum(r[d]) / 252
s2       = sum((r[d] - mu)^2) / 251
m4       = sum((r[d] - mu)^4) / 252
kurtosis = m4 / (s2^2)
```

The EA buys above `3.0 + 1e-12`, sells below `3.0 - 1e-12`, and consumes the
month flat on a tie or invalid state. It requires strictly increasing history,
positive finite closes, a completed endpoint before the decision bar and no
more than ten calendar days stale, finite arithmetic, and `s2 > 1e-12`. It
does not use excess kurtosis, bias correction, a relative rank, fitted pivot,
magnitude-scaled risk, trained output, or prohibited signal indicator.

A terminal-persistent month marker is written before history, spread, quote,
news, ATR, sizing, or order gates, preventing same-month retries. The EA owns
at most one XNG position, attaches a frozen `3.5 * ATR(20,D1)` broker hard
stop, has no take profit, exits at the next broker month, and closes stale
after forty calendar days. Malformed owned state is flattened before entry
logic. The sole setfile is `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the entry spread ceiling is 2,500
points. News axes and Friday close are OFF. There is no grid, martingale,
scale-in, pyramid, or external runtime feed.

## Source And Non-Duplicate Review

The primary source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in
Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The governed complete-read parent
packet covers the 57-page accepted article and online appendix, explicitly
includes natural gas, and is bound by SHA-256
`66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47`.
The bounded XNG extraction is
`strategy-seeds/sources/HOLLSTEIN-XNG-KURT-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20297_xng_kurt_prem_g0.md`.

The paper defines prior-year Pearson historical kurtosis, monthly
cross-sectional sorts, and the high-minus-low direction. It does not test an
absolute benchmark-three XNG time-series rule, continuous CFD, hard stop, or
QM book decorrelation. Its directly relevant two-portfolio result and
Fama-MacBeth slope are insignificant, and the post-financialization result
reverses sign insignificantly. Those adverse facts are preserved: this is an
explicit low-prior QM translation, not a transferred source result.

The canonical pre-allocation check scanned 4,362 EA-registry rows and 473 root
cards. It found no exact slug, strategy-ID, or mechanic identity and returned
eight expected fuzzy source-family neighbors. Manual review separated them:

- `QM5_13131_energy-kurt-rank` is a simultaneous XTI/XNG relative-rank
  package; this EA has one absolute XNG state, one magic, and no orphan leg.
- `QM5_20291_xauxag-kurt-rk` is a paired precious-metal relative rank with
  different carriers and execution topology.
- `QM5_20295_wti-kurt-prem` preserves the estimator on WTI; this is a
  separately authorized XNG carrier with its own history, contract economics,
  spread guard, magic, and Q02 verdict.
- `QM5_20296_xng-skew-prem` uses a centered third standardized moment around
  zero and the low-skew direction, not the fourth central moment around three.
- `QM5_13130_xti-xng-lowmax` and `QM5_20294_xauxag-max-rk` use only the five
  largest returns rather than the full distribution's fourth moment.
- The certified `QM5_12567` XNG sleeve is a short-horizon, long-only
  cumulative-RSI pullback, not a monthly symmetric fourth-moment premium.

Verdict: `CLEAN_AUTHORIZED_XNG_CARRIER_AFTER_MANUAL_REVIEW`. Different logic
is established mechanically; low realized overlap remains a hypothesis that
Q09 must prove against the XAU/SP500/NDX/XNG portfolio.

## Deterministic Allocation And Q01 Evidence

- EA / slug / strategy: `QM5_20297` / `xng-kurt-prem` /
  `HOLLSTEIN-MAX-2021_XNG_TS_S06`.
- Symbol / slot / magic: `XNGUSD.DWX` / 0 / `202970000`.
- Target magic uniqueness and the `ea_id * 10000 + slot` formula passed.
- Resolver generation kept 15,909 rows and dropped zero; embedded registry
  SHA-256:
  `367D4EC6B15192549FA80E15E7C91FB64ECC710C9747A2A09332BC1463389F33`.
- Strict compile: `D:/QM/reports/compile/20260813_011341/summary.csv`, PASS
  with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260813_011341/QM5_20297_xng-kurt-prem.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260813_011340.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20297/P1/P1_QM5_20297_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20297_xng-kurt-prem/docs/test_kurtosis_reference.py`,
  5/5 PASS for source denominators, a known value, high-tail direction, scale
  invariance, benchmark ties, simple-return chronology, exact observation
  counts, strict ordering, and endpoint freshness.
- Card schema/ML lint, G0 lint, build prerequisite guard, SPEC validation,
  target registry/runtime guardrails, and synchronized canonical/intake/build
  card content: PASS.
- The set header's normalized-content build hash, written by the target build
  checker, is
  `82E3909D0795D685EA84942DCB50324B2D334768C1C7AEBB96B610F4E2162567`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `1578FB78185F3AB7929D2DE74FF70863688BE5D0E5EFB6D051C303BBB2B7AD4D` |
| Bounded source packet | `E865A2A5FD04B5953766F8A12AAD072BD6A1E41717470B7E693EA09E141C3BA9` |
| Canonical / intake / build card | `AB73222210120167FD426C80E9EE52BCDD5075C769C9348FC67ED6CBD1E58B90` |
| MQ5 | `75BB9777A1E39DC8A3BB1BD7EE5D4AFCA3E0657029FFAF592335500E2304C75F` |
| EX5 | `C6A9DC1F8D28CFFE974E9BB0D3B87CC4464DD2CBC42061E69A6C64DD41599DFE` |
| SPEC | `71A2D1DFF9BA7E00E4AB2A0DFC1793DD509C1FB30AFD8C6CC725F946F587CF33` |
| Backtest set | `89EA21431F1EE9EFDB758D8411D0B2268CCD7314DCCD62B432DA6E89494F959C` |
| Reference test | `E34A774EAFEEBB16A12A467622AC995423DFCC2B1562FF62C06BD8B3C4E25B03` |

## Q02 Capacity And Enqueue Evidence

The path-anchored pre-enqueue capacity sample at
`2026-08-13T01:18:22.5521500Z` found zero executables rooted exactly under
`D:/QM/mt5/T1..T10/terminal64.exe`, below the seven-job CPU ceiling. The
post-enqueue sample at `2026-08-13T01:18:48.3214933Z` also found zero.
`T_Live` and all non-factory executable paths were excluded from the count and
were not controlled or modified. An unrelated FTMO terminal outside the
factory path was observed read-only and did not count as a factory job.

Before apply, `farmctl work-items --ea QM5_20297` returned zero rows. The
target-only dry run selected exactly one fresh Q02 row, zero stranded rows,
and zero deferred promotions. The apply receipt recorded 959 pending rows at
start against the 7,000-row queue ceiling and inserted the same single row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20297 --queue-ceiling 7000 --max-part2-per-run 0
```

| Field | Value |
|---|---|
| Work item | `8a3e73ec-caca-4306-89fb-4941d953a05a` |
| Created | `2026-08-13T01:18:39+00:00` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XNGUSD.DWX` / D1 |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20297_xng-kurt-prem/sets/QM5_20297_xng-kurt-prem_XNGUSD.DWX_D1_backtest.set` |
| Enqueue class | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track | priority |
| Status | pending at immediate readback |
| Attempt / claim / evidence / verdict | 0 / none / none / none |

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`BF298328F63C052FA97684F286640275A3A72F2854C0FB2243B6871FE19D92EC`
at immediate readback. Because the receipt is shared and rolling, the unique
farm work-item row above is the durable queue proof.

## Scoped Commits Before Closing Evidence

- `82050b231` — durable OWNER mission G0 authorization.
- `603d3544f` — bounded source packet and synchronized approved/intake cards.
- `673d6f5cf` — deterministic EA-ID reservation.
- `ba9ec343d` — slot-0 XNG magic, initial SPEC, and regenerated resolver.
- `5843fbfc7` — EA source, EX5, fixed-risk setfile, independent reference,
  synchronized cards, and Q01 evidence bindings.

All scoped staging remained on `agents/board-advisor`. The pre-existing
untracked Brent-to-WTI review artifact was left untouched.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, `T_Live` file, or T_Live manifest
  was used for control or changed.
- The portfolio gate was not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
