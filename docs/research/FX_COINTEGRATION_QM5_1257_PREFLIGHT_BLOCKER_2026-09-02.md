# FX cointegration fallback: QM5_1257 preflight blocker

Recorded: 2026-09-01T22:42:21Z (2026-09-02 Europe/Berlin)

Branch: `agents/board-advisor`

Observation base: `36e02783da0227ef9715a4bb3d5e1a8f1b58c58a`

## Outcome

The reviewed 66-pair FX cointegration frontier still has no reputable unbuilt
identity. QM5_12532 and QM5_12533 are not blocked at Q02, and the more recent
QM5_20224 fallback has already reached a terminal Q07 economic FAIL. The
concrete non-duplicate continuation therefore remains **QM5_1257
GBPUSD/USDJPY H1**.

This pass repaired a real repository validation gap by adding the missing
localized `SPEC.md` and recording the exact OWNER-authorized V4 Q03 lineage in
the localized Strategy Card. The new spec passes the canonical spec validator,
and the card passes schema/ML-ban lint.

The current source is not build-clean. Strict hardening found a missing MAE
tracker, and card-to-source review found the approved combined-pair 1.5R stop
is declaration-only. No source or binary edit was made because that would make
the already-enqueued Q03 identity stale, while the available emergency rebuild
authority does not include QM5_1257.

## Frontier and anchor reconciliation

- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` records the all-pairs
  scan of 66 unordered FX relationships.
- Sign-aware coverage evidence records zero uncovered relationships. Creating
  another card from this scan would duplicate an existing identity.
- QM5_12532 AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, later Q05 FAIL.
- QM5_12533 EURJPY/GBPJPY: Q02 PASS, later Q04 FAIL.
- Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker.

## Selected existing sleeve

| Field | Value |
|---|---|
| EA | `QM5_1257_lemishko-fx-cointpair` |
| Logical symbol | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Pair | `GBPUSD.DWX` / `USDJPY.DWX` |
| Host / timeframe | `GBPUSD.DWX` / H1 |
| Method | Monthly frozen Engle-Granger/OLS qualification with H1 residual z-score |
| Frozen scan rank | 58 of 66 |
| Source | Lemishko, Landi, and Caicedo-Llano (2024), SSRN 4771108 |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Basket manifest | Present; two explicit legs, USD 100,000 tester account |

The strategy is structural and deterministic. It uses no ML, banned indicator,
grid, martingale, or intramonth hedge-ratio adaptation.

## Exact execution identity and lineage

- MQ5 SHA-256:
  `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5 SHA-256:
  `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- Basket-manifest SHA-256:
  `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- Logical backtest-set SHA-256:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

The pending Q03 row binds all three execution hashes above:

1. Q02 `d4cd660c-c81a-41d3-8a4c-ad21d3319816`: DONE/PASS, 290 trades.
2. Historical Q04 `d48dfb37-d28b-4e9d-aebe-376b7afe12dd`:
   DONE/FAIL; preserved as adverse evidence.
3. V4 Q03 `162a6230-d6fa-424c-a539-b873cc9a5559`: PENDING,
   unclaimed, attempt 0, priority-tracked, and present exactly once.
4. The Q03 rebaseline is authorized by
   `OWNER-DEC-BACKFILL-TRANCHE-1=YES`; it is not a waiver, Q05 promotion, or
   reversal of the historical Q04 FAIL.

A validation wrapper briefly refreshed only `build_hash` comments in the
setfiles. Those mechanical changes were reversed before this receipt. The
logical setfile is again byte-for-byte hash-bound to the pending row.

## New blocking findings

### Strict MAE instrumentation

`build_gate_hardening.py` returns exactly one automated failure:

`EA_Q08_MAE_HOOK_MISSING`: the framework-managed `OnTick()` starts at source
line 743 but does not call `QM_FrameworkTrackOpenPositionMae()` as its first
action.

The strict wrapper receipt is
`D:/QM/reports/framework/21/build_check_20260901_222803.json`, SHA-256
`f1f91d1bbbee9cf6336a70701c788bc3eeefb6d6cab615af689f418384ae0c93`.

### Card-required combined risk stop

The approved card requires a combined-pair stop at 1.5R. The current source
declares `strategy_r_stop=1.5` at line 43, but the identifier has no second
occurrence and therefore cannot enforce a package-level loss boundary. The
per-leg ATR stops do not prove the separate combined-pair rule.

`strategy_coint_exit_p=0.10` is also declaration-only. The card defines mean
crossing, time, daily-residual, and combined-risk exits; it does not authorize
inventing an additional 0.10 exit mechanic during this preflight.

## Governance boundary

The exact MAE emergency rebuild contract in
`tools/strategy_farm/compile_work_items.py` is limited to QM5_12947 through
QM5_12952. QM5_1257 is not in that allowlist, and no other exact source-repair
authority covers it. Consequently this pass did not:

- edit or recompile the MQ5;
- overwrite the EX5 or setfile bindings;
- enqueue a compile or duplicate Q03 row;
- hold, force-dispatch, reorder, or otherwise mutate the runtime queue.

The safe continuation is an OWNER/router-issued, one-EA source-repair authority
that covers both reviewed defects, followed by a governed compile and a fresh
append-only execution binding. The current Q03 row must not be silently rebound
to a different source or binary.

## Fleet state and capacity

Five paced CPU samples were 59.565424%, 36.720120%, 28.519358%, 25.162314%,
and 24.164439% (average 34.826331%, maximum 59.565424%). The 97% ceiling was
not reached.

At the observation time, the single serialized factory lane was occupied by
QM5_41196 OPT_CENSUS work item `def7ed06-f196-5cf7-827b-e569a7cf23cb`
on T3. QM5_1257 remained pending in governed order. No target dispatch or
second multisymbol tester was started.

## Validation

- `validate_spec_doc.py`: PASS, 1/1.
- Strategy Card schema and ML-ban lint: PASS, no missing sections or ML hits.
- `validate_build_guardrails.py`: PASS, 45 files, zero findings.
- `test_basket_work_items.py`: 18 passed.
- Strict build hardening: expected FAIL on the single MAE-hook finding above.
- `git diff --check`: PASS (line-ending conversion warning only).

No portfolio-admission/KPI/Q08-contribution file, T_Live manifest, T_Live
terminal, or AutoTrading setting was read for mutation or changed.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_1257_preflight_blocker_20260901T224221Z_board_advisor.json`.
