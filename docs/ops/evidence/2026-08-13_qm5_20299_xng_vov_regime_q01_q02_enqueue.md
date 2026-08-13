# QM5_20299 XNG Realized-VoV Regime — Q01 PASS / Q02 Enqueued

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20299_xng-vov-regime` is a new low-frequency outright-XNG uncertainty-
regime candidate. It is built, Q01 is `PASS`, and exactly one fixed-risk
`XNGUSD.DWX` D1 row is enqueued at Q02. Work item
`19cae282-9ed8-4791-b439-868b1c51e867` was pending at immediate readback,
attempt 0, unclaimed, with no evidence path or verdict. This mission issued no
dispatch tick and ran no manual backtest. Enqueue is not efficacy,
certification, decorrelation, or portfolio admission.

## Edge And Mechanical Contract

At the first processed D1 bar after a genuine broker-month transition, the EA
loads exactly 543 completed XNG D1 closes, newest first. It forms two
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
EA owns at most one XNG position, attaches a frozen `3.5 * ATR(20,D1)` broker
hard stop, has no take profit, exits at the next broker month, and closes stale
after forty calendar days. Malformed owned state is flattened before entry
logic. The sole setfile is `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the entry spread ceiling is 2,500
points. News axes and Friday close are OFF. There is no external runtime feed,
trained output, banned signal indicator, grid, martingale, scale-in, or
pyramid.

## Source And Non-Duplicate Review

The primary source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in
Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The governed complete-read parent
packet covers the accepted article and online appendix, explicitly includes
natural gas, and is bound by SHA-256
`F54F17F2DCDA40000D939D2D89122F4EA3F305293018AFF331A6C018F3DBDD00`.
The bounded extraction is
`strategy-seeds/sources/HOLLSTEIN-XNG-VOV-REGIME-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20299_xng_vov_regime_g0.md`.

The paper defines option-implied VoV as the population standard deviation of
252 daily implied-volatility observations divided by their mean, applies a
monthly broad commodity cross-sectional sort, includes natural gas, and
reports a negative high-minus-low relation. It does not test the EA's nested
realized-volatility proxy, two-block own-history comparison, outright XNG
rule, continuous CFD, hard stop, or QM book decorrelation. Later source
evidence is weaker, and the paired realized-proxy parent
`QM5_13146_energy-vov` later failed Q08. Those limitations are preserved: this
is an explicit low-prior QM translation, not a transferred source result.

The canonical pre-allocation check scanned 4,364 EA-registry rows and 475 root
cards. It found no exact slug, strategy-ID, or mechanic identity and returned
ten expected lexical/source-family neighbors. Manual review separated them:

- `QM5_13146_energy-vov` ranks concurrent XTI and XNG VoV and trades a paired
  package; this EA compares two disjoint XNG history blocks and owns one leg.
- `QM5_20236_xauxag-vov-rank` ranks two precious metals and has paired
  execution rather than an outright XNG state.
- `QM5_20298_wti-vov-regime` preserves the estimator on WTI, but has different
  registered history, contract economics, spread, magic, and Q02 verdict.
- `QM5_13046_xti-vrp-proxy` uses realized-volatility level to gate a stretch
  fade; it does not measure dispersion along rolling realized volatility.
- `QM5_20297_xng-kurt-prem` and `QM5_20296_xng-skew-prem` use centered fourth
  and third return moments, not nested realized VoV.
- The certified `QM5_12567` XNG sleeve is a short-horizon, long-only
  cumulative-RSI pullback, not monthly symmetric XNG uncertainty logic.

Verdict: `CLEAN_AUTHORIZED_XNG_CARRIER_AFTER_MANUAL_REVIEW`. The incumbent
book already has XNG exposure; the new state and lifecycle are mechanically
different, while low realized overlap remains a hypothesis that Q09 must test
against XAU/SP500/NDX/XNG.

## Deterministic Allocation And Q01 Evidence

- EA / slug / strategy: `QM5_20299` / `xng-vov-regime` /
  `HOLLSTEIN-VOV-2021_XNG_TS_S04`.
- Symbol / slot / magic: `XNGUSD.DWX` / 0 / `202990000`.
- The EA registry and magic registry each contain one target row; the target
  magic is unique and equals `ea_id * 10000 + slot`.
- Resolver generation kept 15,911 rows and dropped zero; embedded registry
  SHA-256:
  `D5F8562487904AA619B32F380F14284E929EB6A22A3CB52BB6B7FD4DD84F85FC`.
