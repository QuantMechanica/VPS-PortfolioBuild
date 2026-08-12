# FX cointegration frontier and CPU stop — 2026-07-25

## Scope

OWNER mission: grow the certified V5 portfolio with a new market-neutral FX
cointegration sleeve, prefer repairing `QM5_12532` / `QM5_12533` if either is
still blocked at Q02, and stop at the paced-fleet CPU ceiling.

Branch: `agents/board-advisor`.

No T_Live or AutoTrading action was taken. No portfolio-admission, KPI,
Q08-contribution, or live-manifest artifact was modified.

## Source-qualified pair decision

The controlling research record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its systematic v3 scan
tested all 66 FX pairs and admitted exactly two pairs under the declared
threshold (`DEV > 0`, OOS net Sharpe `> 0.8`, at least four OOS trades):

| Pair | EA | Current deterministic state |
|---|---|---|
| AUDUSD.DWX / NZDUSD.DWX | `QM5_12532` | logical Q02 `PASS`, Q04 `PASS`, Q05 strategy `FAIL` (`pf_below_floor`, PF 0.950) |
| EURJPY.DWX / GBPJPY.DWX | `QM5_12533` | logical Q02 no longer infrastructure-blocked; repaired run reached a strategy trade-count failure, and the basket later failed Q04 |

The repository also contains cards, compiled EAs, RISK_FIXED backtest setfiles,
and `basket_manifest.json` files for the later sign-aware scan tail explored
under previous missions. The durable frontier audit at
`docs/ops/evidence/2026-07-23_fx_cointegration_frontier_q04_cpu_stop.md`
confirms that no source-qualified unbuilt scan pair remains.

Creating another card from the 66-pair scan would therefore duplicate an
existing sleeve or lower the documented reputable-source selection threshold.
Replaying either anchor at Q02 would duplicate completed logical-basket work.

## Existing-sleeve fallback

The highest-ranked non-anchor fallback previously identified was `QM5_12978`
GBPUSD.DWX / USDCAD.DWX. It has completed Q02 `PASS`, repaired Q03 `PASS`, and
logical Q04 strategy `FAIL` (`lowfreq_pooled_pf_below_floor`). It cannot be
advanced without bypassing the deterministic gate.

Other built scan-tail baskets have likewise either reached a terminal strategy
verdict or already advanced beyond Q02. No non-duplicate, gate-valid FX
cointegration enqueue was found.

## Live paced-fleet check

Read-only command:

```text
python framework/scripts/mt5_queue_status.py --sqlite D:/QM/strategy_farm/state/farm_state.sqlite --limit 30
```

Observed on 2026-07-25:

| Status | Count |
|---|---:|
| active | 8 |
| pending | 2300 |
| done | 52784 |
| failed | 48044 |

The eight active rows occupy the paced fleet across Q02, Q04, Q07, and Q08.
This is the mission's backtest CPU ceiling. No MT5 process was launched and no
queue row or farm database field was inserted, updated, or deleted.

## Stop decision

Stop without a duplicate build or enqueue. Resume only when both conditions
hold:

1. an OWNER-approved reputable source or refreshed scan admits a genuinely
   unbuilt FX pair under a declared threshold, or a built FX sleeve has a
   non-terminal infrastructure defect; and
2. paced-fleet capacity is available.

