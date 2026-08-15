# FX cointegration GBPUSD/USDJPY — post-restoration basket-lane stop

Date: 2026-08-15

Branch: `agents/board-advisor`

Sample window: `2026-08-15T21:33:45Z` through `2026-08-15T21:33:59Z`

## Outcome

No duplicate Card or EA was created. The frozen 66-pair cointegration frontier
remains fully mechanized. A fresh filesystem reconciliation found 25 approved
Card filenames containing `coint` or `cointegration`, and every parsed EA ID and
slug has its matching EA directory.

The two priority anchors remain beyond Q02 and have no open ONINIT or
NO_HISTORY repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback is therefore still frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in the approved and
built `QM5_1257_lemishko-fx-cointpair`. Its repaired logical Q02 work item is
pending exactly once. Enqueueing or requeueing it would create duplicate queue
work, so neither action was taken.

## Exact fallback state

| Field | Value |
| --- | --- |
| Work item | `d4cd660c-c81a-41d3-8a4c-ad21d3319816` |
| Logical symbol | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Phase | Q02 |
| Status | `pending`, unclaimed |
| Attempt count | 2 |
| Verdict / evidence | none / none |
| Last update | `2026-08-15T13:03:04.898529Z` |
| Exact identity rows / open rows | 1 / 1 |

Fresh SHA-256 reads of the repaired MQ5, EX5, basket manifest, and logical
backtest setfile match the four bindings already stored in the row payload:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest: `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- logical backtest setfile:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

The H1 preset remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The durable OWNER-approved Card cites Lemishko, Landi,
and Caicedo-Llano (2024), SSRN 4771108. No threshold, pair binding, source
contract, risk rule, banned indicator, ML component, or strategy mechanic
changed.

## Binding backtest ceiling

The OWNER-authorized runtime decision
`RTA-2026-08-15-ENOSPC-FIX-FULL-PARALLELISM` is current and signed containment
is now disabled. General factory claims have resumed: the canonical database
reported five active work items, versus one in the preceding handoff.

The separate, fail-safe multisymbol serialization rule remains in force. Its
claim transaction permits at most one active basket farm-wide. That lane is
currently owned by:

- work item `64b6953d-2886-4227-a520-0b235deeb87a`;
- `QM5_20016_XTI_XNG_MON_RV_D1` at Q05, claimed by T4;
- path-bound PID 8916 at `D:/QM/mt5/T4/terminal64.exe`;
- two declared legs, `XTIUSD.DWX` and `XNGUSD.DWX`;
- no orphaned factory terminal process.

The three-sample CPU average was 80.33%, physical-memory headroom was 45.98
GiB, and D: had 201.32 GiB free. Those soft resources permit ordinary parallel
claims, but they do not permit a second multisymbol working set. This is the
mission's explicit backtest CPU/resource-ceiling stop. No dispatch tick, tester
launch, queue mutation, terminal reservation or control, containment mutation,
or manual bypass was attempted. The existing paced worker queue retains
ownership after the active basket completes.

## Non-duplicate delta

This state is materially different from the committed `20:48:56Z` handoff.
Signed containment changed from enabled to disabled, active work expanded from
one item to five under the restored factory, and the sole basket owner changed
from `QM5_20206` Q02 on T3 to `QM5_20016` Q05 on T4. The target's exact queue
identity and artifact bindings remain unchanged, proving that the repaired FX
basket was neither duplicated nor silently executed with drifted inputs.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_postrestore_basket_lane_stop_20260815T213359Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, Card, EA, registry,
setfile, basket manifest, external queue row, history archive, containment
state, factory process, or running terminal was changed.
