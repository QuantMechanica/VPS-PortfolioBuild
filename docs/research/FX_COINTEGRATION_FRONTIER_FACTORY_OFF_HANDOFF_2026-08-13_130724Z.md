# FX cointegration frontier — OWNER-OFF Q02 handoff

Date: 2026-08-13

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 logical Q02 remains
PENDING; Factory OWNER state is OFF

## Outcome

No duplicate Card, EA, or work item was created. The committed sign-aware
frontier reconciliation still accounts for all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`, so there is no unbuilt
relationship to mechanize.

The existing-card fallback remains scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, implemented as pair slot 8 in the approved
`QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 row
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` remains the only row for
`QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`. It is PENDING, unclaimed, at
attempt zero, priority-tracked, free of holds/quarantine, and currently rank 8
under the canonical claim selector.

## Changed frontier state

The other unresolved relationship in the prior audit is no longer pending.
Rank 65, `USDCHF.DWX` / `AUDUSD.DWX`, completed Q02 as a strategy FAIL in
work item `415cd6d3-560c-46d8-a9f9-ee4a5b399100`: 14 trades versus the
required 25, PF 1.01, with no ONINIT failure. The exact relationship census is
now 54 PASS, 10 FAIL, one failed INFRA_FAIL, and one PENDING.

The anchors remain clear of setup blockers:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY condition.

## Existing-pair contract

The fallback is bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card, with R1-R4 PASS. The two-leg manifest carries
`GBPUSD.DWX` and `USDJPY.DWX`; the canonical H1 backtest setfile uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Its frozen scan evidence is adverse, so Q02 remains a one-shot
cadence/economics test. No refit, extra filter, banned or ML indicator, rescue
tuning, profitability claim, or strategy-mechanics change was made.

## Binding OWNER state

At `2026-08-13T13:07:24Z`, `farmctl.py mt5-slots` found zero T1-T10 factory
terminals. This is not permission to launch: both governed Factory intent
tasks, `QM_StrategyFarm_Pump_5min` and `QM_StrategyFarm_Tick_5min`, are
disabled. The watchdog independently recorded at `13:05:03Z`:

```text
factory_enabled=false
action=noop_factory_off
detail=FACTORY tasks disabled (OWNER OFF); workers=0 - leaving alone
```

The OWNER-OFF state is stricter than available CPU capacity. It was preserved:
no Factory toggle, worker start, terminal reservation, dispatch, manual tester,
queue mutation, or backtest followed. The existing exact Q02 row will remain
for the next OWNER-authorized Factory-ON window.

## Verification

- EA build guardrails: PASS across 45 files with zero findings.
- Symbol scope: `BASKET_OK`, zero violations.
- Basket-manifest regressions: 44 passed.
- Machine-readable handoff: valid JSON.
- The immutable approved Card is a legacy pre-current-template artifact. The
  current Card linter finds no ML tokens but does not recognize its older
  section names as `hypothesis`, `rules`, and `risk`. No new Card was drafted,
  and the governed G0 APPROVED / R1-R4 PASS artifact was not rewritten or
  re-approved merely to conform headings.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_factory_off_20260813T130724Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
T_Live terminal, AutoTrading state, live setfile, or live deployment artifact
was changed. FTMO and T_Live were observed only to exclude them from the
factory count.