- Strict compile: `D:/QM/reports/compile/20260813_042814/summary.csv`, PASS
  with strict mode true, zero errors, and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260813_042814/QM5_20299_xng-vov-regime.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260813_042838.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20299/P1/P1_QM5_20299_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20299_xng-vov-regime/docs/test_vov_reference.py`, 6/6
  PASS for nested denominators, source direction, comparison tolerance,
  disjoint return support, price-scale invariance, exact counts, chronology,
  and endpoint freshness.
- Card schema/ML lint, G0 lint, build prerequisite guard, SPEC validation,
  target registry/runtime guardrails, normalized carrier-port comparison, and
  synchronized canonical/intake/build card content: PASS.
- Exactly one setfile exists. Its normalized-content build hash, written by
  the target build checker, is
  `8F126C1CB0FC7C61799D443C97266F27640E65CE6570837373C4A672CF23C0B6`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `B7B41ABDFEA7CE57CA82F93C57CFE75106EA3DCF46CBD823080F652D56F45B69` |
| Bounded source packet | `92C8C03CD7DBBDEA74643809BE10683F679BE6F5EAA65B3ABBF68D0C63B6DBDE` |
| Canonical / intake / build card | `91B9AC3AEBBCF79DE16FCF7803854453DA796A8CD834AED5F8F1246DA93A5BBB` |
| MQ5 | `CF4D93FEDC87AF8AF783D898E666BB642E419A166598D85AE8871FBF697E19C9` |
| EX5 | `5D60A33B374B5B7D096C2B3E40F699C369965CBE0A063116FF6FDE341C7A568C` |
| SPEC | `DAEE209F9E3C10954E65031AEF6C206619D5F6280BE896C583E9DB673917710F` |
| Backtest set | `7C651415E24574798F8A18BDDCA48682D6CB6D0F6800F6EBFD421EFA6A6E80E0` |
| Reference test | `ED4548E097B94DCB9796C8A4510D2EA27EF971F80E3A5E73D1A78214B74A2367` |

## Q02 Capacity And Enqueue Evidence

Path-anchored samples counted only executables rooted exactly under
`D:/QM/mt5/T1..T10/terminal64.exe`; `T_Live` and all non-factory paths were
excluded and were not controlled or modified:

| Sample | UTC | Factory terminals | Ceiling |
|---|---|---:|---:|
| Before duplicate/dry-run checks | `2026-08-13T04:30:36.4875680Z` | 5 | 7 |
| Immediately before apply | `2026-08-13T04:31:53.6508155Z` | 4 | 7 |
| Immediately after enqueue | `2026-08-13T04:32:07.5360100Z` | 4 | 7 |

One existing fleet terminal ceased appearing in the exact process sample
during this interval. It was observed only; this mission did not start, stop,
reserve, reap, or alter any terminal.

Before apply, `farmctl work-items --ea QM5_20299` returned zero rows. The
target-only dry run selected exactly one fresh Q02 row, zero stranded rows,
and zero deferred promotions. Immediately before apply the duplicate check
again returned zero rows. The apply receipt recorded 940 pending rows at
start against the 7,000-row queue ceiling and inserted the same single row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20299 --queue-ceiling 7000 --max-part2-per-run 0
```

| Field | Value |
|---|---|
| Work item | `19cae282-9ed8-4791-b439-868b1c51e867` |
| Created | `2026-08-13T04:31:53+00:00` |
| Phase / kind | `Q02` / `backtest` |
| Symbol / timeframe | `XNGUSD.DWX` / D1 |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20299_xng-vov-regime/sets/QM5_20299_xng-vov-regime_XNGUSD.DWX_D1_backtest.set` |
| Enqueue class | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track | priority |
| Status | pending at immediate readback |
| Attempt / claim / evidence / verdict | 0 / none / none / none |

The rolling enqueue receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`AE951D0470B388F400EEE5740EA79B1AD5B1EBC85E915FB266214B08F8167D0E`
at immediate readback. Because the receipt is shared and rolling, the unique
farm work-item row above is the durable queue proof.

## Scoped Commits Before Closing Evidence

- `c6b99a2bd` — durable OWNER mission G0 authorization.
- `451c4f4c5` — bounded source packet and synchronized approved/intake cards.
- `efb207e70` — deterministic EA-ID reservation.
- `415d6a493` — slot-0 XNG magic, initial SPEC, and regenerated resolver.
- `d88b51450` — EA source, EX5, fixed-risk setfile, independent reference,
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
