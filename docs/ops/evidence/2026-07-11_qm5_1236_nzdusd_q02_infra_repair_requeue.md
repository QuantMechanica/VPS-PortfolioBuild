# QM5_1236 NZDUSD Q02 Infrastructure Recovery

## Outcome

`QM5_1236_gh-donchian-55` is now current-framework clean and its existing
`NZDUSD.DWX` D1 Q02 row is pending again. The repair preserves the approved
completed-bar 55-day Donchian entry, 20-day channel exit, ATR filter, and hard
stop. No new work-item row or manual backtest was created.

## Selection And Claim

No faithful priority-1 build was available. The three pending build tasks were
an unavailable lumber proxy, an unavailable rates/bonds strategy, and a
high-frequency XAU/NDX scalper. The priority-2 diverse-instrument lane was used.

- Farm claim: `agent_tasks.id=82fc6aa5-5a27-4c28-b4c4-970283480b4a`.
- Target: `QM5_1236`, `NZDUSD.DWX`, D1, Q02.
- Card: `APPROVED`, R1-R4 PASS, estimated 18 trades/year/symbol.
- Rule family: structural 55/20 Donchian trend following with ATR risk; no ML,
  grid, martingale, or pyramiding.
- Collision guard: no competing active claim, open Q02-Q03 work, strategy
  verdict, or downstream row existed for this EA.

## Diagnosis

The pre-write DB backup contains 144 Q02 rows for the EA: all 144 are
`INFRA_FAIL`, none is a strategy verdict, and none was open. The selected
NZDUSD row repeatedly ended as `summary_missing_retries_exhausted`.

The package had four concrete current-gate defects:

1. The checked-in `.ex5` came from commit `586d0c099` on June 21 and predated
   20 current framework includes.
2. The first strict build check found eight forbidden raw `iHigh`, `iLow`,
   `iTime`, `iClose`, and `Bars` calls.
3. D1 channel management and exit series work ran on every tick, retaining a
   reportless timeout risk despite the completed-bar strategy definition.
4. Its spread-history guard had the `.DWX` zero-spread warning shape.
5. `SPEC.md` was absent, and all 12 backtest setfiles omitted `qm_ea_id`,
   explicit strategy parameters, and the approved-card defaults source.

## Repair And Validation

Raw series reads were replaced with `QM_ReadBar`; channel lengths, completed-bar
indexing, filters, entries, exits, and sizing were not changed. Zero/unavailable
modeled spread now remains tradeable, while genuinely wide positive spread is
still filtered. D1 management, exit, and entry evaluation now runs behind
`QM_IsNewBar`, with news gating applied to entries only. The missing spec was
added and all declared-symbol setfiles were regenerated with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

| Check | Result |
|---|---|
| SPEC validation | PASS |
| Build guardrails | PASS, zero findings |
| Symbol scope | `SINGLE_SYMBOL_OK`, zero violations |
| Strict compile | PASS, 0 errors, 0 warnings |
| Compile log | `C:/QM/repo/framework/build/compile/20260711_053101/QM5_1236_gh-donchian-55.compile.log` |
| Build check | PASS, 0 failures, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260711_052837.json` |
| Old `.ex5` SHA256 | `B0549B9841102CBBA595D1FD553DE93C57C38FF7370326B6CF3AFC2097CC9266` |
| New `.ex5` SHA256 | `3D161D442DBD8B9087E0AD46106EAD9E0BA0ABD5C522F9373A4AD7BC73583690` |

## Q02 Handoff

The existing row was reset in place under an atomic state guard:

| Symbol | Work item | State |
|---|---|---|
| `NZDUSD.DWX` | `266083da-2354-4fb3-bc02-bedc6130ee21` | `pending`, attempt 0, unclaimed |

The retry window is `2017.01.01` through `2024.12.31`. The consistent pre-write
DB backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1236_nzdusd_q02_requeue_20260711T052625Z.sqlite`.

## Runtime And Safety

`FACTORY_OFF.flag` is active and the farm already held 3 active plus 3,630
pending rows at handoff. No manual smoke/backtest, terminal, or MetaTester was
started or interrupted, so this unit added no backtest CPU load. No T_Live
path, AutoTrading setting, portfolio gate, or T_Live manifest was touched.

Machine-readable evidence:
`artifacts/qm5_1236_nzdusd_q02_infra_repair_requeue_20260711.json`.
