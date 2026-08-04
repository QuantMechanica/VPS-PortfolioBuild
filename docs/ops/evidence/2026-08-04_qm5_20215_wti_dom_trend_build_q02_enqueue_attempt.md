# QM5_20215 WTI Day-of-Month Trend Build And Q02 Enqueue Attempt

Date: 2026-08-04 (Europe/Berlin)

Branch: agents/board-advisor

## Outcome

One new structural, low-frequency energy candidate was researched, approved,
allocated, implemented, strictly validated, and committed:

- EA: QM5_20215_wti-dom-trend.
- Carrier: XTIUSD.DWX, D1, slot 0, magic 202150000.
- Mechanic: exact broker day 1 BUY only with positive completed 252-D1
  return; exact broker day 26 SELL only with negative completed 252-D1
  return; first-following-D1 exit.
- Missing exact dates never shift.
- Q01: PASS with zero final compile errors/warnings and zero build-check
  failures/warnings.
- Backtest set: RISK_FIXED=1000, RISK_PERCENT=0, and
  PORTFOLIO_WEIGHT=1.

Q02 was not inserted. The exact dry run selected one priority-track row, but
every guarded apply observed the live global factory mutation lock and
returned a no-op. A final read-only database check found zero QM5_20215 work
items. The card therefore remains q02_status NOT_STARTED; no queue success or
pipeline verdict is claimed.

## Source And Non-Duplicate Boundary

The governed packet is
strategy-seeds/sources/BOROWSKI-MOP-WTI-DOMTREND-2026/source.md. It preserves
complete repository reviews of:

- Borowski (2016), Journal of Management and Financial Sciences 26, 27-44,
  for WTI numbered-day effects; and
- Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2),
  228-250, for the sign of an instrument's own completed 12-month return.

The source reports a significant negative day-26 WTI effect in its sample,
but its positive day-1 mean is not statistically significant. Multiple
testing, source-sample decay, and futures-to-continuous-CFD basis are explicit
kill risks. Neither paper tests the conjunction or transfers performance,
cost, drawdown, correlation, or portfolio evidence.

The deterministic pre-allocation check scanned 4,272 registry rows and 389
cards and returned CLEAN with no fuzzy match above threshold. Manual review
separates this interaction from:

- QM5_20028, unconditional exact-day-1 WTI long;
- QM5_20027, unconditional exact-day-26 WTI short;
- QM5_12603, year-round monthly WTI 12-month trend;
- QM5_20136, same-calendar-month plus 63-D1 monthly WTI trend;
- QM5_20172, Friday WTI behavior; and
- QM5_12567, a two-day commodity oscillator pullback.

The exact dates, opposite directional maps, completed 252-D1 agreement, and
one-session lifecycle are jointly load-bearing. The G0 authorization is
decisions/2026-08-04_qm5_20215_wti_dom_trend_g0.md.

## Commits And Allocation

- Source packet, G0 decision, and card: 94e400f6c.
- Registry row, magic row, resolver, and initial generated artifacts:
  666595df9.
- Final EA, binary, SPEC, approved/build card references, and fixed-risk set:
  82fe1191f.
- EA registry: 20215,wti-dom-trend.
- Magic registry: XTIUSD.DWX slot 0, magic 202150000.
- Generated resolver verification: one EA row, one magic row, and the
  202150000 mapping present.
- Resolver tests: 4 passed.

The shared paced-fleet artifact pump created commit 666595df9 while the build
was in progress; it captured exactly the new registry/magic/resolver and
initial generated-artifact paths. The final successful binary and set hash
were committed explicitly in 82fe1191f.

## Q01 Evidence

- Strategy-card schema lint: PASS for canonical and approved copies; no
  missing sections or forbidden-library hits.
- Seven-section SPEC validation: PASS.
- Symbol-scope validation: SINGLE_SYMBOL_OK, zero violations.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile summary:
  D:/QM/reports/compile/20260804_201459/summary.csv.
- Compile log:
  C:/QM/repo/framework/build/compile/20260804_201459/QM5_20215_wti-dom-trend.compile.log.
- Strict V5 build check: PASS, 0 failures and 0 warnings:
  D:/QM/reports/framework/21/build_check_20260804_201459.json.
- The first compile exposed two incorrectly escaped diagnostic JSON strings;
  those strings were repaired before the successful compile and before the
  final build commit.

Artifact SHA-256 values after the successful build:

| Artifact | SHA-256 |
|---|---|
| Source packet | 2A70D06598B6F89E0D265DD821816DD2DAB3B2923CEDB2F2C860C9F40FB4A4DD |
| MQ5 | 01B7DDDA829E2A8D521D76D749C4DD44137B8B4FAC0A9FE5DE37C2B95BC0D245 |
| EX5 | 6BBCC426E17E5DEF1D1C41EC9636F2A46C98BF5744DC1964A81C94CD80F78503 |
| SPEC | 6D8ACE4613B6709531A166BDEB0E865A63B122EE6BDCD294D329F364F512D7D2 |
| Approved card | 487FB8CB7BE719B2FF3FCC51E8939826F64629CF7DFD64D9781B14A27F66107A |
| Backtest set | 7FAF24FE2B18495ADB125451FBE31605FBDCE2057EBC7C6253A8853D4C6B4A96 |

## Q02 Dry Run And Blocked Apply

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20215 --symbols XTIUSD.DWX --max-part2-per-run 0

It reported:

- part1 never_tested: enqueued 1, skipped 0;
- part2 stranded: enqueued 0, skipped 0;
- deferred promoted: 0;
- priority-track items: 1.

The guarded apply used the identical scope plus --apply. Repeated bounded
attempts across the observation interval all returned:

    {"skipped":"factory mutation lock busy","lock":"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock"}

No attempt deleted, renamed, reaped, or bypassed the lock. No direct SQLite
write was used. Read-only query-only SQLite checks confirmed zero QM5_20215
work items after the final attempt.

The initial process scan counted five active factory terminals
(T1, T2, T3, T5, T6); later scans counted four or five as work rotated. The
final scan counted four (T10, T2, T5, T6), below the seven-terminal CPU
ceiling. No terminal was started, stopped, reserved, or altered.

## Safety And Deviation Note

- No manual backtest or downstream phase was launched.
- No live/demo/shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not changed.
- No T_Live terminal, setting, file, or manifest was intentionally opened by
  the build or enqueue workflow.
- During lock diagnosis, one read-only global farmctl health command was
  invoked. That broad diagnostic includes a T_Live kill-switch-baseline
  health check and surfaced live-status metadata. It made no mutation, but it
  exceeded the requested no-T_Live read boundary; no further broad health
  command was used.
- Q02 dry-run selection is not an enqueue, certification, profitability
  result, decorrelation result, or portfolio admission.
