# QM5_1257 GBPUSD/USDJPY exit repair and Q02 refresh

Date: 2026-08-15  
Branch: `agents/board-advisor`  
Outcome: same-lineage exit repair compiled and validated; the existing exact Q02 row was rebound and released pending. No Q02 PASS is claimed.

## Selection

The governed 66-pair scan has no unbuilt relationship. `QM5_12532` and
`QM5_12533` are already beyond Q02, so creating another Card or basket would be
duplicate work. This pass therefore advanced the existing approved fallback,
`QM5_1257_lemishko-fx-cointpair`, for the logical GBPUSD.DWX/USDJPY.DWX basket.

## Same-lineage repair

The prior entry-path repair made the basket trade-capable in principle, but two
explicit Card exits remained unreachable:

- The convergence exit tested `abs(z) <= 0.0`. With the Card's default zero
  band, that requires an exact floating-point zero rather than a crossing.
- The D1 structural-stop branch requested two completed closes through
  `ReadLogCloses`, while that helper rejected every request below 30 bars before
  calling `CopyClose`.

Commit `f9ef37c1c` keeps the pair, thresholds, monthly screen, sizing, and risk
contract frozen. It identifies long/short residual direction from the registered
USDJPY companion magic and closes on the corresponding directional mean cross.
It also permits the already-coded two-close D1 observation. This is an
implementation correction to the approved rules, not a new filter or alpha
variant.

## Validation

| Check | Result | Evidence |
| --- | --- | --- |
| Strict MetaEditor compile | PASS, 0 errors, 0 warnings | `D:/QM/reports/compile/20260815_130020/summary.csv`; `framework/build/compile/20260815_130020/QM5_1257_lemishko-fx-cointpair.compile.log` |
| Strict build check | PASS, 0 failures, 0 warnings | `D:/QM/reports/framework/21/build_check_20260815_130045.json` |
| Build guardrails | PASS, 45 files, no findings | `validate_build_guardrails.py` |
| Basket symbol scope | BASKET_OK, 0 violations | GBPUSD.DWX and USDJPY.DWX only |
| Focused regression suite | 45 passed in 2.63s | `tools/strategy_farm/tests/test_fx_basket_manifests.py` |

Final bindings:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- RISK_FIXED logical setfile: `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`
- Basket manifest: `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`

The logical preset remains H1, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Build-check hash restamps were mechanically removed after
validation, so no backtest or live setfile changed.

## Exact Q02 refresh

The still-pending work item
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` was protected with its existing
`EA_IMPLEMENTATION_REPAIR` hold before source editing. Both online SQLite
backups passed `quick_check=ok`:

- Hold backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1257_exit_repair_hold_20260815T125919Z.sqlite`
  (SHA-256 `79d87e8f3bb7bc3acfe40f9ed5f300d420b63b3af651ebb7d583d320e3eb4117`).
- Refresh backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1257_exit_repair_refresh_20260815T130304Z.sqlite`
  (SHA-256 `fea8fb9fa48df889c0d81fe366f4c4de223995c250b1e3d6504ba1830bb7e9db`).

One compare-and-swap transaction replaced only the expected MQ5/EX5 hashes,
recorded commit `f9ef37c1c`, released the hold, and appended transition-ledger
sequence 1846. Post-state is pending, unclaimed, attempt count 2, payload
SHA-256 `0b8d0b355d1f750ded28c08e853e2178c24944c6d7f3c16020b02cc3e3b35c6b`.
Exactly one open row exists for this logical Q02 identity; no enqueue or requeue
created another row.

## Paced execution boundary

The factory already owns its one permitted multisymbol slot with active
`QM5_20202` work item `a070ff3f-aec1-4d32-b2c4-3444a42a4d54`. Five CPU samples
peaked at 76.7%, below the 97% global ceiling, and free RAM was 53.57 GiB. The
binding limit is the deliberate one-basket-at-a-time guard, so no competing
tester was launched. The paced worker owns QM5_1257 execution after that slot
clears.

## Safety

No Strategy Card, registry, basket manifest, setfile, portfolio-admission path,
`_kpi`, `_q08_contribution`, T_Live manifest, deploy artifact, or AutoTrading
state changed. This repair and pending Q02 row do not authorize live use.

Machine-readable companion:
`artifacts/qm5_1257_gbpusd_usdjpy_exit_repair_q02_refresh_20260815T130304Z_board_advisor.json`.
