# QM5_20300 WTI MAX Regime — Q01 PASS / Q02 Enqueued

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20300_wti-max-regime` is a new low-frequency outright-WTI upside-tail-
state candidate. It is built, Q01 is `PASS`, and exactly one fixed-risk
`XTIUSD.DWX` D1 row was enqueued at Q02. Work item
`42f8f5dd-b01e-493f-ba28-c51e9ff2b9d8` had already been claimed by fleet
worker T3 at immediate readback; it was active at attempt 0 with no evidence
path or verdict. This mission issued no dispatch tick and ran no manual
backtest. Enqueue is not efficacy, certification, decorrelation, or portfolio
admission.

## Edge And Mechanical Contract

At the first processed D1 bar after a genuine broker-month transition, the EA
loads exactly 505 completed WTI D1 closes, newest first, and computes the
source MAX characteristic over two consecutive return blocks:

```text
r[b,k]   = close[b+k] / close[b+k+1] - 1, k=0..251
MAX[b]   = arithmetic_mean(five_largest(r[b,0..251]))

recent block b=0:       return indices 0..251
preceding block b=252:  return indices 252..503
```

The blocks share only close index 252 and share no return. The EA buys when
recent MAX is below preceding MAX by more than `1e-12`, sells when it is above
by more than `1e-12`, and consumes the month flat on a tie or invalid state.
It requires positive finite closes, strictly older timestamps by increasing
series index, exact completed-history and top-five counts, and a completed
endpoint before the decision bar and at most ten calendar days stale.

A terminal-persistent month marker is written before history, signal, spread,
quote, news, ATR, sizing, or order gates, preventing same-month retries. The
EA owns at most one WTI position, attaches a frozen `3.5 * ATR(20,D1)` broker
hard stop, has no take profit, exits at the next broker month, and closes stale
after forty calendar days. Malformed owned state is flattened before entry
logic. The sole setfile is `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the spread ceiling is 1,500
points. News axes and Friday close are OFF. There is no external runtime feed,
trained output, prohibited signal indicator, grid, martingale, scale-in, or
pyramid.

## Source And Claim Boundary

The primary source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in
Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The governed complete-read parent
packet explicitly includes WTI and is bound by SHA-256
`66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47`.
The bounded extraction is
`strategy-seeds/sources/HOLLSTEIN-WTI-MAX-REGIME-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20300_wti_max_regime_g0.md`.

The paper defines prior-year MAX as the mean of exactly the five largest
daily simple returns, renews the cross-sectional characteristic monthly, and
reports negative high-minus-low returns only in its 2000-2015
post-financialization subsample. Its full-sample and two-portfolio results are
null. It does not test the EA's two-block own-history comparison, outright WTI
direction, continuous CFD, hard stop, or QM-book decorrelation. Those
limitations are preserved: this is an explicit low-prior QM translation, not
a transferred source result.

## Non-Duplicate Review

The canonical pre-allocation check scanned 4,365 EA-registry rows and 476
root cards. It found no exact slug, strategy-ID, or mechanic identity and
returned eleven expected lexical/source/carrier neighbors. Manual review
separated the material neighbors:

- `QM5_13130` and `QM5_20294` rank concurrent XTI/XNG or XAU/XAG MAX and trade
  paired packages; this EA compares two disjoint WTI history blocks and owns
  one leg.
- `QM5_20295_wti-kurt-prem` measures Pearson historical kurtosis over all
  returns; it does not average the five largest observations.
- `QM5_20298_wti-vov-regime` measures nested realized volatility-of-
  volatility, not an upside order statistic.
- WTI trend, calendar, event, variance-ratio, robust-location, breakout, and
  reversal builds use different state objects and entry lifecycles.
- The certified `QM5_12567` sleeve is short-horizon, long-only XNG cumulative-
  RSI pullback logic on another energy carrier.

Verdict: `CLEAN_AUTHORIZED_WTI_MAX_AFTER_MANUAL_REVIEW`. Crude-oil exposure
is structurally different from the incumbent XAU/SP500/NDX/XNG book, but low
realized overlap remains only a hypothesis; Q09 owns correlation acceptance.

## Deterministic Allocation And Q01 Evidence

- EA / slug / strategy: `QM5_20300` / `wti-max-regime` /
  `HOLLSTEIN-MAX-2021_XTI_TS_S07`.
- Symbol / slot / magic: `XTIUSD.DWX` / 0 / `203000000`.
- The EA registry and magic registry each contain one target row; the target
  magic is unique and equals `ea_id * 10000 + slot`.
- Resolver generation kept 15,912 rows and dropped zero; embedded registry
  SHA-256:
  `62F3C638A6548EFAB5DD28CCA47B35CB51F6AE0A10ADE5ADBE4D0AA0FD685491`.
