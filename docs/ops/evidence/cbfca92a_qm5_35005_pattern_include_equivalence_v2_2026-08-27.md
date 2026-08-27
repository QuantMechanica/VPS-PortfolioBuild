# QM5_35005 one-variable Include equivalence v2

- Router task: `cbfca92a-79ca-4cde-9dc8-1992a6023f39`
- Outcome: **IDENTISCH**
- Pipeline verdict: **none**; this artifact remains subject to Orchestrator/OWNER review.
- Factory/live terminals: **not targeted**; both compiles and tests used create-only disposable profiles.

## Isolated build identities

| Side | Detached commit | Include tree SHA-256 | MQ5 SHA-256 | Private EX5 SHA-256 | Compile |
|---|---|---|---|---|---|
| parent | `73d81a93e7df539d51f7496c3b3c9a428611e29c` | `b8d2232d92096c650cd956c249cc4cbdb2fc9197f6633becefd697a49255cf1f` | `8c5457fc7cc7b10af168f89089b7320a5118d43078f87ed73232de18bbe0d4fc` | `897bea184c3d7e9bf7b6e55748beefae8ebccdcac945f378aa6eb71c2eec3c88` | 0 errors, 0 warnings |
| integration | `b0bdc4d72f23876398b707db72450a560718ef4a` | `1663d76d1ea90e1bd385987b5ebae61b69b58aa0e56232677d783f0a8a5721f3` | `8c5457fc7cc7b10af168f89089b7320a5118d43078f87ed73232de18bbe0d4fc` | `9f021ec3e74f82c927e25ddd087ad777c5859a3374dfe978454526c9820263c3` | 0 errors, 0 warnings |

The only deliberate compiler-input difference is the complete `framework/include` tree at the parent versus `b0bdc4d72`. The EA source bytes, MetaEditor bytes, standard-library source, set file, tester build, custom history, window, model, seed, deposit, currency, and leverage are frozen identically.

Include delta:

- `M	framework/include/QM/QM_BasketOrder.mqh`
- `M	framework/include/QM/QM_Common.mqh`
- `M	framework/include/QM/QM_Entry.mqh`
- `M	framework/include/QM/QM_PatternPermission.mqh`

## Exact Deals comparison

| Measure | Parent | Integration | Result |
|---|---:|---:|---|
| Native Deals rows | 69 | 69 | IDENTISCH |
| Canonical Deals SHA-256 | `8b5bfa3870764060ae90483338b72f60f5c5c4fcf1ec643640274aec985371a8` | `8b5bfa3870764060ae90483338b72f60f5c5c4fcf1ec643640274aec985371a8` | IDENTISCH |
| Differing rows | 0 | 0 | none |
| History inventory | `9cb641a3b124af1c418868c842748a9dbf1abec5a9b59a07c1ebc24295185816` | `9cb641a3b124af1c418868c842748a9dbf1abec5a9b59a07c1ebc24295185816` | IDENTICAL |

## Integration-run input echo

- `opt_pp_buy1=0`
- `opt_pp_buy2=0`
- `opt_pp_buy3=0`
- `opt_pp_sell1=0`
- `opt_pp_sell2=0`
- `opt_pp_sell3=0`

## Interpretation

The two native Deals byte streams are identical and every documented Deals field matches. The six new pattern-permission inputs echo zero. Orchestrator/OWNER may review this proof when deciding the compile-wave hold; this artifact does not lift the hold itself.

## Safety

- No EX5 is stored in Git or the EA inventory.
- T1-T10, T_Live, AutoTrading, queue rows, and pipeline verdicts were not changed.
- Outbound firewall blocks covered every disposable MetaEditor, terminal, and tester executable for the duration of its use and were removed at closeout.
- `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and `qm_news_stale_max_hours <= 336` were enforced before launch.

## Governed containment finalization

The original controller completed both native tests, but the integration portable terminal ignored `ShutdownTerminal=1`. The controller contained only that disposable process at its 30-minute bound and removed all six outbound-block firewall rules. This finalization pass launched no process and re-authenticated the stable native reports and all durable build/run bindings after containment.

- Original contained failure packet SHA-256: `c04913d595352f06da389d1d387c021b07c22bcff475b8daaed984bd6228617f`
- Parent post-run cache changes outside the tested window: 2
- Integration post-run cache changes outside the tested window: 2
- Tested-window 2022 history/tick files remained byte-unchanged on both sides.
- Current-year cache mutations were excluded from the equivalence variable and are listed in the packet.
