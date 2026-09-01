# FX cointegration frontier: QM5_1257 V4 Q03 activation handoff

Recorded: 2026-09-01T20:13:17Z

Branch: `agents/board-advisor`

Observation base: `ae7d5f56c17b708a8b779665c01e33d06b72e547`

## Outcome

No reputable, unbuilt FX cointegration identity remains in the reviewed 66-pair frontier. Per the mission fallback, the next concrete existing pair is **QM5_1257 GBPUSD/USDJPY H1**. Its OWNER-authorized, exact-identity V4 Q03 row is pending exactly once and is ready for normal resident-worker dispatch after the custom-history activation rollout is healthy.

No duplicate card, EA, work item, or forced dispatch was created. This handoff does not promote QM5_1257 and does not erase its historical Q04 failure.

## Frontier and anchor checks

- The v3 all-pairs discovery in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` evaluated all 66 pair combinations. It admitted QM5_12533 EURJPY/GBPJPY and QM5_12532 AUDUSD/NZDUSD.
- `artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json` records sign-aware coverage of the full 66-pair universe with zero uncovered identities.
- The approved cointegration/coint filename census found 44 unique EA IDs; all 44 have EA directories. Creating another card from an already-covered pair would therefore be duplicate work without new reputable research evidence.
- The two mission anchors are not blocked at Q02: QM5_12532 has Q02 PASS and Q04 PASS (later Q05 FAIL); QM5_12533 has Q02 PASS (later Q04 FAIL).

## Selected concrete fallback

| Field | Value |
|---|---|
| EA | `QM5_1257_lemishko-fx-cointpair` |
| Pair | `GBPUSD.DWX` / `USDJPY.DWX` |
| Host / timeframe | `GBPUSD.DWX` / H1 |
| Logical symbol | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Method | Structural Engle-Granger pair trading; monthly frozen OLS and spread z-score |
| Source | Lemishko, Landi, and Caicedo-Llano (2024), *Cointegration-Based Strategies in Forex Pairs Trading*, SSRN 4771108 |
| Card | OWNER-approved; R1-R4 PASS |
| Backtest risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Basket manifest | Present; two explicit legs and USD 100,000 tester account |
| Q02 window | 2017-01-01 through 2022-12-31 |

The card is structural, contains no ML dependency or banned indicator, and freezes its hedge estimate for a calendar month rather than adapting intramonth.

## Exact identity and lineage

The on-disk identity was rechecked against the V4 Q03 payload:

- MQ5 SHA-256: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5 SHA-256: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest SHA-256: `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- backtest set SHA-256: `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`
- V4 payload SHA-256: `c345e2e2e8c583db875e4fd6f1fa1da15ac4555caa965b67dd7b0c47d175ecdf`

Canonical lineage:

1. Q02 work item `d4cd660c-c81a-41d3-8a4c-ad21d3319816` is DONE/PASS with 290 trades.
2. Historical Q04 work item `d48dfb37-d28b-4e9d-aebe-376b7afe12dd` is DONE/FAIL. That result remains authoritative historical evidence.
3. V4 exact-identity Q03 work item `162a6230-d6fa-424c-a539-b873cc9a5559` is PENDING, unclaimed, attempt 0, and the only open row for this exact identity.
4. The V4 row is explicitly covered by OWNER decision `OWNER-DEC-BACKFILL-TRANCHE-1=YES` in `docs/ops/evidence/a4812054_backfill_tranche1_receipt_2026-08-31.json` (receipt SHA-256 `4da21c71b0d492cef50ffe471e67acbade6711b16d7b9a038999710ebd9b5c0a`).

This is a rebaseline test contract, not a waiver or retroactive reversal of the legacy Q04 FAIL.

## Dispatch state and capacity

Five paced CPU samples during the final observation window were 37.43%, 37.19%, 43.68%, 43.71%, and 48.05% (average 42.01%, maximum 48.05%). The 97% CPU ceiling was not reached, and the launch gate remained capped at one concurrent launch.

At 20:13:17Z there were zero active canonical work items and zero active factory terminals. The resident workers nevertheless remained fail-closed because their running activation contract was stale relative to the activation-v2 repair already landed in commits `47c1200f55` and `ae7d5f56c1`. A worker briefly claimed an unrelated higher-ranked row and released it unchanged with `CUSTOM_HISTORY_ISOLATION_FAIL_CLOSED`; its attempt count was preserved. QM5_1257 therefore remained pending in canonical order.

The safe continuation is to complete the existing worker rollout under the landed activation-v2 owner process, then let a resident worker claim the already-authorized QM5_1257 row normally. Do not add a duplicate row, target-dispatch around queue order, create `FACTORY_OFF`, or bypass the custom-history gate.

## Validation and safety

- `python -m pytest tools/strategy_farm/tests/test_basket_work_items.py -q`: **18 passed** in 11.38 seconds on the final rerun.
- No runtime database or queue mutation was made.
- No EA, setfile, basket manifest, registry, portfolio-admission gate, portfolio KPI/Q08 contribution, T_Live manifest, or AutoTrading setting was changed.

Machine-readable companion: `artifacts/fx_cointegration_qm5_1257_q03_v4_activation_handoff_20260901T201317Z_board_advisor.json`.
