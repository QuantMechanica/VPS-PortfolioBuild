# Host-slot magic conflation (18954866): independent verification, not yet implemented

- Router task: `18954866-6166-4529-8ec6-8485ef25c023` (claude, priority 85)
- Follow-up to `docs/ops/evidence/2026-08-16_host_slot_magic_conflation_q04_evidence.md`
  (the original root-cause investigation).
- Scope: read-only source verification. No source, card, setfile, or
  work-item mutated.

## What this task did

1. **Independently re-derived the root cause from source**, per the dual-forensics
   practice for serious incidents. Confirmed on direct read, not by trusting
   the prior doc's line citations:
   - `QM_Entry.mqh:251`: `magic = QM_MagicChecked(g_qm_entry_ea_id,
     req.symbol_slot, _Symbol);` — matches exactly.
   - `QM_MagicResolver.mqh:145-172` (`QM_MagicChecked`): `expected_symbol` is
     accepted as a parameter but only used inside
     `QM_MagicCollisionWithForeignOpenPositions` (a live-position collision
     check), never to validate that the registry's own `(ea_id, slot)` symbol
     mapping equals `expected_symbol`. Confirmed: a slot whose registered
     symbol differs from `_Symbol` returns that foreign symbol's magic
     silently, exactly as the original doc describes.
   - `QM_Entry.mqh:257`: `if(v3_execution && magic !=
     g_qm_runtime_execution_contract.magic)` rejects loudly
     (`QM_ENTRY_REJECTED_CONTRACT`) on any magic mismatch for V3-contract
     EAs. This independently answers handoff item 3 ("determine why
     V3-contract EAs are immune") from source alone, without needing the
     natural-experiment result: V3 EAs cannot silently accept a foreign
     magic because the contract-magic comparison catches it and rejects.
   - Conclusion: the original root-cause diagnosis is accurate. The proposed
     fix shape (host-slot semantics at `QM_Entry.mqh:251` + fail-closed
     registry-symbol validation inside `QM_MagicChecked`) is well-targeted.

2. **Checked the gating natural experiment.** The original doc left
   `4619255d-47b9-415f-9eb3-514c744479af` (QM5_2002 XAUUSD, Q04) running
   deliberately to size the blast radius / confirm the detector before any
   fix lands. As of this check it is still `status=pending` in `work_items`
   (queued, not yet run) — normal queue depth (952 pending factory-wide), not
   evidence of anything stuck. This task did not force it ahead of the
   deterministic queue.

3. **Narrowed the open question analytically instead of waiting.**
   `QM5_2002`'s registry row for `XAUUSD.DWX` is slot 34 (non-zero,
   `framework/registry/magic_numbers.csv`), and its source has no explicit
   `req.symbol_slot = qm_magic_slot_offset` assignment and no textual
   reference to `RuntimeExecutionContract`/V3 machinery. That pattern matches
   the *affected* profile (default slot 0 vs. non-zero registry slot), not
   the *immune* V3 profile — but absence of a source-level V3 marker is not
   conclusive on its own (the known-immune precedent `QM5_10571` also has no
   explicit `symbol_slot` assignment; its immunity comes from a
   framework-level runtime flag this task did not fully trace). Treat this as
   a directional signal, not a substitute for the natural experiment's actual
   result.

## Why no code was changed this cycle

- The original doc's own handoff explicitly names **Codex** as the
  implementer for this fix (`framework include changes require rebuilding
  affected EAs`); per `CLAUDE.md`'s capability split, Codex is the default
  lane for repo-edit/pipeline-wiring work at this blast radius (`QM_Entry.mqh`
  / `QM_MagicResolver.mqh` are included into every EA in the fleet).
- Verification the handoff itself requires (`verification_required`: unit
  tests for the magic resolution paths, one real fold rerun of `QM5_11424`
  GBPUSD proving stream + `q04_sim` appear, confirming
  `ENTRY_ACCEPTED`==`INIT`==`KILL_SWITCH_INIT` magic) needs an actual
  compile + bound backtest cycle through the T1-T10 factory, which this
  single-pass task is not positioned to run and self-verify.
- Live exposure remains none (confirmed unchanged from the original doc: all
  24 active `T_Live` presets belong to slot-wiring EAs).

## Disposition

No source, card, setfile, or work item mutated. Recommend: (a) route the
actual `QM_Entry.mqh`/`QM_MagicResolver.mqh` edit to Codex, (b) let
`4619255d` resolve through the normal Q04 queue as originally designed
before treating the blast-radius count as final, (c) re-scan with the
corrected detector once the fix lands, staging `QM5_11424` first as the
original doc specifies (Q02 already swept 5/5, blocked on 3 of 4 symbols).
