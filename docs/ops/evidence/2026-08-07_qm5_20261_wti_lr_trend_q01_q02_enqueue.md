# QM5_20261 WTI Linear-Trend Quality Q01 And Q02 Enqueue

Date: 2026-08-07 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20261_wti-lr-trend` is built and Q01 is `PASS`. Q02 is
`ENQUEUED`: work item `1ddcb021-2d49-4829-aca8-ccf2b1b49e3d` was read back as
pending, unclaimed, and attempt 0 for `XTIUSD.DWX` immediately after the
single successful apply-mode enqueue. No dispatch command or manual backtest
was run.

## Edge And Non-Duplicate Boundary

At the first processed WTI D1 bar of a genuine new broker month, the EA
reconstructs thirteen consecutive completed month-end closes, ordered oldest
to newest. It fits `ln(close)` to the fixed index `0..12` and trades the slope
sign only when the regression has finite, nondegenerate sums,
`abs(beta) > 1e-10`, and `R2 >= 0.50`. A weak, flat, malformed, nonconsecutive,
or stale path consumes the month flat.

One position receives a frozen `3.5*ATR(20,D1)` hard stop and no take-profit.
The package renews at the next broker month, with a forty-calendar-day stale
guard. The month attempt is persisted before history, signal, news, spread,
quote, sizing, or order gates, so a rejection or stop cannot retry in-month.

The deterministic pre-allocation checker scanned 4,318 EA-registry rows and
435 cards, found no exact slug or strategy-ID collision, and returned five
expected fuzzy source/trend neighbors. Manual review resolved the closest WTI
systems:

- `QM5_12603_wti-tsmom12m` uses a single endpoint return;
- `QM5_20056_wti-dual-mom` and `QM5_20258_wti-mom-vote` combine cumulative
  return horizons;
- `QM5_13150_wti-signmom` and `QM5_20244_wti-trend-sign` use monthly return
  signs rather than regression residual dispersion; and
- WTI moving-average, channel, variance-ratio, calendar, event, and basket
  EAs use different state variables or clocks.

A content scan found no existing WTI card requiring both oldest-to-newest
log-price OLS slope and a fixed regression-fit gate. The thirteen endpoints,
orientation, slope sign, `R2 >= 0.50`, consumed attempt, and monthly renewal
are jointly load-bearing. Direct WTI supplies a new energy carrier relative to
the certified XAU, SP500, NDX, and XNG book. Realized decorrelation is not
claimed; Q09 alone may measure it if every preceding gate passes.

## Source And G0 Record

The tier-A source is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete governed review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded WTI extraction
is `strategy-seeds/sources/MOP-WTI-LRTREND-2026/source.md`.

The paper supplies explicit WTI membership and monthly own-price continuation
through twelve lags. It does not supply the OLS path or `R2` gate. Those rules,
the CFD endpoint reconstruction, fixed cash risk, ATR stop, spread cap, and
lifecycle controls are transparent QM hypotheses. No source profitability,
density, CFD basis, or portfolio-correlation result transfers.

G0 authorization is
`decisions/2026-08-07_qm5_20261_wti_lr_trend_g0.md`. The authorization is
commit `80780058f`, source/card approval `4a7374035`, deterministic EA-ID
reservation `de02f7fb9`, magic allocation `48e2f615b`, initial build
`2a24731a9`, and committed-resolver binary binding `d52639eb2`.

## Deterministic Allocation And Q01 Evidence

- EA ID/slug: `QM5_20261` / `wti-lr-trend`.
- Strategy ID: `MOP-TSMOM-2012_XTI_LR12R2_S14`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202610000`.
- Committed registry/resolver CSV identity:
  `F5D04A74D933E978B08381EBDE9028161854B6B2D376244F43BB0882571F870A`.
- Card schema/ML lint: PASS on canonical, intake, and build cards; no missing
  sections or ML hits.
- Build prerequisite guard: PASS for EA registry, magic row, and EA directory.
- SPEC validation: PASS, one target and zero failures.
- Build guardrails: PASS with no findings.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- Strict target-scoped build gate:
  `D:/QM/reports/framework/21/build_check_20260807_073248.json` (`PASS`,
  strict mode, 0 failures, 0 warnings).
- The gate's compiler invocation:
  `D:/QM/reports/compile/20260807_073248/summary.csv` (`PASS`, 0 errors,
  0 warnings).
- Compile log:
  `C:/QM/repo/framework/build/compile/20260807_073248/QM5_20261_wti-lr-trend.compile.log`.
- EX5 size: 380,566 bytes.
- Setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; generated header build hash
  `3c4e604de898b069e0cf255cf7ca3945f8ddf1f59489525cd9255d4f62b8861b`.
- Manual smoke/backtest: none.

Artifact SHA-256 values after the Q01/Q02 card-status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `7D29036021DA73C0AC529AAAC5E6A791FC124F868B65F0FBB9F40D9FD1012571` |
| Canonical/build card | `53AFB7B79A9C201CB372B3AFB3018BD3F52B40280D2058A7B6B406DB8FE175D8` |
| Intake pointer card | `37BBAE359B3297F0B44F3FB10E4A779DDA8D4756546A66AAFDE1EC078F65E48E` |
| MQ5 | `4F871939C17A110F5F6207ECEE1C7A8008CB4F9913E7D4AFE12E5BCE5428EB2D` |
| EX5 | `811C13F76B54265CEF60D8DA76AF0310AFB22EC3C1537DD87467429794E0F62F` |
| SPEC | `CAC9C61EBF6966695109A33290AED1F0CF4048AF7A69192EB796BB83CB494664` |
| Backtest set | `5DDF3E3A1C1D9E0968D21AEC8129A6F7E42E0B06393E66C784FF0D5BDF43D81F` |

## Q02 Capacity And Enqueue

`farmctl mt5-slots` sampled governed processes at
`2026-08-07T07:34:27+00:00` and found six active factory terminals against the
paced ceiling of seven:

| Terminal | PID | Active phase/context |
|---|---:|---|
| T1 | 8648 | Q02, `QM5_12577` |
| T3 | 20344 | governed Q09 live-news backfill cell |
| T4 | 6488 | Q02, `QM5_12538` |
| T5 | 5268 | Q02, `QM5_12538` |
| T8 | 16548 | Q02, `QM5_12538` |
| T9 | 4108 | Q09_NEWS, `QM5_11422` |

Only governed factory terminals count toward the paced ceiling. The separate
`C:/QM/mt5/T_Live` and FTMO processes were observed by the read-only sample
but excluded and were not accessed or changed. With governed load at 6/7, the
EA-and-symbol-scoped dry run selected one never-tested item, zero stranded
retries, and zero deferred promotions.

The first apply attempts made no mutation while the factory mutation lock was
held. A bounded idempotent retry acquired the lock and reported exactly one
Q02 enqueue. Immediate readback recorded:

- work item: `1ddcb021-2d49-4829-aca8-ccf2b1b49e3d`;
- phase/kind: `Q02` / `backtest`;
- symbol: `XTIUSD.DWX`;
- status: `pending`;
- attempt count: 0;
- claimed by: null;
- created: `2026-08-07T07:37:17+00:00`.

This is an enqueue handoff, not a Q02 screening verdict.

## Safety Boundary

- No dispatch tick, manual backtest, smoke test, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading and `T_Live` were not touched.
- The portfolio gate and T_Live manifest were not touched.
- Concurrent unrelated EA builds and their uncommitted registry activation
  were preserved outside the QM5_20261 commits.
