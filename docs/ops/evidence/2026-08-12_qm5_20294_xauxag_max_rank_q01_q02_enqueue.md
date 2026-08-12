# QM5_20294 XAU/XAG Low-MAX Rank — Q01 PASS / Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20294_xauxag-max-rk` is a new low-frequency, opposite-side XAU/XAG
upper-order-statistic candidate. It is built, Q01 is `PASS`, and exactly one
logical basket row is enqueued at Q02. Work item
`b9bde578-9476-470f-a051-fda0a11116c6` was pending at immediate readback,
attempt 0, unclaimed, with no evidence path or verdict. This mission issued no
dispatch tick and ran no manual backtest. Enqueue is not certification,
efficacy, neutrality, decorrelation, or portfolio admission.

## Edge And Mechanical Contract

At the first processed XAU D1 bar after a genuine broker-month transition,
the EA forms exactly 252 completed chronological simple returns for each metal
and computes the source-defined MAX characteristic:

```text
r[d] = close[d] / close[d-1] - 1
MAX_i = arithmetic_mean(five_largest(r_i[1..252]))
```

It buys XAU and sells XAG when `MAX_XAU < MAX_XAG`; otherwise it sells XAU
and buys XAG when `MAX_XAU > MAX_XAG`. A difference within `1e-12`, incomplete
or stale history, invalid price/chronology/arithmetic, or another failed gate
consumes the month flat. One terminal-persistent attempt marker is written
before history and order gates.

The package splits one `RISK_FIXED=1000` budget equally by stop risk, attaches
frozen `3.5 * ATR(20,D1)` broker hard stops, renews at the next broker month,
closes stale after forty days, and immediately flattens an orphan, missing-stop,
or malformed package. The only setfile is `environment=backtest`,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both news axes
and Friday close are OFF. There is no trained output, prohibited signal
indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Source And Non-Duplicate Review

The primary source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in
Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The governed parent packet records a
complete read of the 57-page accepted article and online appendix and is bound
by SHA-256
`66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47`.
The bounded carrier packet is
`strategy-seeds/sources/HOLLSTEIN-XAUXAG-MAX-2026/source.md`; durable G0
authorization is
`decisions/2026-08-12_qm5_20294_xauxag_max_rank_g0.md`.

The paper defines MAX as the mean of the five largest prior-year daily
commodity-futures excess returns and supplies monthly cadence. Its full-sample
hedge return and two-portfolio result are null; only the December 2000-
December 2015 post-financialization subsample supports the locked negative
high-minus-low direction. It does not test a two-metal continuous-CFD carrier.
Those facts are binding Q02 kill risks, and no source return, alpha, cost,
neutrality, CFD equivalence, or correlation transfers.

The canonical pre-card check scanned 4,359 EA-registry rows and 470 cards. It
found no exact slug, strategy-ID, or mechanic identity and returned ten
expected fuzzy neighbors. Manual review separated them:

- `QM5_13130` is the same locked statistic on XTI/XNG, not this XAU/XAG
  carrier, and supplies no sibling pipeline result.
- `QM5_20291` uses all 252 returns in Pearson historical kurtosis and buys
  high kurtosis; this rule uses only the five largest returns and buys low MAX.
- Existing XAU/XAG skewness, semivariance, expected-shortfall, volatility-of-
  volatility, variance-ratio, return-shock, ratio, OLS, quantile, momentum,
  calendar, and RSI systems use different information objects.
- `QM5_12567` is a short-horizon long-only cumulative-RSI pullback.