- Strict compile: `D:/QM/reports/compile/20260813_053912/summary.csv`, PASS
  with strict mode true, zero errors, and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260813_053912/QM5_20300_wti-max-regime.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260813_053911.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20300/P1/P1_QM5_20300_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20300_wti-max-regime/docs/test_max_reference.py`, 6/6
  PASS for exact top-five simple returns, source direction, comparison
  tolerance, disjoint support, price-scale invariance, exact counts,
  chronology, and endpoint freshness.
- Card schema/prohibited-output lint, G0 lint, build prerequisite guard, SPEC
  validation, target registry checks, and synchronized canonical/intake/build
  card content: PASS.
- The repository-wide registry audit remained FAIL on 1,500 pre-existing
  legacy inventory issues across 4,366 EA and 15,966 magic rows; it returned
  zero issue strings for `20300`, `wti-max-regime`, or `203000000`.
- Exactly one setfile exists. Its normalized-content build hash, written by
  the target build checker, is
  `FFA272CF9A4A5FA92CB586D6F5F50430C7CB0B6097C5124D8D597D577FA0E114`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `3E72ABE90BDE7672B98799CEC8E615FF0C245FE68E43FD8FC4E83A9CF563E776` |
| Bounded source packet | `AC538AA694B5027469990B0AC4051D52EE25A61DEE73571494164CB6A069C67F` |
| Canonical / intake / build card | `6B1A4BD6EFB1D1F6671A47ACDB45AAF656F38FDA123144182DAAA015ACE57CEA` |
| MQ5 | `27EF6B33528B514F7543B06D833D4607206F11D76CAD59622AB3E65E49209160` |
| EX5 | `860A34EC96B06095594B9BDCF50A24498DB94F906149C0E05B0C7B329D46F106` |
| SPEC | `6115D43BBBCDD601ECFD2BA9327E4E259687BE0191050CA001DB926DF13427C3` |
| Backtest set | `0DEAEE2C878311845300AB4984ED97E496F203FAFB535F4B8E5F2481BB49649D` |
| Reference test | `3641DD3CA7683B3DD4DBECDFD521B7B96A8610CA5988AA02005FE9234C1E25F9` |

## Q02 Capacity And Enqueue Evidence

Path-anchored samples counted only executables rooted exactly under
`D:/QM/mt5/T1..T10/terminal64.exe`; `T_Live` and all non-factory paths were
excluded and were not controlled or modified:

| Sample | UTC | Factory terminals | Ceiling |
|---|---|---:|---:|
| Before duplicate/dry-run checks | `2026-08-13T05:43:49.5102480Z` | 5 | 7 |
| Immediately before apply | `2026-08-13T05:44:28.6801954Z` | 5 | 7 |
| Immediately after enqueue/readback | `2026-08-13T05:44:58.4511497Z` | 5 | 7 |

Before apply, `farmctl work-items --ea QM5_20300` returned zero rows. The
target-only dry run selected exactly one fresh Q02 row, zero stranded rows,
and zero deferred promotions. Immediately before apply the duplicate check
again returned zero rows. The apply receipt recorded 928 pending rows at
start against the 7,000-row queue ceiling and inserted the same single row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20300 --queue-ceiling 7000 --max-part2-per-run 0
```

| Field | Value |
|---|---|
| Work item | `42f8f5dd-b01e-493f-ba28-c51e9ff2b9d8` |
| Created | `2026-08-13T05:44:42+00:00` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / D1 |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20300_wti-max-regime/sets/QM5_20300_wti-max-regime_XTIUSD.DWX_D1_backtest.set` |
| Enqueue class | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track | priority |
| Immediate status | active; claimed by T3 |
| Attempt / evidence / verdict | 0 / none / none |

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`BAEEC1CB1896B61A63333BCD839A67A7EAF85333910B6D01B3A6D882B03F2F6D`
at immediate readback. Because the receipt is shared and rolling, the unique
farm work-item row above is the durable queue proof.

## Scoped Commits Before Closing Evidence

- `c8a283f35` — durable OWNER mission G0 authorization.
- `af81443b6` — bounded source packet and synchronized approved/intake cards.
- `a1d681280` — deterministic EA-ID reservation.
- `84d48aa37` — slot-0 WTI magic, initial SPEC, and regenerated resolver.
- `c30e195de` — EA source, EX5, fixed-risk setfile, independent reference,
  synchronized cards, and Q01 evidence bindings.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, `T_Live` file, or T_Live manifest
  was used for control or changed.
- No portfolio-gate path was touched; the scoped mission diff has zero
  `T_Live` or portfolio-gate path changes.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
