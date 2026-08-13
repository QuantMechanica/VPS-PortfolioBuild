# QM5_20301 WTI Expected-Shortfall Regime — Q01 PASS / Q02 Enqueued

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20301_wti-es-regime` is a new low-frequency outright-WTI downside-tail
state candidate. It is built, Q01 is `PASS`, and exactly one fixed-risk
`XTIUSD.DWX` D1 row was enqueued at Q02. Work item
`391694f4-f6d3-400a-9f3b-9f8f5d700ae0` was pending at immediate readback,
attempt 0, with no worker, evidence path, or verdict. This mission issued no
dispatch tick and ran no manual backtest. Enqueue is not efficacy,
certification, decorrelation, or portfolio admission.

## Edge And Mechanical Contract

At the first processed D1 bar after a genuine broker-month transition, the EA
loads exactly 505 completed WTI D1 closes, newest first, and calculates
historical expected shortfall over two consecutive return blocks:

```text
r[b,k] = close[b+k] / close[b+k+1] - 1, k=0..251
K      = ceil(252 * 0.05) = 13
ES[b]  = arithmetic_mean(13 smallest r[b,0..251])

recent block b=0:       return indices 0..251
preceding block b=252:  return indices 252..503
```

The blocks share only close index 252 and share no return. The EA buys when
recent ES is higher, hence less negative, than preceding ES by more than
`1e-12`; it sells when recent ES is lower by more than `1e-12`; and it
consumes the month flat on a tie or invalid state. It requires positive finite
closes, strictly older timestamps by increasing series index, exact completed-
history and tail counts, and a completed endpoint before the decision bar and
at most ten calendar days stale.

A terminal-persistent month marker is written before history, signal, spread,
quote, news, ATR, sizing, or order gates, preventing same-month retries. The
EA owns at most one WTI position, attaches a frozen `3.5 * ATR(20,D1)` broker
hard stop, has no take-profit, exits at the next broker month, and closes stale
after forty calendar days. Malformed owned state is flattened before entry
logic. The sole setfile is `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the spread ceiling is 1,500
points. News axes and Friday close are OFF. There is no external runtime feed,
trained output, prohibited signal indicator, grid, martingale, scale-in, or
pyramid.

## Source And Claim Boundary

The primary source is Qin, Cai, Zhu, and Webb (2025), "Commodity Futures
Characteristics and Asset Pricing Models," *Journal of Futures Markets*
45(3), 176-207, DOI `10.1002/fut.22559`. The governed complete-read parent
packet is bound by SHA-256
`AC00A311DCA3BDB3C1BF47725EAB1887BC0335ADE84E898F4DBD8117C3A36FE9`.
The bounded extraction is
`strategy-seeds/sources/YIYI-WTI-ES-REGIME-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20301_wti_es_regime_g0.md`.

The paper defines prior-year expected shortfall as the mean of the worst five
percent of daily returns, renews the cross-sectional characteristic monthly,
and uses a high-minus-low direction. Its full-sample one-way hedge has a weak
1.36 t-statistic. It does not test the EA's two-block own-history comparison,
outright WTI direction, continuous CFD, hard stop, or QM-book decorrelation.
The closest source-family build, `QM5_13143_energy-es-rank`, passed Q02 but
failed all three Q04 OOS folds with net PF 0.782, 0.314, and 0.000. These
limitations and adverse evidence are preserved: this is an explicit low-prior
QM translation, not a transferred source result.

## Non-Duplicate Review

The canonical pre-allocation check scanned 4,366 EA-registry rows and 477
root cards. It found no exact slug, strategy-ID, or mechanic identity and
returned five expected source/name neighbors. Manual review separated the
material neighbors:

- `QM5_13143` and `QM5_20235` rank two concurrent energy or metal instruments
  and execute paired packages; this EA compares two disjoint WTI history
  blocks and owns one leg.
- `QM5_20300_wti-max-regime` averages the five largest returns and buys the
  lower-MAX state; this EA averages the thirteen smallest returns and buys the
  higher-ES state.
- `QM5_20289_wti-rsj-rev` uses one complete month and signed semivariance, not
  sorted lower-tail means over two annual blocks.
- WTI skewness, kurtosis, VoV, trend, robust-location, calendar, event,
  breakout, variance-ratio, and ordinary reversal builds use different state
  objects or clocks.
- The certified `QM5_12567` sleeve is short-horizon, long-only XNG cumulative-
  RSI pullback logic on another energy carrier.

Verdict: `CLEAN_AUTHORIZED_WTI_TIME_SERIES_ES_AFTER_MANUAL_REVIEW`. Crude-oil
exposure and the downside-tail state are structurally different from the
incumbent XAU/SP500/NDX/XNG book, but low realized overlap remains only a
hypothesis; Q09 owns correlation acceptance.

## Deterministic Allocation And Q01 Evidence

- EA / slug / strategy: `QM5_20301` / `wti-es-regime` /
  `YIYI-ES-2025_XTI_TS_S04`.
