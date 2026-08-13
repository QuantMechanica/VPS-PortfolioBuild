# QM5_20302 WTI ALIQ Regime - Q01 PASS / Q02 Enqueued

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20302_wti-aliq-regime` is a new low-frequency outright-WTI
activity-price-impact state candidate. It is built, Q01 is `PASS`, and exactly
one fixed-risk `XTIUSD.DWX` D1 row was enqueued at Q02. Work item
`9666a9ef-f51a-464f-a883-90a89945d45d` was active on T6 at immediate
readback, attempt 0, with no evidence path or verdict. This mission issued no
dispatch tick and ran no manual backtest. Enqueue and worker claim are not
efficacy, certification, decorrelation, or portfolio admission.

## Edge And Mechanical Contract

At the first processed D1 bar after a genuine broker-month transition, the EA
loads exactly 505 completed WTI D1 rates, newest first, and calculates an
Amihud-style illiquidity proxy over two consecutive blocks:

```text
r[b,k]       = ln(close[b+k] / close[b+k+1]), k=0..251
aliq[b,k]    = abs(r[b,k]) / tick_volume[b+k] * 1,000,000
ALIQ[b]      = arithmetic_mean(aliq[b,0..251])

recent block b=0:       close pairs 0/1..251/252; volumes 0..251
preceding block b=252:  close pairs 252/253..503/504; volumes 252..503
```

The blocks share only close index 252 and share no return or tick-volume
observation. The EA buys when recent ALIQ is higher than preceding ALIQ by
more than `1e-12`; it sells when recent ALIQ is lower by more than `1e-12`;
and it consumes the month flat on a tie or invalid state. It requires positive
finite closes, strictly positive used tick volumes, strictly older timestamps
by increasing series index, exact completed-history and observation counts,
and a completed endpoint before the decision bar and at most ten calendar
days stale.

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
`EB8D48BA2F04350634370358961686F24E7842AF09CBE30614FC001452558B85`.
The bounded extraction is
`strategy-seeds/sources/YIYI-WTI-ALIQ-REGIME-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20302_wti_aliq_regime_g0.md`.

The paper defines ALIQ as the prior-year average of absolute daily return
divided by dollar volume, renews the cross-sectional characteristic monthly,
and uses a high-minus-low direction. It does not test the EA's two-block
own-history comparison, outright WTI direction, tick-volume proxy, continuous
CFD, hard stop, or QM-book decorrelation. MT5 quote-tick counts are not source
dollar volume.

The closest source-family build, `QM5_13140_energy-aliq-rank`, passed Q02
through Q07 and failed Q08 hard on a runs-test p-value of `0.00226`. Its 2024
Q02 row had 82 trades, PF 1.19, and net profit 1,787.12 at fixed risk. Those
facts are preserved as material family evidence but do not transfer to this
carrier or waive any gate.

## Non-Duplicate Review

The canonical pre-allocation check scanned 4,367 EA-registry rows and 478
root cards. It found no exact slug, strategy-ID, or mechanic identity and
returned two expected fuzzy neighbors. Manual review separated them:

- `QM5_13140` ranks concurrent XTI and XNG proxy values over the prior twelve
  complete months, executes opposite legs, splits package risk, and repairs
  orphans. This EA compares two fixed WTI history blocks and owns one leg.
- `QM5_20301_wti-es-regime` shares the one-leg WTI, two-block, and monthly
  lifecycle architecture but sorts the lower five-percent tail of simple
  returns and averages thirteen observations. This EA averages all 252
  absolute log returns divided by same-bar tick volume.
- WTI trend, calendar, event, variance-ratio, robust-location, reversal,
  skewness, kurtosis, MAX, ES, and VoV builds use different information
  objects or clocks.
- The certified `QM5_12567` sleeve is a short-horizon, long-only XNG
  cumulative-RSI pullback on another carrier.

Verdict: `CLEAN_AUTHORIZED_WTI_TIME_SERIES_ALIQ_AFTER_MANUAL_REVIEW`. Crude-
oil exposure and the activity-price-impact state are structurally different
from the incumbent XAU/SP500/NDX/XNG book, but low realized overlap remains a
hypothesis; Q09 owns correlation acceptance.

## Deterministic Allocation And Q01 Evidence

- EA / slug / strategy: `QM5_20302` / `wti-aliq-regime` /
  `YIYI-ALIQ-2025_XTI_TS_S02`.
- Symbol / slot / magic: `XTIUSD.DWX` / 0 / `203020000`.
- The EA registry and magic registry each contain one target row; the target
  magic is unique and equals `ea_id * 10000 + slot`.
- Resolver generation kept 15,914 active rows and dropped zero; embedded
  registry SHA-256:
  `038395D450A8208459676C9A53D32A95478DDD60CDAF74EA6F6C8C9F18A479A0`.
- Strict compile: `D:/QM/reports/compile/20260813_083041/summary.csv`, PASS
  with strict mode true, zero errors, and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260813_083041/QM5_20302_wti-aliq-regime.compile.log`.
