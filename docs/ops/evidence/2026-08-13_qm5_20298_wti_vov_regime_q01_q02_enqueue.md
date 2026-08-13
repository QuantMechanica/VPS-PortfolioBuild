# QM5_20298 WTI Realized-VoV Regime — Q01 PASS / Q02 Enqueued

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20298_wti-vov-regime` is a new low-frequency outright-WTI uncertainty-
regime candidate. It is built, Q01 is `PASS`, and exactly one fixed-risk
`XTIUSD.DWX` D1 row is enqueued at Q02. Work item
`16e088fa-2b19-49d8-b0c2-027e94ddfa50` was pending at immediate readback,
attempt 0, unclaimed, with no evidence path or verdict. This mission issued no
dispatch tick and ran no manual backtest. Enqueue is not efficacy,
certification, decorrelation, or portfolio admission.

## Edge And Mechanical Contract

At the first processed D1 bar after a genuine broker-month transition, the EA
loads exactly 543 completed WTI D1 closes, newest first. It forms two
realized-volatility-of-volatility blocks:

```text
r[b,s,k] = ln(close[b+s+k] / close[b+s+k+1]), k=0..19
rv[b,s]  = sample_std(r[b,s,0..19], denominator 19) * sqrt(252), s=0..251
mean_rv[b] = average(rv[b,0..251])
vov[b] = sqrt(sum((rv[b,s] - mean_rv[b])^2) / 252) / mean_rv[b]

recent block b=0:       return indices 0..270
preceding block b=271:  return indices 271..541
```

The two blocks share only one boundary close and no return. The EA buys when
recent VoV is below preceding VoV by more than `1e-12`, sells when it is above
by more than `1e-12`, and consumes the month flat on a tie or invalid state.
It requires positive finite closes, strictly older timestamps by increasing
series index, an exact completed-close count, a completed endpoint before the
decision bar and at most ten calendar days stale, positive inner sample
variances, positive RV means and VoV population variances, and finite
arithmetic.

A terminal-persistent month marker is written before history, signal, spread,
quote, news, ATR, sizing, or order gates, preventing same-month retries. The
EA owns at most one WTI position, attaches a frozen `3.5 * ATR(20,D1)` broker
hard stop, has no take profit, exits at the next broker month, and closes stale
after forty calendar days. Malformed owned state is flattened before entry
logic. The sole setfile is `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the entry spread ceiling is 1,500
points. News axes and Friday close are OFF. There is no external runtime feed,
trained output, grid, martingale, scale-in, or pyramid.

## Source And Non-Duplicate Review

The primary source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in
Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The governed complete-read parent
packet covers the 57-page accepted article and online appendix, explicitly
includes WTI, and is bound by SHA-256
`F54F17F2DCDA40000D939D2D89122F4EA3F305293018AFF331A6C018F3DBDD00`.
The bounded extraction is
`strategy-seeds/sources/HOLLSTEIN-WTI-VOV-REGIME-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20298_wti_vov_regime_g0.md`.

The paper defines option-implied VoV as the population standard deviation of
252 daily implied-volatility observations divided by their mean, applies a
monthly broad commodity cross-sectional sort, includes WTI, and reports a
negative high-minus-low relation. It does not test the EA's nested realized-
volatility proxy, two-block own-history comparison, outright WTI rule,
continuous CFD, hard stop, or QM book decorrelation. Later source evidence is
weaker, the sample ends in 2015, and the paired realized-proxy parent
`QM5_13146_energy-vov` later failed Q08. Those limitations are preserved: this
is an explicit low-prior QM translation, not a transferred source result.

The canonical pre-allocation check scanned 4,363 EA-registry rows and 474 root
cards. It found no exact slug, strategy-ID, or mechanic identity and returned
nine expected lexical/source-family neighbors. Manual review separated them:

- `QM5_13146_energy-vov` ranks concurrent XTI and XNG VoV and trades a paired
  package; this EA compares two disjoint WTI history blocks and owns one leg.
- `QM5_20236_xauxag-vov-rank` ranks two precious metals and has paired
  execution rather than an outright WTI state.
- `QM5_13046_xti-vrp-proxy` uses realized-volatility level to gate a stretch
  fade; it does not measure dispersion along rolling realized volatility.
- `QM5_20249_xauxag-vr-spread` is a paired metal variance-ratio rule, not VoV.
- `QM5_20295_wti-kurt-prem` uses a fourth central return moment around a fixed
  normal benchmark, not nested realized VoV or a two-block state transition.
- The certified `QM5_12567` XNG sleeve is a short-horizon, long-only
  cumulative-RSI pullback, not monthly symmetric WTI uncertainty logic.

Verdict: `CLEAN_AFTER_EXPECTED_SOURCE_FAMILY_FUZZY_AND_MANUAL_REVIEW`.
Different logic and exposure are established mechanically; low realized book
overlap remains a hypothesis that Q09 must test against XAU/SP500/NDX/XNG.

## Deterministic Allocation And Q01 Evidence

- EA / slug / strategy: `QM5_20298` / `wti-vov-regime` /
  `HOLLSTEIN-VOV-2021_XTI_TS_S03`.
