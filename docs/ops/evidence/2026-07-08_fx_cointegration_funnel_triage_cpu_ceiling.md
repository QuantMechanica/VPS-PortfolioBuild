# FX Cointegration Funnel Triage CPU Ceiling - 2026-07-08

Branch: `agents/board-advisor`
Operator: Codex
Checked at: `2026-07-08T03:49:05+02:00`

## Scope

Mission: grow the V5 book with market-neutral FX cointegration sleeves, preferring
`QM5_12532` / `QM5_12533` Q02 unblocks if still blocked. Guardrails observed:
no `T_Live`, no AutoTrading, no deploy manifest, and no portfolio admission,
portfolio KPI, or Q08 contribution edits.

## Research Decision

The controlling strict scan remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. It names only two
strict 66-pair FX cointegration survivors:

| Pair | Built EA | Current state |
|---|---|---|
| `EURJPY~GBPJPY` | `QM5_12533` | Q02 PASS, later Q04 FAIL |
| `AUDUSD~NZDUSD` | `QM5_12532` | Q02 PASS, Q04 PASS, later Q05 FAIL |

No unbuilt approved/allocated strict-scan pair was found. The extended-screen
siblings are also already built and past Q02:

| EA | Pair | Current state |
|---|---|---|
| `QM5_13024` | `AUDCAD~GBPAUD` | Q02 PASS, Q04 FAIL |
| `QM5_13029` | `GBPCAD~GBPNZD` | Q02 PASS, Q03 PASS, Q04 FAIL |

Creating another Q02 row for these would be duplicate queue work.

## Fallback Lane Selected

The highest clean existing FX cointegration lane is:

| Field | Value |
|---|---|
| EA | `QM5_12712` |
| Pair | `EURGBP.DWX` / `EURAUD.DWX` |
| Logical symbol | `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1` |
| Current gate | Q07 |
| Work item | `1b9fa7a5-48a7-4e57-a699-9e55dfb0cb19` |
| Status | `pending` |
| Priority | `priority_track=true` |
| Prior gates | Q02 PASS, Q03 PASS, Q04 PASS, Q05 PASS, Q06 PASS |

This row is already the top priority pending item in
`D:/QM/strategy_farm/state/farm_state.sqlite`, so no duplicate enqueue or
priority churn was applied.

## CPU Ceiling

Queue snapshot at check time:

| Status | Count |
|---|---:|
| active | 7 |
| pending | 5425 |
| done | 43626 |
| failed | 45267 |

Because seven worker items were active and `QM5_12712` was already priority
pending, I stopped under the mission CPU-ceiling discipline instead of manually
launching a tester or adding duplicate queue rows.

Machine-readable snapshot:
`artifacts/fx_cointegration_funnel_triage_20260708T014905Z.json`.
