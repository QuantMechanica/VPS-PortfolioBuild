# QM5_20296 XNG Pearson-Skewness Premium — Q01 PASS / Q02 Enqueued

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20296_xng-skew-prem` is a new low-frequency outright-natural-gas
third-moment candidate. It is built, Q01 is `PASS`, and exactly one fixed-risk
`XNGUSD.DWX` D1 row is enqueued at Q02. Work item
`36cc9282-c16c-449f-b5a1-455809f8a9d4` was pending at immediate readback,
attempt 0, unclaimed, with no evidence path or verdict. This mission issued no
dispatch tick and ran no manual backtest. Enqueue is not efficacy,
certification, decorrelation, or portfolio admission.

## Edge And Mechanical Contract

At the first processed XNG D1 bar after a genuine broker-month transition,
the EA reconstructs the twelve complete preceding broker months and computes
boundary-contained daily log returns and population Pearson skewness:

```text
r[d] = ln(close[d] / close[d-1])
mu   = sum(r[d]) / n
m2   = sum((r[d] - mu)^2) / n
m3   = sum((r[d] - mu)^3) / n
skew = m3 / (m2^(3/2))
```

It requires all twelve expected month keys, 180 through 280 returns, positive
finite closes, strictly increasing timestamps, finite arithmetic, and
`m2 > 1e-12`. It buys below `-1e-12`, sells above `+1e-12`, and consumes a
tie or invalid state flat. The current month and any boundary-crossing return
are excluded. There is no simple-return substitution, bias correction, rank,
fitted pivot, magnitude-scaled risk, trained output, or prohibited signal
indicator.

One terminal-persistent month-attempt marker is written before history, news,
spread, quote, sizing, or order gates. The EA permits exactly one owned XNG
position, attaches a frozen `3.5 * ATR(20,D1)` broker hard stop, has no take
profit, exits at the next broker month, and closes stale after forty days.
Malformed owned state is flattened before entry logic. The sole setfile is
`environment=backtest`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; its XNG spread ceiling is 2,500 points. News axes and
Friday close are OFF. There is no grid, martingale, scale-in, pyramid, or
external runtime feed.

## Source And Non-Duplicate Review

The primary source is Fernandez-Perez, Frijns, Fuertes, and Miffre (2018),
"The Skewness of Commodity Futures Returns," *Journal of Banking & Finance*
86, 143-158, DOI `10.1016/j.jbankfin.2017.06.015`. The governed complete-read
parent packet explicitly covers natural gas and is bound by SHA-256
`D9C9BDD383956A0190490E4977CAC5D247E9B250342B88577BF7439019C893F7`.
The bounded XNG extraction is
`strategy-seeds/sources/FERNANDEZ-XNG-SKEW-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20296_xng_skew_prem_g0.md`.

The paper defines prior-twelve-month Pearson return skewness, rebalances
monthly, includes natural gas, and documents a negative cross-sectional
skewness premium. It does not test an absolute zero-pivot XNG time-series
rule, a continuous CFD, this hard stop, or QM portfolio decorrelation. Those
are explicitly bounded implementation hypotheses, and no WTI result or
evidence is inherited by this carrier.

The canonical pre-card check scanned 4,361 EA-registry rows and 472 root
cards. It found no exact slug, strategy-ID, or mechanic identity and returned
three expected fuzzy source-family neighbors. Manual review separated them:

- `QM5_13118_energy-skew-rank` is a simultaneous two-leg XTI/XNG relative
  rank; this EA has one absolute XNG state, one magic, and no orphan leg.
- `QM5_20233_xauxag-skew-rank` is a paired precious-metal rank with different
  carriers and execution topology.
- `QM5_20290_wti-skew-prem` preserves the estimator on WTI; this is a
  separately authorized XNG carrier with its own history, contract economics,
  spread guard, magic, and Q02 verdict.
- The certified `QM5_12567` XNG sleeve is a short-horizon, long-only
  cumulative-RSI pullback, not a monthly symmetric third-moment premium.

Verdict: `CLEAN_AUTHORIZED_XNG_CARRIER_AFTER_MANUAL_REVIEW`. Different logic
is established mechanically; low realized overlap remains a hypothesis that
Q09 must prove against the XAU/SP500/NDX/XNG book.

## Deterministic Allocation And Q01 Evidence

- EA / slug / strategy: `QM5_20296` / `xng-skew-prem` /
  `FERNANDEZ-SKEW-2018_XNG_TS_S04`.
- Symbol / slot / magic: `XNGUSD.DWX` / 0 / `202960000`.
- Target magic uniqueness and the `ea_id * 10000 + slot` formula passed.
- Resolver generation kept 15,908 rows and dropped zero; embedded registry
  SHA-256:
  `5466B7E552F3982A1FC272D43D6F817DEC74103C088BC6BF2AE3CE60DEA3227E`.
- Strict compile: `D:/QM/reports/compile/20260813_001437/summary.csv`, PASS
  with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260813_001437/QM5_20296_xng-skew-prem.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260813_001437.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20296/P1/P1_QM5_20296_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20296_xng-skew-prem/docs/test_skew_reference.py`, PASS
  for low-/high-skew directions, zero ties, scale invariance, month-window
  containment, full month coverage, count bounds, moment validity,
  chronology, and genuine month transitions.
