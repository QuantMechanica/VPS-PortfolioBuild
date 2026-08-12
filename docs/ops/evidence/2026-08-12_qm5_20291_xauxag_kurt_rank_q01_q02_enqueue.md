# QM5_20291 XAU/XAG Historical-Kurtosis Rank — Q01 PASS / Q02 Enqueued

Date: 2026-08-12 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20291_xauxag-kurt-rk` is a new low-frequency, opposite-side XAU/XAG
fourth-moment candidate. It is built, Q01 is `PASS`, and exactly one logical
basket row is enqueued at Q02. Work item
`fbe16151-4f78-446d-a61f-a399f1c6659a` was pending at immediate readback,
attempt 0, unclaimed, with no verdict. This mission issued no dispatch tick
and ran no manual backtest. Enqueue is not certification, efficacy,
decorrelation, or portfolio admission.

## Edge And Mechanical Contract

At the first processed XAU D1 bar after a genuine broker-month transition,
the EA forms exactly 252 completed simple returns for each metal and computes
the source-defined Pearson historical-kurtosis measure:

```text
r[d] = close[d] / close[d-1] - 1
mu = sum(r[d]) / 252
s2 = sum((r[d] - mu)^2) / 251
m4 = sum((r[d] - mu)^4) / 252
kurtosis = m4 / (s2^2)
```

It buys the higher-kurtosis metal and shorts the lower-kurtosis metal. An
absolute rank difference at or below `1e-12`, incomplete/stale history,
nonpositive variance, or invalid arithmetic consumes the month flat. One
terminal-persistent attempt marker is written before data and order gates.
The package splits one `RISK_FIXED=1000` budget equally by stop risk, attaches
frozen `3.5 * ATR(20,D1)` broker hard stops, renews at the next broker month,
closes stale after forty days, and immediately flattens an orphan or malformed
package.

The only setfile is `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both news axes and Friday close
are OFF. There is no trained output, prohibited signal indicator, external
runtime feed, grid, martingale, scale-in, or pyramid.

## Source And Non-Duplicate Review

The primary source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The governed parent packet records
a complete read of the 57-page accepted article and online appendix and is
bound by SHA-256
`66791A68F7EA1705CB96C0AA0F40C0A19988F8091F50D4380D8E82EF50774C47`.
The bounded carrier packet is
`strategy-seeds/sources/HOLLSTEIN-XAUXAG-KURT-2026/source.md`; durable G0
authorization is
`decisions/2026-08-12_qm5_20291_xauxag_kurt_rank_g0.md`.

The paper specifies the estimator, high-minus-low direction, and monthly
cadence, but its directly relevant two-portfolio result is insignificant and
its later-period result reverses sign and is insignificant. It does not test
a two-metal continuous-CFD carrier. Those facts are binding Q02 kill risks;
no source return, alpha, cost, CFD equivalence, or correlation transfers.

The canonical pre-card check found no exact slug or strategy-ID identity and
five expected lexical fuzzy neighbors. Manual review separated them:

- `QM5_13131` is the same locked statistic on XTI/XNG, not this XAU/XAG
  carrier, and supplies no performance evidence.
- `QM5_20233`, `QM5_20234`, `QM5_20235`, and `QM5_20236` rank skewness,
  signed semivariance, expected shortfall, and volatility-of-volatility,
  respectively; none computes this fourth standardized moment.
- Existing ratio, OLS, quantile, return-shock, momentum, calendar,
  variance-ratio, and idiosyncratic-volatility metal baskets use different
  information objects.
- Legacy kurtosis EAs combine higher moments with other fast signals rather
  than using a pure monthly two-metal rank.
- `QM5_12567` is a short-horizon long-only cumulative-RSI pullback.

Verdict: `CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`. Opposite sides and
equal stop-risk halves reduce directional-metal intent but do not prove
dollar, beta, volatility, factor, market, or portfolio neutrality. Q09 alone
may establish realized overlap with the XAU/SP500/NDX/XNG book.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20291` / `xauxag-kurt-rk` /
  `HOLLSTEIN-MAX-2021_XAU_XAG_S03`.
- XAU/slot/magic: `XAUUSD.DWX` / 0 / `202910000`.
- XAG/slot/magic: `XAGUSD.DWX` / 1 / `202910001`.
- Resolver generation kept 15,897 rows and dropped zero; embedded registry
  SHA-256:
  `7A0BC886859429B3BE39E5A9942FC76B5138ADFFF6CDEC015A9EF6C260C093AA`.
- Strict compile: `D:/QM/reports/compile/20260812_101248/summary.csv`, PASS
  with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260812_101248/QM5_20291_xauxag-kurt-rk.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260812_101248.json`, PASS with
  zero failures and zero warnings.
