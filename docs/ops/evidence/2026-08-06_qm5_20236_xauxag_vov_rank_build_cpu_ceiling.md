# QM5_20236 XAU/XAG Realized-VoV Build And CPU-Ceiling Handoff

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; Q02 eligible but not enqueued because the CPU ceiling was
already exceeded

## Outcome

One new structural, low-frequency commodity basket was researched, approved,
allocated, built, committed, and strictly validated:

- EA: `QM5_20236_xauxag-vov-rank`.
- Logical carrier: `QM5_20236_XAU_XAG_VOV_D1`, hosted on `XAUUSD.DWX` D1 and
  trading registered XAU and XAG legs.
- Mechanic: at each broker-month transition, construct 252 overlapping
  realized-volatility observations per metal, each from 20 completed D1 log
  returns. Buy the lower realized-VoV metal and short the higher one.
- Lifecycle: monthly close and rerank, 40-day stale guard, persistent consumed
  attempt before history/signal/order gates, deal-history guard, orphan repair,
  and second-leg rollback.
- Risk: one `RISK_FIXED=1000` package split into equal stop-risk halves, with
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and `3.5 * ATR(20,D1)` hard stops.

No Q02 row was inserted. The targeted dry run selected exactly one priority
item, but the mandatory binding scan found nine active factory terminals
against the ceiling of seven. Per the mission stop condition, the apply step
was not run.

## Source And Non-Duplicate Boundary

The governed source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies
in Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The durable packet is
`strategy-seeds/sources/HOLLSTEIN-VOV-2021/source.md`, and the carrier approval
is `decisions/2026-08-06_qm5_20236_xauxag_vov_rank_g0.md`.

The source signal uses option-implied volatility. The EA openly substitutes a
price-native nested realized-VoV estimator because no commodity option chain
is available at runtime. The paper ranks a broad futures universe and does not
test this two-metal CFD package. No source return, significance, cost,
correlation, or risk statistic transfers.

The deterministic pre-allocation check found no exact identity across 4,293
registry rows and 409 pre-existing cards. The expected same-method sibling is
`QM5_13146_energy-vov`; it uses the locked estimator on XTI/XNG, reached Q07,
and failed Q08. That adverse result is disclosed rather than optimized around.
The new carrier remains different from existing XAU/XAG ratio, OLS, skew,
signed-semivariance, expected-shortfall, idiosyncratic-volatility, momentum,
calendar, shock, and cumulative-RSI logic.

## Allocation And Commit Chain

- Source packet and durable G0 decision: `d0054a3c0`.
- Canonical card, EA-ID row, both magic rows, and regenerated resolver:
  `608b13e32`.
- EA source/binary, SPEC, basket manifest, card copies, and fixed-risk setfile:
  `1fc743eaf`.

The magic allocation is `202360000` for XAU slot 0 and `202360001` for XAG
slot 1.

## Q01 Evidence

- Strategy-card schema lint: PASS.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260806_013254/QM5_20236_xauxag-vov-rank.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_013254/summary.csv`.
- Full V5 build check: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260806_013327.json`.
- EX5 size: 375,588 bytes.

Artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| Source packet | `F54F17F2DCDA40000D939D2D89122F4EA3F305293018AFF331A6C018F3DBDD00` |
| G0 decision | `166926A6BB5C0BB6C11408D07E076E71B55BC127D21A27AC60639619A90D3D74` |
| Canonical/approved/build card | `4B6BD4AF16109AEB7475C625154C87BB8F7286ACD401F78C71E1F7C9ACD9E57C` |
| MQ5 | `682E9EDC0C1A224FAAA3BCBF3CB7EB9E45FD54D5393606525042EC15B3E32620` |
| EX5 | `D14E205561C95898917109D4BB73644829F2C15E0419699D17F4C76C251C6D96` |
| SPEC | `A214A57E48F3A9E2CAF113D9958D7A862AC04CACF2A1A71A2496E6BEE1411385` |
| Basket manifest | `B84F1DDAD91D215B783868599FA55C3EBD001C1B23FC2648FE10A81BF563E25A` |
| Backtest set | `4545D008BD6EAFE9117B38FC11FE41E3BD1CE0C63A18548A85D359157BBF4706` |

## Q02 Dry Run And CPU-Ceiling Evidence

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20236 --symbols QM5_20236_XAU_XAG_VOV_D1 --max-part2-per-run 0

It selected one `never_tested` priority item and no stranded/recovery item.
The generated dry-run record is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`. A read-only SQLite
snapshot found zero existing `QM5_20236` work items, 1,514 pending rows, and
10 active rows against the separate 7,000-row queue ceiling.

At `2026-08-06T01:35:03Z`, `farmctl.py mt5-slots` found nine active factory
terminals: T1, T2, T4, T5, T6, T7, T8, T9, and T10. The scan separately saw
T_Live and an FTMO terminal, neither of which was counted as a factory slot.
Nine exceeds the binding CPU ceiling of seven, so `--apply` was not run. No
work-item ID exists and no manual dispatch occurred.

## Safety Boundary

- No manual backtest, dispatch tick, terminal reservation, tester launch, or
  process mutation was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- Existing unrelated working-tree changes were preserved and excluded from
  every task commit.
