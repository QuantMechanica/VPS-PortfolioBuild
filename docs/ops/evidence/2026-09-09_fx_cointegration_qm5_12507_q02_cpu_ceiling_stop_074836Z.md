# FX cointegration fallback — QM5_12507 Q02 CPU-ceiling stop

Date: 2026-09-09

Captured: `2026-09-09T07:48:36.9405484Z`

Branch: `agents/board-advisor`

Observation head: `0717153225abef51d900757867823d0da178be65`

## Outcome

The frozen 66-pair FX cointegration frontier has no unbuilt, reputable-screen
relationship. Its two original survivors are not blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then Q05
  `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then Q04 `FAIL`.

Creating another card or EA from that frontier would be duplicate work. The
selected existing-card fallback is therefore the low-frequency EURUSD/GBPUSD
H1 relationship in `QM5_12507_pair-coint-z`. Its one canonical logical-basket
Q02 work item is `547c4fd3-f3fd-4c59-b9dc-654e96521251`; it remains `pending`,
unclaimed, attempt zero, and already carries `priority_track=true`. It has no
work-item hold. No second Q02 row was inserted and its priority marker was not
rewritten.

The EA retains a compiled `.ex5`, a `basket_manifest.json`, and the logical
backtest setfile. The setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The approved card is
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12507_pair-coint-z.md`, whose
SHA-256 is
`237b11c5657f226e140a6ae68a41e438e2514519a1b0cf9f987b1c284006c988`.
The reputable structural-method lineage is Ernest P. Chan, *Quantitative
Trading* (Wiley, 2009), preserved in the governed source/card records.

## PACER guard

The source was not written during this wake, so the mandatory post-write
compile boundary was not entered. A read-only guard audit was nevertheless
run against the selected source:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
ok=true, predicate=EA_FRAMEWORK_INPUT_PINNED, hit_count=0
```

The selected artifact identities were:

| Artifact | SHA-256 |
|---|---|
| `.mq5` | `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c` |
| `.ex5` | `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa` |
| `basket_manifest.json` | `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56` |
| logical backtest setfile | `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99` |

## Binding CPU stop

The five one-second whole-host CPU samples were `84.200531%`, `96.424782%`,
`94.733734%`, `94.156700%`, and `97.755768%`. The average was `93.454303%` and
the maximum exceeded the binding `97%` ceiling. At the same snapshot, the
canonical farm had seven active work items (`Q04=4`, `OPT_CENSUS=3`), exactly
the `BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT=7` threshold. A preceding
path-aware `mt5-slots` snapshot observed six factory terminals; `T_Live` and
the unrelated FTMO terminal were excluded and were not controlled.

Per the mission's explicit ceiling rule, processing stopped. No compile or
backtest work was enqueued, no queue row or priority was mutated, no dispatch
tick or tester was launched, and no terminal reservation or control followed.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution surface changed.
- No T_Live manifest, T_Live terminal, deploy artifact, or AutoTrading state
  changed.
- No Strategy Card, EA source, binary, setfile, basket manifest, registry, or
  magic row changed.
- Unrelated dirty-worktree changes were left unstaged and untouched.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_cpu_ceiling_stop_20260909T074836Z_board_advisor.json`.