- Final target build check before enqueue:
  `D:/QM/reports/framework/21/build_check_20260813_083330.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20302/P1/P1_QM5_20302_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20302_wti-aliq-regime/docs/test_aliq_reference.py`, 6/6
  PASS for exact log-return/same-bar-volume arithmetic, source direction,
  tolerance, disjoint support, price- and volume-scale behavior, counts,
  positive volume, chronology, and endpoint freshness.
- Card schema/prohibited-output lint, G0 lint, build prerequisite guard,
  target registry checks, and synchronized canonical/intake/build card
  content: PASS.
- Exactly one setfile exists. Its normalized-content build hash at enqueue is
  `b1d09fdc1d9bf5fdb7c976820c49a03f20907ee89e9629ac47a40cd3680226da`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `76E7F3B11DEF61FBF05A183ED3AFBC632F6CFB84CC208D60CCA2004F7122FE5F` |
| Bounded source packet | `B27833AC79A061456D4BDDE9E1CD40EBB37824C0306E1E80547F16E696F04619` |
| Canonical / intake / build card | `E4CEDEF62A4FA69D24B8B0C636B8D5A61D26233A0B243714CEDC851C41BFC0CC` |
| MQ5 | `BBBAF0E04659E68A94640EED206FDE49B78C1539BCA1A709F25CBF95DE1037F1` |
| EX5 | `1501A1370A0CA68910F93407E8E92DF0691C436E873361D969D6925A003CF99A` |
| SPEC | `1566E2ED2DB43E6327B47784BC8D799CC051ED9D9DA7989CA7041E47A70482C3` |
| Backtest set | `0DB9FD952E2018A3EACC4A53E1AD8D97D068E771095C242726CFEB9B98AD61D0` |
| Reference test | `F2037438E1E861F46C45126CC5E331AC497D78A085083AB43D8198C422FB54C4` |
| Generated magic resolver | `E51E6BD0C2A4488BA33ACFE57555BA4E0D713F3ACDD4675DA181E9DC5EA9C5B0` |

## Q02 Capacity And Enqueue Evidence

Capacity samples counted only executables rooted exactly under
`D:/QM/mt5/T1..T10/terminal64.exe`; `T_Live` and unrelated processes were
excluded and were not controlled or modified:

| Sample | UTC | Factory terminals | Ceiling |
|---|---|---:|---:|
| Before duplicate/dry-run checks | `2026-08-13T08:35:31.6735515Z` | 5 (`T1,T4,T5,T9,T10`) | 7 |
| Immediately before apply | `2026-08-13T08:36:20.5063721Z` | 4 (`T1,T4,T5,T10`) | 7 |
| Immediately after enqueue/readback | `2026-08-13T08:36:33.2786350Z` | 4 (`T1,T4,T5,T10`) | 7 |

Before apply, `farmctl work-items --ea QM5_20302` returned zero rows. The
target-only dry run selected exactly one fresh Q02 row, zero stranded rows,
and zero deferred promotions. Immediately before apply the duplicate check
again returned zero rows. The apply receipt recorded 918 pending rows at
start against the 7,000-row queue ceiling and inserted the same single row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20302 --queue-ceiling 7000 --max-part2-per-run 0
```

| Field | Value |
|---|---|
| Work item | `9666a9ef-f51a-464f-a883-90a89945d45d` |
| Created | `2026-08-13T08:36:21+00:00` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / D1 |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20302_wti-aliq-regime/sets/QM5_20302_wti-aliq-regime_XTIUSD.DWX_D1_backtest.set` |
| Enqueue class | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track | priority |
| Immediate status | active; claimed by T6 |
| Attempt / evidence / verdict | 0 / none / none |

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`542819277B7CB0E9153E3FD34740A92AB14C6D5DA3B7CEFA78174D25F20BFDC6`
at immediate readback. Because the receipt is shared and rolling, the unique
farm work-item row above is the durable queue proof.

## Scoped Commits Before Closing Evidence

- `7b2893bfa` - durable OWNER mission G0 authorization.
- `d653187aa` - bounded source packet and synchronized approved/intake cards.
- `e84bc321c` - deterministic EA-ID reservation.
- `f8ab1b30a` - slot-0 WTI magic, initial SPEC, and regenerated resolver.
- `afe95435e` - EA source, EX5, fixed-risk setfile, independent reference,
  synchronized cards, and Q01 evidence bindings.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- The existing factory claimed the enqueued row autonomously; no terminal was
  started, stopped, reserved, reaped, or altered by this mission.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, `T_Live` file, or T_Live manifest
  was used for control or changed.
- No portfolio-gate path was touched; the scoped mission diff has zero
  `T_Live` or portfolio-gate path changes.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01, Q02 enqueue, or the immediate T6 claim.
