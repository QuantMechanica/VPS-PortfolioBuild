# SP-D5 Immutable Second Backup Copy — Dependency Hold

Date: 2026-08-23

Router task: `942fd7c2-c094-40f8-8e45-49730c88ec17` (`SP-D5`, priority 50, zone GELB)

## Verdict

DEPENDENCY_HOLD — no backup copy, trust-domain split, or retention change was
made. SP-D5's own payload declares `depends_on: SP-D3`. `SP-D3`
(`74a78403-733e-40c7-a80e-f222f36c942f`, "Backup verschluesseln +
manifestieren") is `BLOCKED`, and its block is not a stalled work item but a
recorded, deliberate OWNER deferral:

> BLOCKED durch OWNER-Entscheid, nicht durch Arbeitsmangel ... OWNER hat die
> Custody-Frage am 2026-08-22 ausdruecklich VERTAGT (OWNER-DEC-BACKUP-KEY,
> "OWNER: vertagt"; `decisions/2026-08-22_owner_decisions_evening_batch.md`
> Abschnitt 1). Damit ist SP-D3 kein offener Arbeitsauftrag mehr, sondern eine
> bewusst akzeptierte Risikoposition ... Wiedervorlage ausschliesslich durch
> OWNER.

`SP-D4` ("Echter Restore-Drill mit RPO/RTO"), the other task that names
`SP-D3` as its own dependency, was already held on 2026-08-22 for the same
reason. This hold applies the identical, already-established reasoning to
`SP-D5` rather than re-litigating a settled OWNER call.

## Why an immutable second copy cannot be built ahead of SP-D3

`SP-D5`'s acceptance criteria require "eine getrennte Trust-Domain nachgewiesen"
against the second copy's own retention/immutability. Building that second,
immutable copy today would mean picking its content and custody shape
(encrypted vs. plain, which retention policy governs it, which key material
if any) independently of `SP-D3`, which is the task chartered to decide
exactly that under `ROT-4`. `ROT-4` is the OWNER decision `SP-D3` is blocked
on; per the standing authorization's ROT list, key custody / encryption
policy is never autonomous. Producing a second copy now would either (a)
duplicate work `SP-D3` will have to redo once custody is decided, or (b)
silently commit to an unencrypted-forever posture for the second copy without
that being an explicit OWNER call — the same failure mode `SP-D3`'s and
`SP-D4`'s holds were written to prevent.

## Checks performed

- Read `SP-D5`'s routed payload (`depends_on: SP-D3`, hard_constraint
  "getrennte Trust-Domain") from `agent_tasks`.
- Read `SP-D3`'s current `agent_tasks` row: state `BLOCKED`, verdict as
  quoted above, `updated_at=2026-08-22T19:16:24Z`.
- Read `SP-D4`'s current `agent_tasks` row (state `BLOCKED`, same `SP-D3`
  dependency, same OWNER-deferral reasoning) as the established precedent
  for how a `SP-D3`-dependent task should be held.
- Confirmed no `decisions/YYYY-MM-DD_*` file superseding
  `OWNER-DEC-BACKUP-KEY` exists as of this observation (2026-08-23) — the
  deferral in `decisions/2026-08-22_owner_decisions_evening_batch.md` §1
  remains the current, unreversed state.

No calendar seed, source file, pipeline verdict, work item, terminal, or
AutoTrading state was changed while producing this hold.

## Deterministic resume conditions

SP-D5 may be re-routed once OWNER decides `OWNER-DEC-BACKUP-KEY` / `ROT-4`
(the key-custody and recovery contract) and `SP-D3` moves out of `BLOCKED`.
At that point SP-D5's second-copy design should reuse whatever
encrypted/manifested shape SP-D3 lands on, rather than being designed
independently of it.

## Evidence

- `agent_tasks` row `942fd7c2-c094-40f8-8e45-49730c88ec17` (SP-D5, this task).
- `agent_tasks` row `74a78403-733e-40c7-a80e-f222f36c942f` (SP-D3, `BLOCKED`).
- `agent_tasks` row `41aa55bc-0780-474d-8f26-332db8fb9e1b` (SP-D4, `BLOCKED`,
  same dependency, established precedent for this hold's reasoning).
- `decisions/2026-08-22_owner_decisions_evening_batch.md` §1
  (`OWNER-DEC-BACKUP-KEY`: "OWNER: vertagt").