- Symbol / slot / magic: `XTIUSD.DWX` / 0 / `203010000`.
- The EA registry and magic registry each contain one target row; the target
  magic is unique and equals `ea_id * 10000 + slot`.
- Resolver generation kept 15,913 active rows and dropped zero; embedded
  registry SHA-256:
  `3BBA8BFBBCEF661CFBE876CB3D3016DF4B295C104B4A2BFF251729EB17D91A35`.
- Strict compile: `D:/QM/reports/compile/20260813_073825/summary.csv`, PASS
  with strict mode true, zero errors, and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260813_073825/QM5_20301_wti-es-regime.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260813_073824.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20301/P1/P1_QM5_20301_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20301_wti-es-regime/docs/test_es_reference.py`, 6/6 PASS
  for exact ceiling tail count and simple returns, source direction,
  comparison tolerance, disjoint support, price-scale invariance, exact
  counts, chronology, and endpoint freshness.
- Card schema/prohibited-output lint, G0 lint, build prerequisite guard, SPEC
  validation, target registry checks, and synchronized canonical/intake/build
  card content: PASS.
- The repository-wide legacy registry audit remains FAIL on unrelated
  pre-existing numeric-ID parsing and inventory findings; direct target checks
  returned one correct EA row, one correct magic row, and no target collision.
- Exactly one setfile exists. Its normalized-content build hash, written by
  the target build checker, is
  `57db263993f9d10ed336ddd151b4423a515e3ba4fe0039753917da074c37dde4`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `0FD836D402551675C82A6DA2DB984EA1E24C932679F37A2C0132DF61184D35A3` |
| Bounded source packet | `2EFA28362B110D0DEA515EDB84165A8BE87C186A6A5C8DBD4F42BC9BC779F4FE` |
| Canonical / intake / build card | `F977A248BEFAB2D8006895E82C5BE5051EAD43F720944245C8B219C34B1F50E7` |
| MQ5 | `85BEE96AA1F6F458D9A70E309F81AC1FFF764749C074BA6C2AAE18132FC96DB1` |
| EX5 | `6128FE7B80423F05944F42AAE04810A8EAFBDE5E8F39A58F927EB560249B2353` |
| SPEC | `FE5160E9A4559C66E17A8DAE450073122ED2C6E848079F2427DF3AB96D378485` |
| Backtest set | `3C08ACC2FE1DA97EB99A01F93F295BC886B0DE90AE441DE41CAB6DB0124923AC` |
| Reference test | `EB8C17204D68974AD28DFD9C5B7D6BDCE9CEB9F961AA532096856D8355EE1649` |
| Generated magic resolver | `36E3468CE9912D45298B8A1B2360881268750CAD541D243EF8F2A7640415330E` |

## Q02 Capacity And Enqueue Evidence

Capacity samples counted only executables rooted exactly under
`D:/QM/mt5/T1..T10/terminal64.exe`; `T_Live` and unrelated FTMO processes were
excluded and were not controlled or modified:

| Sample | UTC | Factory terminals | Ceiling |
|---|---|---:|---:|
| Before duplicate/dry-run checks | `2026-08-13T07:41:53Z` | 4 (`T1,T5,T9,T10`) | 7 |
| Immediately before apply | `2026-08-13T07:42:19.5310368Z` | 3 (`T5,T9,T10`) | 7 |
| Immediately after enqueue/readback | `2026-08-13T07:42:35.3322295Z` | 3 (`T5,T9,T10`) | 7 |

Before apply, `farmctl work-items --ea QM5_20301` returned zero rows. The
target-only dry run selected exactly one fresh Q02 row, zero stranded rows,
and zero deferred promotions. Immediately before apply the duplicate check
again returned zero rows. The apply receipt recorded 922 pending rows at
start against the 7,000-row queue ceiling and inserted the same single row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20301 --queue-ceiling 7000 --max-part2-per-run 0
```

| Field | Value |
|---|---|
| Work item | `391694f4-f6d3-400a-9f3b-9f8f5d700ae0` |
| Created | `2026-08-13T07:42:24+00:00` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / D1 |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20301_wti-es-regime/sets/QM5_20301_wti-es-regime_XTIUSD.DWX_D1_backtest.set` |
| Enqueue class | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track | priority |
| Immediate status | pending; unclaimed |
| Attempt / evidence / verdict | 0 / none / none |

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`6935108D911AFC266512EF4518321AE1163AC9C0DFB90F9404B11519FF069448`
at immediate readback. Because the receipt is shared and rolling, the unique
farm work-item row above is the durable queue proof.

## Scoped Commits Before Closing Evidence

- `4ba9f4d4d` — durable OWNER mission G0 authorization.
- `493f13342` — bounded source packet and synchronized approved/intake cards.
- `186d1b3c9` — deterministic EA-ID reservation.
- `becc17fff` — slot-0 WTI magic, initial SPEC, and regenerated resolver.
- `780c70785` — EA source, EX5, fixed-risk setfile, independent reference,
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