- Symbol / slot / magic: `XTIUSD.DWX` / 0 / `202980000`.
- The EA registry and magic registry each contain one target row; the target
  magic is unique and equals `ea_id * 10000 + slot`.
- Resolver generation kept 15,910 rows and dropped zero; embedded registry
  SHA-256:
  `E228BAE8E753A681EC29975F56F6CC7FD35A38170FB3F5E02289C1FCACFCFFEA`.
- Strict compile: `D:/QM/reports/compile/20260813_024446/summary.csv`, PASS
  with strict mode true, zero errors, and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260813_024446/QM5_20298_wti-vov-regime.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260813_024519.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20298/P1/P1_QM5_20298_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20298_wti-vov-regime/docs/test_vov_reference.py`, 6/6
  PASS for nested denominators, source direction, comparison tolerance,
  disjoint return support, price-scale invariance, exact counts, chronology,
  and endpoint freshness.
- Card schema/ML lint, G0 lint, build prerequisite guard, SPEC validation,
  target registry/runtime guardrails, and synchronized canonical/intake/build
  card content: PASS.
- The repository-wide registry validator remains red on pre-existing legacy
  malformed IDs, slugs, and duplicate magic rows outside `QM5_20298`; no
  unrelated registry debt was changed. Target-only allocation checks pass.
- Exactly one setfile exists. Its normalized-content build hash, written by
  the target build checker, is
  `32836B6E660F838948503FD603FA57C0B248B5855EEEA7CAA1F08E4A30A8DD9C`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `5BD89BA3844F224FE0DDE52CE13087CF22B0DFD3CC4FDD01935545DF1707DDFD` |
| Bounded source packet | `C3B3C7AE9ED226DAAA6F9D48D46464683A53031EE70D1F661A2C030AFA568401` |
| Canonical / intake / build card | `764F1C62BA529E8B00836375734284F85FF5CB93E424A07AC07FFC010C8C1B46` |
| MQ5 | `98171D3E555FFE3A0FD7F8F2936C79557A4A8C902D9D441555C7F3D30F003E6E` |
| EX5 | `FD1D78EC3A57CEA3A544DE2854985FE664A2F1D431E855B012C5BD26F08BA580` |
| SPEC | `E5144F8133B9232F1E6C145B4C9ACE07CA6A6801D0948BE77A19F3D3ADFD9F69` |
| Backtest set | `386809492B2EA94FF076DE6D01CF1B64A345B0C5B82ECEEC0EAD27EDAE4611D2` |
| Reference test | `562E7C4CC0FBE9E03C997306AAAD6B49802497963198F00FD8EF0550E43DE539` |

## Q02 Capacity And Enqueue Evidence

Path-anchored samples counted only executables rooted exactly under
`D:/QM/mt5/T1..T10/terminal64.exe`; `T_Live` and all non-factory paths were
excluded and were not controlled or modified:

| Sample | UTC | Factory terminals | Ceiling |
|---|---|---:|---:|
| Before duplicate/dry-run checks | `2026-08-13T02:50:58.4977247Z` | 0 | 7 |
| Immediately before apply | `2026-08-13T02:52:32.3815964Z` | 1 | 7 |
| Immediately after enqueue | `2026-08-13T02:52:52.5930120Z` | 2 | 7 |

The paced fleet independently started existing QM5_20295 and QM5_20297 work
during this interval. They remained below the ceiling and were observed only;
this mission did not start, stop, reserve, reap, or alter either terminal.

Before apply, `farmctl work-items --ea QM5_20298` returned zero rows. The
target-only dry run selected exactly one fresh Q02 row, zero stranded rows,
and zero deferred promotions. The apply receipt recorded 958 pending rows at
start against the 7,000-row queue ceiling and inserted the same single row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20298 --queue-ceiling 7000 --max-part2-per-run 0
```

| Field | Value |
|---|---|
| Work item | `16e088fa-2b19-49d8-b0c2-027e94ddfa50` |
| Created | `2026-08-13T02:52:38+00:00` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XTIUSD.DWX` / D1 |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20298_wti-vov-regime/sets/QM5_20298_wti-vov-regime_XTIUSD.DWX_D1_backtest.set` |
| Enqueue class | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track | priority |
| Status | pending at immediate readback |
| Attempt / claim / evidence / verdict | 0 / none / none / none |

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`C74F35767F6D8E8C04BB429AD37B1891F1736DB9703131159BB6D82757C6C89E`
at immediate readback. Because the receipt is shared and rolling, the unique
farm work-item row above is the durable queue proof.

## Scoped Commits Before Closing Evidence

- `441a846ed` — durable OWNER mission G0 authorization.
- `4fa4ffd2b` — bounded source packet and synchronized approved/intake cards.
- `462dabb87` — deterministic EA-ID reservation.
- `3e8b580ef` — slot-0 WTI magic, initial SPEC, and regenerated resolver.
- `64fc8f524` — EA source, EX5, fixed-risk setfile, independent reference,
  synchronized cards, and Q01 evidence bindings.

All scoped staging remained on `agents/board-advisor`. The pre-existing
untracked Brent-to-WTI review artifact was left untouched.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, `T_Live` file, or T_Live manifest
  was used for control or changed.
- No portfolio-gate path was touched; the scoped mission diff has zero
  `T_Live` or portfolio-gate path hits.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.
