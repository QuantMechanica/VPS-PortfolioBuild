# FX cointegration GBPUSD/USDJPY — hard CPU-ceiling stop

Date: 2026-08-16 Europe/Berlin (`2026-08-15T23:19:52Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; exact non-duplicate fallback remains
pending once at Q02; live basket ownership and the hard CPU ceiling block launch

## Outcome

No duplicate Card, EA, registry row, manifest, setfile, or Q02 row was created.
The frozen sign-aware 66-pair scan remains fully mechanized. A fresh approved-
Card reconciliation found 25 filenames containing `coint` or `cointegration`,
with a matching EA directory for every parsed EA ID.

The two preferred anchors remain beyond Q02 and have no open `ONINIT` or
`NO_HISTORY` repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The sole governed fallback is frozen-scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, implemented as pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. Its exact Q02 row remains pending once, so
enqueueing or requeueing it would be duplicate work.

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
| Last update | `2026-08-15T13:03:04.898529Z` |

Fresh SHA-256 reads still match all queue bindings:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest:
  `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- logical backtest setfile:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

The manifest binds `GBPUSD.DWX` and `USDJPY.DWX` with `GBPUSD.DWX` H1 as
host. The backtest preset remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The OWNER-approved Card retains R1-R4 PASS and cites
Lemishko, Landi, and Caicedo-Llano (2024), SSRN 4771108. Its frozen-OLS
residual-reversion mechanics are structural and contain no ML, grid,
martingale, adaptive refit, or banned indicator.

## Binding backtest ceiling

The canonical database reported seven active work items. Its one allowed
farm-wide multisymbol working set remains owned by:

- work item `c21cab69-2e64-44b6-bc67-4e7db3e5befd`;
- `QM5_20236_XAU_XAG_VOV_D1` at Q02, claimed by T8;
- declared legs `XAUUSD.DWX` and `XAGUSD.DWX`;
- path-bound terminal PID 4800 and tester PID 8884; and
- tester configuration
  `D:/QM/reports/work_items/c21cab69-2e64-44b6-bc67-4e7db3e5befd/QM5_20236/20260815_214424/raw/run_01/tester.ini`.

The live path binding proves that the basket-lane owner is not a stale database
claim. `T_Live` and the FTMO terminal were observed only to exclude them and
were not controlled.

Three two-second CPU samples were 94.85%, 99.90%, and 99.32%, averaging
**98.02%**, above the governed 97% hard trip. Free physical memory was 21.05
GiB and D: had 181.69 GiB free. Both the hard CPU trip and the already occupied
serialized basket lane bind. Per the mission stop rule, no compile, dispatch
tick, tester launch, enqueue, requeue, terminal reservation/control, or policy
bypass was attempted.

## Non-duplicate delta

The preceding committed sample averaged 70.67% CPU and therefore had soft
resource headroom. This sample crossed the 97% hard ceiling at 98.02%. The same
T8 basket remains live, while five of the six other active work-item identities
changed, demonstrating farm progress without target duplication or artifact
drift. The durable hard-ceiling handoff is the scoped contribution for this
pass.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_hard_cpu_ceiling_stop_20260815T231952Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, Card, EA, registry,
setfile, basket manifest, external queue row, factory process, or running
terminal was changed. Concurrent unrelated worktree changes were left unstaged
and untouched.