- Card schema/ML lint, G0 lint, build prerequisite guard, SPEC validation,
  target runtime guardrails, and synchronized canonical/intake/build-card
  content: PASS.
- The backtest set header binds MQ5 SHA-256
  `4AABC2EDB9438427D02209C38EEAA5121098D012B56A1F8032FC091D961CD239`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `5229BA81C5112E468CF69EB1A8A83D6FD9E703E24223FA7D6A1581932116D785` |
| Bounded source packet | `C3CFD727AE258D971EF0587E25B6EFC0A95758FEAA7D0E5F744191C281757B8E` |
| Canonical / intake / build card | `457F804A8CF075870A0B0C729913C49E8C1052EEEA07E6EE12E1C8AD3506FB4C` |
| MQ5 | `4AABC2EDB9438427D02209C38EEAA5121098D012B56A1F8032FC091D961CD239` |
| EX5 | `1D13BA143EB450AFE1B7DCCE63F2C4F945D5DFF865A93A2E8672317C64A0F229` |
| SPEC | `1901148BA9E3F0DDE09ADD36A626E4AE1EC67717C53894358900DE7E4265220F` |
| Backtest set | `6D84B16CDFBCBF97AD23612E3D1F00BC0929BAC99EEC60F4ACDFD7834C0C3C63` |
| Reference test | `0EF3A5A6668854C66A279AF5C4ACCAA7008D81114E6B152868E5C861B38B5634` |

## Q02 Capacity And Enqueue Evidence

The path-anchored capacity sample at
`2026-08-13T00:16:56.2639979Z` found zero executables rooted exactly under
`D:/QM/mt5/T1..T10/terminal64.exe`, below the seven-job CPU ceiling. The
post-enqueue sample at `2026-08-13T00:17:18.3073236Z` also found zero.
`T_Live` and all non-factory paths were excluded from the count and were not
controlled or modified.

Before apply, `farmctl work-items --ea QM5_20296` returned zero rows. The
target-only dry run selected exactly one fresh Q02 row, zero stranded rows,
and zero deferred promotions. The apply receipt recorded 956 pending rows at
start against the 7,000-row queue ceiling and inserted that same one row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20296 --queue-ceiling 7000 --max-part2-per-run 0
```

| Field | Value |
|---|---|
| Work item | `36cc9282-c16c-449f-b5a1-455809f8a9d4` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XNGUSD.DWX` / D1 |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20296_xng-skew-prem/sets/QM5_20296_xng-skew-prem_XNGUSD.DWX_D1_backtest.set` |
| Enqueue class | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track | priority |
| Status | pending at immediate readback |
| Attempt / claim / evidence / verdict | 0 / none / none / none |

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`0FFC21FC82204CD64C5EBF34CC456BCCA62795ACA2EEEA29A1A87C4F88E08D7F`
at immediate readback. Because the receipt is shared and rolling, the unique
farm work-item row above is the durable queue proof.

## Scoped Commits Before Closing Evidence

- `28ba388c9` — durable OWNER mission G0 authorization.
- `f4314e3f8` — bounded source packet and synchronized approved/intake cards.
- `c4c9585b7` — deterministic EA-ID reservation.
- `d04e7dca2` — slot-0 XNG magic, initial SPEC, and regenerated resolver.
- `698a1c8c4` — EA source, EX5, fixed-risk setfile, independent reference,
  synchronized cards, and Q01 evidence bindings.

All scoped staging remained on `agents/board-advisor`. The pre-existing
untracked Brent-to-WTI review artifact was left untouched.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, `T_Live` file, or T_Live manifest
  was read for control or changed.
- The portfolio gate was not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