Verdict: `CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`. Opposite sides and
equal stop-risk halves reduce outright-metal intent but do not prove dollar,
beta, volatility, factor, market, or portfolio neutrality. Q09 alone may
establish realized overlap with the XAU/SP500/NDX/XNG book.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20294` / `xauxag-max-rk` /
  `HOLLSTEIN-MAX-2021_XAU_XAG_S04`.
- XAU/slot/magic: `XAUUSD.DWX` / 0 / `202940000`.
- XAG/slot/magic: `XAGUSD.DWX` / 1 / `202940001`.
- Resolver generation kept 15,906 rows and dropped zero; embedded registry
  SHA-256:
  `D98434498D46CDFD299DC78D3412BF2FB4B3E162299643B9DBC918615FB7E981`.
- Strict compile: `D:/QM/reports/compile/20260812_221737/summary.csv`, PASS
  with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260812_221737/QM5_20294_xauxag-max-rk.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260812_221737.json`, PASS with
  zero failures and zero warnings. The post-blank-line setfile hash refresh
  also passed at
  `D:/QM/reports/framework/21/build_check_20260812_221925.json`.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20294/P1/P1_QM5_20294_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20294_xauxag-max-rk/docs/test_max_measure_reference.py`,
  PASS (`xau_max=0.022000000000`, `xag_max=0.042000000000`, direction
  `LONG_XAU_SHORT_XAG`).
- Card schema/ML lint, G0 lint, build prerequisite guard, SPEC validation,
  target runtime guardrails, registry formula/uniqueness, and synchronized
  canonical/intake/build-card content: PASS.
- Setfile header build hash:
  `b38b889eb2c5444f2893d3bb1cee9b17b5dbb0282c29110cc0cd4ab91b48fdca`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `A75F385569D9E7D8923F799535404C67A2CB5BAEF2575D315EE13B08681F4682` |
| Bounded source packet | `2312ABC8224C014AD84B1F3506DB7D42E502ACF56DB492019A94E242D15900F8` |
| Canonical/intake/build card | `798BC15063CAD8BD758EBFF3EC30859A73E6811D77EF173981B7B936D1681F0C` |
| MQ5 | `89E93D4583F174E33F4D78C5C154B9ADC30405FD4753C703A9AA8E57111E34A1` |
| EX5 | `9425AA537DAA333D559A74A5F613A4F010C0BA2AD72101B9C3ACF87C07897510` |
| SPEC | `5AD0CBD08689E4F1DA5B8969F6A4BF0D346EB5FA9306022953756F4C81337403` |
| Basket manifest | `92B6F3778610AEF48BED374D9C3C16762D007BC37643D92BD82997DAF4A1930D` |
| Backtest set | `7A358536BCCC124AC2315FE340119906DEF98459D604978AAF62A98C423A654B` |
| Reference test | `74F393486E0E660119A0513A1564A371758FF8622FC939A6D66EBF8FD2DC8029` |

## Q02 Capacity And Enqueue Evidence

The path-anchored capacity sample at
`2026-08-12T22:20:04.5021250Z` found zero executables rooted under
`D:/QM/mt5/T1..T10/terminal64.exe`, below the seven-job CPU ceiling. The
post-enqueue readback at `2026-08-12T22:20:40.9511904Z` still found zero.
`T_Live` and FTMO paths were excluded from the count and were not controlled
or modified.

The apply receipt reported 952 pending rows at start against the 7,000-row
queue ceiling. The scoped basket-aware dry run selected exactly one fresh Q02
row and zero stranded rows. The apply command enqueued the same one row and no
unrelated recovery work:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20294 --queue-ceiling 7000 --max-part2-per-run 0
```

| Field | Value |
|---|---|
| Work item | `b9bde578-9476-470f-a051-fda0a11116c6` |
| Phase / kind | `Q02` / `backtest` |
| Logical symbol | `QM5_20294_XAU_XAG_LOWMAX_D1` |
| Host | `XAUUSD.DWX` / D1 |
| Basket symbols | `XAUUSD.DWX`, `XAGUSD.DWX` |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20294_xauxag-max-rk/sets/QM5_20294_xauxag-max-rk_QM5_20294_XAU_XAG_LOWMAX_D1_D1_backtest.set` |
| Enqueued by | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track / scope | priority / basket |
| Status | pending at immediate readback |
| Attempt / claim / verdict | 0 / none / none |

The rolling enqueue receipt was
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`547D299A7AE44BD18D801A9F647AF66312D59B19AC181A0B4D8771E32BD76783`
at immediate readback. Because that receipt is shared and rolling, the durable
proof is the unique SQLite work-item row above.

## Scoped Commits Before Closing Evidence

- `309137b5f` — durable G0 decision, bounded source packet, and synchronized
  approved/intake cards.
- `2b3068374` — deterministic EA-ID reservation.
- `d4491d471` — target SPEC, two symbol-magics, and generated resolver.
- `b24dba77a` — EA source, EX5, basket manifest, fixed-risk setfile, reference
  test, synchronized cards, and Q01 bindings.

All scoped staging remained on `agents/board-advisor`. The pre-existing
untracked Brent-to-WTI review artifact was left untouched.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, `T_Live` file, or T_Live manifest
  was changed.
- The portfolio gate was not touched.
- No efficacy, certification, neutrality, decorrelation, or portfolio-
  admission result is inferred from Q01 or the Q02 enqueue.
