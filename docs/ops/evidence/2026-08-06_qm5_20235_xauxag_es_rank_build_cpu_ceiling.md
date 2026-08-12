# QM5_20235 XAU/XAG Expected-Shortfall Build And CPU-Ceiling Handoff

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; Q02 eligible but not enqueued because the CPU ceiling was
already exceeded

## Outcome

One new structural, low-frequency commodity basket was researched, approved,
allocated, built, committed, and strictly validated:

- EA: `QM5_20235_xauxag-es-rank`.
- Logical carrier: `QM5_20235_XAU_XAG_ES_D1`, hosted on `XAUUSD.DWX` D1 and
  trading registered XAU and XAG legs.
- Mechanic: at each broker-month transition, reconstruct synchronized returns
  ending inside exactly the prior twelve completed months. Average each
  metal's worst five percent, buy the higher expected-shortfall statistic (the
  less negative lower tail), and short the lower statistic.
- Lifecycle: monthly close and rerank, 40-day stale guard, persistent attempt
  state written before entry gates, same-month deal guard, orphan cleanup, and
  second-leg rollback.
- Risk: one `RISK_FIXED=1000` package split into equal stop-risk halves, with
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and `3.5 * ATR(20,D1)` hard stops.

No Q02 row was inserted. The targeted dry run selected exactly one priority
item, but the mandatory binding scan found eight active factory terminals
against the ceiling of seven. Per the mission stop condition, the apply step
was not run.

## Source And Non-Duplicate Boundary

The governed source is Qin, Cai, Zhu, and Webb (2025), "Commodity Futures
Characteristics and Asset Pricing Models," *Journal of Futures Markets*
45(3), 176-207, DOI `10.1002/fut.22559`. The durable packet is
`strategy-seeds/sources/YIYI-ES-2025/source.md`, and the carrier approval is
`decisions/2026-08-06_qm5_20235_xauxag_es_rank_g0.md`. The public-paper route
was policy-deferred, so no new web claim was introduced; the build relies on
the existing complete-read packet.

The paper ranks a broad commodity-futures universe and does not test this
two-metal CFD package. Its broad one-way evidence is weak. No paper or sibling
return, significance, cost, correlation, or risk statistic transfers.

The deterministic pre-allocation check found no exact identity across 4,292
registry rows and 408 cards. Its expected fuzzy match is
`QM5_13143_energy-es-rank`, the same locked estimator on XTI/XNG. Manual review
classifies this work as a carrier extension, not a parameter sweep. It remains
different from existing XAU/XAG ratio, OLS, skew, RSJ, return-reversal,
momentum, calendar, idiosyncratic-volatility, shock, and cumulative-RSI logic.

## Allocation And Commit Chain

- Source packet and durable G0 decision: `7ddceff40`.
- Canonical card, EA-ID row, and both magic rows: `01688e917`.
- EA source/binary, SPEC, basket manifest, card copies, and fixed-risk setfile:
  `9639113b9`.

The magic allocation is `202350000` for XAU slot 0 and `202350001` for XAG
slot 1.

## Q01 Evidence

- Strategy-card schema lint: PASS.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260806_003832/QM5_20235_xauxag-es-rank.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_003832/summary.csv`.
- Full V5 build check: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260806_003909.json`.
- EX5 size: 375,876 bytes.

Artifact SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| Source packet | `AC00A311DCA3BDB3C1BF47725EAB1887BC0335ADE84E898F4DBD8117C3A36FE9` |
| G0 decision | `1101957F8CD084D3FB3CAB10921BAE67AD17CAB3EA99B301747A4A59FABC644A` |
| Canonical/approved/build card | `D027BEB621181EC4B32769084B158356DA901B0D284E4501247E79B64D2CDDB2` |
| MQ5 | `113533FD8EC4C4FEEBCBBD0A4196B8E0D31469AF9EA7ACEAFFA796C20FD8A0DC` |
| EX5 | `A3226CC5B57B714B6EBFF23B03BA0DE395EE37BAAABAF076858F458D773DC805` |
| SPEC | `91104DCCADFCC2E3ACB59FAB1AA98062A1276045BA92CAC6A051BE370024AE11` |
| Basket manifest | `412C4ED47586F40EBD94D5BC6BE0A73DC48F76B796AC022E4B3ECA7DFC511A4C` |
| Backtest set | `5D3F0D6A1E97AD8876E7022BFA5FA629A7F021D073F9204C4EEFB29931DEF28D` |

## Q02 Dry Run And CPU-Ceiling Evidence

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20235 --symbols QM5_20235_XAU_XAG_ES_D1 --max-part2-per-run 0

It selected one `never_tested` priority item and no stranded/recovery item. A
read-only SQLite snapshot found zero existing `QM5_20235` work items, 1,518
pending rows, and nine active rows against the separate 7,000-row queue
ceiling.

At `2026-08-06T00:42:51.4426809Z`, a read-only process scan anchored exactly
to `D:/QM/mt5/T1..T10/terminal64.exe` and excluding `T_Live` found eight active
factory terminals: T1, T2, T3, T5, T6, T8, T9, and T10. Eight is at or above
the binding CPU ceiling of seven, so `--apply` was not run. No work-item ID
exists and no manual dispatch occurred.

## Safety Boundary

- No manual backtest, dispatch tick, terminal reservation, or tester launch
  was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- Existing unrelated working-tree changes were preserved and excluded from
  every task commit.
