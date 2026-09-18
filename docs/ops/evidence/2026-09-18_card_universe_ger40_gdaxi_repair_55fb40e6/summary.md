# Card-universe repair: GER40.DWX -> GDAXI.DWX (QM5_12947, QM5_12952)

Task: `55fb40e6-2d5c-4b8e-bb49-9b05302cfc28` (follow-up of 269ac1c4 / 2c43671f).

## Defect

Both approved cards declared the non-canonical symbol literal `GER40.DWX` in
`target_symbols` (and R3 reasoning / body text). `GER40.DWX` has no row in
`framework/registry/dwx_symbol_matrix.csv`; the canonical DAX custom symbol
is `GDAXI.DWX` (both raw `GDAXI` and raw `GER40.cash` alias to it in
`execution_symbol_aliases_v1.json`). This exact class of defect has been
corrected dozens of times across build waves (see git log `--grep=GER40`).

Consequence differed per EA because each hit a different governance gate:

- **QM5_12947**: magic registry (2026-08-22) and setfiles were already built
  against `GDAXI.DWX`; its `COMPILE_EA` had already passed
  (work_item `5d074dcd-...`, `COMPILE_OK`, 2026-09-07) at a point when the
  card apparently matched. The card later reverted to the `GER40.DWX`
  literal (root cause of the reversion not determinable from available
  evidence), leaving the approved-card record inconsistent with the already
  -compiled artifact.
- **QM5_12952**: `COMPILE_EA` (work_item `6c8a40b2-...`, 2026-08-25) hard
  -failed with `EA_SYMBOL_NOT_IN_CARD_UNIVERSE` -- MetaEditor compile itself
  was clean (0 errors/warnings), but `build_check` refused because the
  card's declared universe (`EURUSD.DWX, GER40.DWX, USDJPY.DWX`) did not
  contain the symbol (`GDAXI.DWX`) the magic registry/setfiles actually use.

## Fix

Edited both approved cards on `D:/QM/strategy_farm/artifacts/cards_approved/`
(runtime copy; no C:/QM/repo mirror exists for these two cards) replacing
`GER40.DWX` with `GDAXI.DWX` in frontmatter `target_symbols`, `r3_reasoning`,
and the corresponding body section. Re-parsed with
`farmctl.parse_card_frontmatter()` to confirm `target_symbols` and
`g0_status: APPROVED` are intact post-edit.

This is a documentation/data-hygiene correction to match an already-active,
already-allocated canonical symbol -- not a change to card-universe
admission criteria or to which symbols are eligible.

## Governed magic allocator

`farmctl.py magic-allocation-inventory` (read-only) re-run post-fix: no
finding rows for either `QM5_12947` or `QM5_12952` -- registry and card
text are consistent. No allocator mutation was needed; both EAs' magic
rows were already correctly allocated to `GDAXI.DWX` (2026-08-22, Codex).

## COMPILE_EA

- **QM5_12947**: already `COMPILE_OK` against the correct symbol set; left
  untouched (no unnecessary recompile of a passing artifact).
- **QM5_12952**: the governed source-repair-successor path
  (`--repair-successor-of`) refused with `SOURCE_NOT_REPAIRED` because the
  `.mq5` was never the defect (its sha256 is unchanged) -- that path is for
  source-code fixes. Used the plain governed positional enqueue instead
  (`enqueue-compile QM5_12952_mql5-force-ema-card`), which re-reads the
  (now-fixed) card fresh. New work item `489c1599-0351-4515-9d23-320b1b623b24`
  enqueued, `pending`, held under the standard
  `COMPILE_EA_WORKER_ROLLOUT_PENDING` rollout gate for the normal factory
  worker/pump cadence to pick up.

## Evidence

- `QM5_12947.json`, `QM5_12952.json` in this directory (per-EA root cause,
  before/after state, exact commands run and their JSON output).

## Safety

No `.mq5`/strategy-mechanics change. No terminal reserved/dispatched
manually. T_Live and AutoTrading untouched throughout.
