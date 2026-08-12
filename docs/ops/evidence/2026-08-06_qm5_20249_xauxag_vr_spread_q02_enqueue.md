# QM5_20249 XAU/XAG Variance-Ratio Spread Build And Q02 Enqueue

Date: 2026-08-06 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; exactly one logical-basket Q02 item enqueued and initially
pending

## Outcome

One new structural, low-frequency precious-metals relative-value candidate was
researched, approved, allocated, built, strictly validated, and placed in the
paced Q02 queue:

- EA: `QM5_20249_xauxag-vr-spread`.
- Logical carrier: `QM5_20249_XAU_XAG_VRSPREAD_D1`, hosted on
  `XAUUSD.DWX` D1 and trading registered XAU and XAG legs.
- Mechanic: reconstruct 33 synchronized consecutive completed month ends,
  form 32 chronological XAU-minus-XAG log returns, and classify their memory
  with the locked heteroskedasticity-robust `q=2` variance ratio.
- Direction: follow the latest relative return under significant persistence,
  reverse it under significant anti-persistence, and stay flat when
  `abs(z) <= 1.64485362695147` or the latest relative return is zero.
- Risk: one `RISK_FIXED=1000` package, `RISK_PERCENT=0`, split equally by
  independent `3.5 * ATR(20,D1)` hard-stop risk across opposing legs.
- Lifecycle: one persisted attempt per broker month, close-before-renew at the
  next month boundary, 35-calendar-day stale guard, second-leg rollback, and
  immediate orphan or invalid-package repair.

The construction suppresses some common-direction precious-metal exposure but
does not prove dollar, beta, volatility, factor, market, or portfolio
neutrality. Q02 owns density and economics; the unchanged downstream
portfolio gate alone may establish realized decorrelation.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/CME-MEHLITZ-XAUXAG-VRSPREAD-2026/source.md`.

- Mehlitz and Auer (2024), *The European Journal of Finance* 30(8), 773-802,
  DOI `10.1080/1351847X.2023.2220118`, supply the 32-month robust `q=2`
  memory state, fixed two-sided 10% boundary, latest-return direction, and
  persistence / anti-persistence matrix. Their commodity universe includes
  gold and silver.
- CME Group supplies the opposing-leg gold/silver relative-value carrier and
  the economic distinction between the two metals.

Neither source tests a variance-ratio statistic on XAU-minus-XAG returns, the
Darwinex continuous CFDs, fixed cash risk, ATR stops, execution costs, or
portfolio decorrelation. This conjunction is a falsifiable QM adaptation, not
a transferred source result.

The deterministic pre-allocation checker scanned 4,306 registry rows and 423
pre-existing canonical cards. It returned `CLEAN` with no exact or fuzzy
match. Manual mechanic review separated the build from the existing
gold/silver ratio z-score, ratio breakout, D1 return-spread reversion, rolling
OLS, quantile, 12/18-month rank-disagreement, skew, expected-shortfall, jump,
and volatility-of-volatility candidates. The closest variance-ratio carrier
is an outright WTI strategy, not a synchronized two-leg relative series.

## Allocation And Commit Chain

- Source packet and durable G0 decision: `200b13a4d`.
- Initial canonical and approved cards: `9fd78981d`.
- EA-ID row, two magic rows, and regenerated resolver: `cfafb9a4c`.
- EA source, EX5, SPEC, basket manifest, colocated contract, fixed-risk
  setfile, and Q01 state: `b263cbce8`.

The magic allocation is `202490000` for XAU slot 0 and `202490001` for
XAG slot 1. Resolver regeneration retained 15,535 rows and dropped zero.

## Q01 Evidence

- Canonical and approved strategy-card schema lint: PASS; no missing sections
  or forbidden-model hits.
- G0 card lint: PASS.
- Approved and colocated execution-contract copies match the canonical card
  byte-for-byte.
- Exact slug, numeric EA ID 20249, active registry row, both active magic
  rows, EA directory, and resolver values were verified before compile.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260806_140506/QM5_20249_xauxag-vr-spread.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260806_140506/summary.csv`.
- Targeted V5 build check: PASS, zero failures and zero warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260806_140506.json`.
- Canonical set header build hash:
  `5868e2a4c5148d50fc587d3bffc1d9f53335f51ee298d2f72a84673e72cdfdd2`.
- EX5 size: 381,194 bytes.
- Manual smoke or backtest run: none.

Artifact SHA-256 values after the Q02 card-state update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `9BDC866A3A753D8BA2AEA5A719A0EF5C6C8FCC4A22B053C902C68FFBFCA077F6` |
| G0 decision | `0BAFBA4A4A043A7C7F69D30C9328A9F00BF7C3768D68E6A4CC77E3943F25F5EE` |
| Canonical/approved/build card | `B00F495F7866738D6B0F163F3AD6BD142BE0C75E537ED555B406851A2A168685` |
| MQ5 | `5868E2A4C5148D50FC587D3BFFC1D9F53335F51EE298D2F72A84673E72CDFDD2` |
| EX5 | `0AC0E710791C8263F7803E0DC58E81613BC49FDDA10FC5709BD318559CF4D6F7` |
| SPEC | `3412E726AF05C972898328EE3E5B7E4C2F368887B5058BD0300B833AB647420A` |
| Basket manifest | `CF7EBA9F29FC64A34CAB27711E518311A42E5851941A4EC16A396200E9B07316` |
| Backtest set | `1DEF36E4E1FDE237DBED80D72F3245F4A22753295A16D08CB26606DC98A8CD9E` |

## Q02 Capacity And Queue Evidence

Only executable paths matching
`D:/QM/mt5/T1..T10/terminal64.exe` were counted. `T_Live`, FTMO, and every
other namespace were excluded.

- `2026-08-06T14:06:36Z`: five exact factory terminals; below the binding
  seven-terminal ceiling.
- Targeted no-mutation dry run selected exactly one `never_tested`,
  priority-track logical-basket row, with zero skips and zero stranded or
  deferred rows.
- `2026-08-06T14:08:27Z`: six exact factory terminals immediately before
  the first apply attempt; below the ceiling. That attempt safely skipped
  because `FACTORY_MUTATION.lock` was held.
- The lock was never deleted, modified, bypassed, or reaped. Guarded retries
  continued to sample five exact factory terminals and remained fail-closed
  until normal lock acquisition succeeded.
- Apply evidence:
  `D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, generated at
  `2026-08-06T14:12:12Z`, records target EA `QM5_20249`, target logical
  symbol `QM5_20249_XAU_XAG_VRSPREAD_D1`, exactly one priority row, zero
  skips, and zero part-2 or part-3 rows.
- Canonical post-apply query initially showed exactly one work item:
  `c3b593c4-8d79-437a-a9c0-ed73c9ebcd51`, phase `Q02`, status `pending`,
  attempt count `0`, unclaimed, created at
  `2026-08-06T14:12:12Z`.

No dispatch tick, worker claim, terminal reservation, or tester launch was
performed by this work session. Normal paced workers own Q02 execution and
the hard floor of at least five completed packages per full post-warm-up
year.

## Safety Boundary

- No manual backtest, smoke run, dispatch tick, downstream phase, terminal
  reservation, or terminal-control action was run.
- No terminal process was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled.
- The portfolio gate, `T_Live` manifest, deploy manifests, and all unrelated
  working-tree changes were untouched.