- P1/Q01 artifact validation:
  `D:/QM/reports/pipeline/QM5_20291/P1/P1_QM5_20291_result.json`, PASS.
- Independent statistic reference:
  `framework/EAs/QM5_20291_xauxag-kurt-rk/docs/test_kurtosis_reference.py`,
  PASS (`xau_kurtosis=61.274399580566`,
  `xag_kurtosis=1.487520968417`).
- Card schema/ML lint, G0 lint, build preflight, SPEC validation, registry
  alignment, and canonical/intake/build-card content synchronization: PASS.
- Setfile header build hash:
  `dd0a4f34facb01877e9b76fb9ef242535bbe1b1aa1273d5869f86ecb535131be`.
- Manual smoke/backtest: none.

Artifact SHA-256 values before this evidence file:

| Artifact | SHA-256 |
|---|---|
| G0 decision | `9F0BB12A39E6BF62574CD394F7EF74203EBA7DA90AF836AE32F40D6F52A73DB8` |
| Bounded source packet | `578F1FE7C7D09742BCE289CB513EE08CB10C75E596199B2718350AC007F4D319` |
| Canonical/intake/build card | `FF5E60D3A1997DAA40D98FFDE4470ACB654F42EE1C3A52CD997A6F3A2CF54DFE` |
| MQ5 | `B63A95CA46B287848F65717B6D70479F65ABCECC458E85B75FF8B19DB156FFCC` |
| EX5 | `7B6578395293CC0BA5FC13996535B3B3B20D7EAAA07055BB7DE96219D3AAF62C` |
| SPEC | `AD8195B65564F930E87B85B6175B424F2EE3C47FDC33AD736663CC552FFC2F68` |
| Basket manifest | `31CB12714D36359DE67287C881073DC7D6BCECFF0CA6EDF5B24AE291927F5775` |
| Backtest set | `6E1E3074A0007D8A8C5CC806F9B8E44BAB6469B57DA611EC2F645C64C39D8577` |
| Reference test | `F49D7BC7A2DEA530B03C5E91607A3044455B0C4A83198068DB159BE6088C1DE3` |

## Q02 Capacity And Enqueue Evidence

Before enqueue, the queue held 1,048 pending and four active rows, below the
7,000-row ceiling. The scoped dry run selected exactly one fresh Q02 row for
`QM5_20291` and zero stranded rows. A path-anchored process snapshot found
four non-live factory terminals (`T4`, `T6`, `T7`, `T8`), below the seven-job
CPU ceiling. `T_Live` and FTMO processes were observed only so they could be
excluded; neither was controlled or modified.

The first apply attempt declined because the canonical factory mutation lock
was held by another scheduler. The lock was not altered. After it cleared,
the same scoped atomic command enqueued one row and no unrelated recovery
rows:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --apply \
  --ea QM5_20291 --queue-ceiling 7000 --max-part2-per-run 0
```

| Field | Value |
|---|---|
| Work item | `fbe16151-4f78-446d-a61f-a399f1c6659a` |
| Phase / kind | `Q02` / `backtest` |
| Logical symbol | `QM5_20291_XAU_XAG_HKURT_D1` |
| Host | `XAUUSD.DWX` / D1 |
| Basket symbols | `XAUUSD.DWX`, `XAGUSD.DWX` |
| Setfile | `C:/QM/repo/framework/EAs/QM5_20291_xauxag-kurt-rk/sets/QM5_20291_xauxag-kurt-rk_QM5_20291_XAU_XAG_HKURT_D1_D1_backtest.set` |
| Enqueued by | `claude_sweep_enqueue_2026-06-10.never_tested` |
| Track / scope | priority / basket |
| Status | pending at immediate readback |
| Attempt / claim / verdict | 0 / none / none |

The rolling enqueue receipt was
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`A051D9BDCC60674D2C581A2495C35C1606FFF13C4FAAB60263921B0A6772AF94`
at immediate readback. Because that receipt is shared and rolling, the durable
proof is the unique SQLite work-item row above.

## Scoped Commits Before Closing Evidence

- `b3cea2e2b` — durable G0 decision, bounded source packet, and synchronized
  approved/intake cards.
- `e74dbe469` — deterministic EA-ID reservation.
- `9f52676ff` — target SPEC scaffold.
- `3d03754b4` — two symbol-magics and generated resolver.
- `a3d92a447` — EA source, EX5, basket manifest, fixed-risk setfile, reference
  test, synchronized cards, and Q01 bindings.

All scoped staging remained on `agents/board-advisor`. Pre-existing and
concurrent unrelated working-tree changes were left untouched.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, `T_Live` file, or T_Live manifest
  was changed.
- The portfolio gate was not touched.
- No efficacy, certification, decorrelation, or portfolio-admission result is
  inferred from Q01 or the Q02 enqueue.

