# FACTORY_RECOVERABLE_BACKLOG — QM5_10280 whc-rsrs NDX.DWX Q08 setfile backfill

- schema: `qm.factory-recoverable-backlog/v1`
- ticket: `FRB-20260916-10280`
- status: `STAGED` (not applied — card-owner act required)
- filed: 2026-09-16 (OWNER-delegated D1 failure-concentration follow-up, task `admission-lint`)
- owner: QM5_10280 card owner (backfill + governed re-enqueue); release hold `SETFILE_EMPTY_STRATEGY_PARAMS` after repair

## Defect

- class: `empty_strategy_params` (same family as docs/ops/evidence/2026-09-05_q08_empty_strategy_params_11179.md)
- artifact: `framework/EAs/QM5_10280_whc-rsrs/sets/QM5_10280_whc-rsrs_NDX.DWX_D1_backtest.set`
- artifact sha256: `446661163bcfd0f8cd607251ec7fa83693b2cff54f7a8cd9223202fd0a4f1a23`
- evidence: setfile `; strategy-specific params` block ends in `; card_defaults_source=not_found`;
  the Q08.5 runner's own parser (`q08_5_neighborhood_runner.parse_setfile_assignments`) returns
  `{}` — zero `strategy_*` keys. The sets dir has no `ablation_*` setfile, so the aggregate
  baseline guesser has no fallback — Q08.5 raises `baseline setfile has no strategy parameters`
  and the row INVALIDs exactly like QM5_10211 did.
- consequence if run: §8.5 INVALID → §8.7 INVALID (`insufficient_distinct_configs`), no merit
  verdict; a wasted full-window Q08 run.

## Park (already applied — prevents the wasted run)

Governed hold via `tools/strategy_farm/governed_work_item_hold.py apply` (backup + BEGIN IMMEDIATE
+ post-check `all_unclaimable: true`; claim-order SQL verified both rows excluded):

| work_item_id | created_at | promotion_source | hold_code | reason |
|---|---|---|---|---|
| `d3f0090c-50e6-43f2-a6cb-6ecf6c109c78` | 2026-09-16T12:00:40Z | farmctl_enqueue_backtest_ea (V3 repair row) | `SETFILE_EMPTY_STRATEGY_PARAMS` | `setfile_empty_strategy_params_pending_backfill` |
| `aec37e79-d8e0-41a6-ab34-16ed3f893715` | 2026-09-16T02:43:58Z | pump_cascade (pre-V3 promotion; same defect setfile) | `SETFILE_EMPTY_STRATEGY_PARAMS` | `setfile_empty_strategy_params_pending_backfill` |

Backup: `D:\QM\strategy_farm\state\backups\farm_state_before_scoped_b_wave3_20260916T142531Z_faf43253.sqlite`
sha256 `782bb03af7eaf8243ead68a771a48d8383d8cdda38ae74acfa87d4eb33e08b5e`. Events
`governed_hold_activated` recorded per row.

## Backfill ticket (staged — DO NOT apply from this change)

Derive the correct setfile by appending the card-locked `strategy_*` block below the existing
`; strategy-specific params from card must be appended below this line` marker, replacing the
`; card_defaults_source=not_found` line with a real source pointer:

```text
strategy_signal_tf=PERIOD_D1
strategy_rsrs_period=20
strategy_entry_threshold=0.80
strategy_exit_threshold=0.50
strategy_atr_period=14
strategy_atr_sl_mult=2.00
; card_defaults_source=D:\QM\strategy_farm\artifacts\cards_approved\QM5_10280_whc-rsrs.md
```

Derivation (both sources agree — no judgment calls):

1. EA source input literals (`framework/EAs/QM5_10280_whc-rsrs/QM5_10280_whc-rsrs.mq5:76-81`):
   `strategy_signal_tf=PERIOD_D1`, `strategy_rsrs_period=20`, `strategy_entry_threshold=0.80`,
   `strategy_exit_threshold=0.50`, `strategy_atr_period=14`, `strategy_atr_sl_mult=2.00`.
2. Card locked parameters (`D:\QM\strategy_farm\artifacts\cards_approved\QM5_10280_whc-rsrs.md`,
   `qm-dsr-single-configuration` declaration under authority `OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916`):
   identical six values (`"research_trial_count": 0`, `no_optimization_search: true` — these are
   the exact locked defaults, not a search product).

## Acceptance / release condition

1. Card owner applies the backfill as a new set_version (bump `set_version` header; the new bytes
   supersede sha256 `44666116…`).
2. The parked rows' bound artifact identity no longer matches after the backfill — close them by
   the append-only governed repair path (supersede + fresh Q08 enqueue against the backfilled
   setfile), never by editing the immutable rows.
3. Release the holds (`farmctl release-hold`) only on the replacement row; the historical parked
   rows stay as evidence.
4. Post-backfill Q08 must produce a complete neighborhood lineage (≥1 `strategy_*` param parses
   from the bound baseline setfile).
