# FX cointegration GBPUSD/USDJPY — serialized basket-lane stop

Date: 2026-08-16 Europe/Berlin (`2026-08-16T08:52:32Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; exact non-duplicate fallback is
repaired and pending once at Q02; another path-bound basket owns the one
farm-wide multisymbol lane

## Outcome

No duplicate Card, EA, registry row, manifest, setfile, or Q02 row was created.
The frozen 66-pair scan remains fully mechanized: all 25 approved Card
filenames containing `coint` or `cointegration` resolve to matching EA
directories.

The two preferred anchors remain beyond Q02 and have no open `ONINIT` or
`NO_HISTORY` repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The governed fallback remains frozen-scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, implemented as slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. Its repaired logical-basket Q02 row remains
pending exactly once, so a second enqueue or append-only rerun would be
duplicate work.

## Exact fallback state

| Field | Value |
| --- | --- |
| Work item | `d4cd660c-c81a-41d3-8a4c-ad21d3319816` |
| Logical symbol | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Phase | Q02 |
| Status | `pending`, unclaimed |
| Attempt count | 2 |
| Verdict / evidence | none / none |
| Exact identity rows / open rows | 1 / 1 |
| Last queue refresh | `2026-08-15T13:03:04.898529Z` |

Fresh SHA-256 reads match the queue bindings:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest:
  `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- logical backtest setfile:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

The manifest binds `GBPUSD.DWX` and `USDJPY.DWX` with `GBPUSD.DWX` H1 as
host. The preset remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The OWNER-approved Card retains R1-R4 PASS and cites
Lemishko, Landi, and Caicedo-Llano (2024), SSRN 4771108. Its frozen-OLS
residual-reversion mechanics are structural and contain no ML, grid,
martingale, adaptive intramonth refit, or banned indicator.

The prior zero-trade run is bound at
`D:/QM/reports/work_items/d4cd660c-c81a-41d3-8a4c-ad21d3319816/QM5_1257/20260815_082908/summary.json`.
The same-lineage entry repair (`751cb391d8`), reachable-exit repair
(`f9ef37c1c`), and set metadata restoration (`82a1bf443`) are resident in the
hashes above. Focused regression validation passed:

```text
python -m pytest -q tools/strategy_farm/tests/test_fx_basket_manifests.py -k qm5_1257
2 passed, 43 deselected
```

## Binding backtest ceiling

The canonical database reported four active work items. Its one allowed
farm-wide multisymbol working set is currently owned by:

- work item `92235bb9-1fc0-4aeb-90c3-f8771ca9e2bd`;
- `QM5_20233_XAU_XAG_SKEW_RANK_D1` at Q02, claimed by T8;
- declared legs `XAUUSD.DWX` and `XAGUSD.DWX`;
- runner PID 17136 and terminal PID 1628; and
- tester configuration
  `D:/QM/reports/work_items/92235bb9-1fc0-4aeb-90c3-f8771ca9e2bd/QM5_20233/20260816_043334/raw/run_01/tester.ini`.

The exact process chain is live and the runner carries the repaired 25,200
second timeout, so this is not a stale database claim. `T_Live` and the FTMO
terminal were observed only to exclude them and were not controlled.

Three two-second CPU samples were 45%, 67%, and 71%, averaging 61%. The prior
98.02% hard CPU trip has cleared; free physical memory is 26.37 GiB and D: has
154.81 GiB free. The binding ceiling is now the single serialized multisymbol
lane, not CPU, RAM, or disk. Launching the FX basket concurrently would violate
the paced-fleet contract, so no manual dispatch or tester start was attempted.

## Non-duplicate delta

The preceding committed sample had a 98.02% CPU hard trip and
`QM5_20236_XAU_XAG_VOV_D1` owned the basket lane. CPU has recovered to 61%
average and that owner completed, demonstrating fleet progress. A different
path-bound basket, `QM5_20233_XAU_XAG_SKEW_RANK_D1`, now owns the serialized
lane while the repaired FX row remains ready and pending exactly once. This is
a materially new lane-ownership state, not a repeat queue snapshot.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_serialized_lane_stop_20260816T085232Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, Card, EA, registry,
setfile, basket manifest, external queue row, factory process, or running
terminal was changed. Concurrent unrelated worktree changes were left
unstaged and untouched.
