# MNT-012 — R3 frontmatter vs body reconciliation: QM5_1457 & QM5_1459

- Date: 2026-08-21
- Task: MNT-012 (router `c96cef85` / `QM-TODO-20260821-012`)
- Agent: Claude (board-advisor worktree)
- Result: **Verified consistent — evidenced value = UNKNOWN on both cards. No edit required.**

## What MNT-012 asked

Reconcile the R3 data-availability claim on the two Strategy Cards where YAML
frontmatter reportedly said `r3_data_available: PASS` while the body R1-R4 table
said `R3 Data Available | UNKNOWN`. Determine the true value from evidence and
make frontmatter and body agree; never upgrade to PASS without data evidence.

## Where the cards actually live

There is **no Obsidian-vault Strategy Card** for these two EAs. Searched
`G:\My Drive\QuantMechanica - Company Reference` recursively for the ids, slugs
(`as-predict-bonds`, `as-lumber-gold`), titles (`Lumber-Gold`,
`Predicting US Treasury`), and `allocatesmartly` — only registry-CSV backups and
the MNT-012 maintenance note matched; the `09 Strategy Wiki/strategies` cards all
carry `ea_id: TBD` and none is an Allocate-Smartly card.

The only Strategy Cards for these EAs are the per-EA docs cards:

- `framework/EAs/QM5_1457_as-predict-bonds/docs/strategy_card.md`
- `framework/EAs/QM5_1459_as-lumber-gold/docs/strategy_card.md`

Both are **git-ignored runtime artifacts** (`git check-ignore` positive; `!!` in
`git status --ignored`) and both fall under `framework/EAs/`, which this task is
hard-ruled not to modify.

## Identity resolution

`framework/registry/ea_id_registry.csv`:

```
1457,as-predict-bonds,...,active,Research,2026-05-19
1459,as-lumber-gold,...,active,Research,2026-05-19
```

## Evidence: the true R3 value is UNKNOWN

R3 (`r3_data_available`) asks whether the card's mechanical inputs exist as
registry-approved tradable/backtestable series. The required inputs are not
present in `framework/registry/dwx_symbol_matrix.csv` (38 symbol rows; contains
only `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `XAUUSD.DWX` among the relevant names —
`grep -iE "IEF|BIL|DBC|lumber|treasury|bond"` returns nothing):

- **QM5_1459 as-lumber-gold** needs a front-month **lumber** future and **IEF**
  (intermediate US Treasuries). Neither is in the matrix.
- **QM5_1457 as-predict-bonds** needs the **Treasury yield curve**, **IEF**,
  **BIL**, **DBC**, plus an equity leg. Only the equity leg (SP500/NDX/WS30) is
  available; the rates/bond/commodity legs are absent.

Corroborating prior artifacts:
- `docs/ops/evidence/2026-07-25_qm5_1459_r3_data_gate_block.md` — the faithful
  build was fail-closed `BLOCKED` (`r3_missing_lumber_and_ief_dwx_series`);
  substituting an available series would change approved mechanics.
- `docs/ops/evidence/2026-07-20_qm5_11167_q03_history_sharing_violation.md` §
  records the original defect verbatim: QM5_1459's "detailed R3 evaluation is
  `UNKNOWN`, despite contradictory `r3_data_available: PASS` frontmatter."

Therefore the evidenced value is **UNKNOWN** for both. There is no data evidence
that would justify PASS; the body table was already correct and the frontmatter
`PASS` was the erroneous side.

## Current state (verified this task)

Both cards now agree on **UNKNOWN** in frontmatter and body, `last_updated:
2026-08-21`:

```
QM5_1457 .../docs/strategy_card.md:19: r3_data_available: UNKNOWN
QM5_1457 .../docs/strategy_card.md:78: | R3 Data Available | UNKNOWN | ... Treasury yield curves, bond ETF, BIL, DBC ... need approved proxies. |
QM5_1459 .../docs/strategy_card.md:18: r3_data_available: UNKNOWN
QM5_1459 .../docs/strategy_card.md:75: | R3 Data Available | UNKNOWN | ... lumber futures and IEF require approved external/custom-symbol data. |
```

The frontmatter had already been corrected `PASS -> UNKNOWN` (card mtime
2026-08-21 12:24, before this task ran), matching the evidenced truth. The
MNT-012 acceptance state — "frontmatter and body agree on both cards, and the
chosen value is evidenced" — therefore holds, with UNKNOWN evidenced above.

## What I changed

Nothing in the cards. No edit was required (already reconciled) and the cards are
under `framework/EAs/` (hard-ruled off-limits) and git-ignored. This document is
the only file added. No `.set`, no `framework/EAs/**`, no verdicts, no farm-state
DB writes, no T_Live touch.

## Rollback

Delete this file: `docs/ops/evidence/2026-08-21_mnt012_r3_frontmatter_body_reconcile.md`.

## Residual note for the orchestrator

MNT-012 also covers build-task lifecycle (unbuildable `pending`, QM5_20062
`BUILT_AWAITING_SMOKE`, state-machine states). Those are out of scope for this
R3-card reconciliation subtask and untouched here.
