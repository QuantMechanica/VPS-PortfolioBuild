# Execution record — OWNER-DEC-GOVERNOR-V2-ENFORCE-20260913 (receipt 1a184219)

Decision-bound task `9e5db1e9-b10e-5b98-94f9-f3f3c3610715` (Claude lane, orchestrator
execution 2026-09-14).

## Authority

OWNER 2026-09-14 ~13:2xZ (chat, control review "Geschwindigkeit, Fortschritt, offene
Punkte, naechster Hebel / 80-20"): "Los gehts, alles freigegeben und gemaess Vorschlag
entschieden! Ausser RAM Zukauf." Card recommendation: "JA fuer (1)-(3) jetzt, (4) im
Cutover-Fenster." Transcribed as a YES receipt by the Orchestrator (Stehende Vollmacht:
OWNER chat instruction = source of truth 1).

| Field | Value |
|---|---|
| decision_id | `OWNER-DEC-GOVERNOR-V2-ENFORCE-20260913` |
| receipt_id | `1a184219-1525-40fa-9f0c-0287833b2e4f` |
| receipt_sha256 | `82eaf6b9ac28e6d09c56faa18a672c02c1f08543f56ecf0cec38485034958714` |
| decided_at_utc | 2026-09-14T13:45:21Z |
| choice | YES |

The receipt names the exact bytes to accept: policy sha `f2baf21a6282942cc99b82ce77caaf46a561247b188340d4e2f06851f01feb70`,
activation sha `5ab3b819562a0504308434342744b1cd3d52c1e558267be8d520b34a9194fb41`, and the order line
`GOVERNOR-ENFORCE: ACTIVATE DXZ 2026-09-13`. Both artifact files were already committed
2026-09-13 (commit `88a4874117`) and re-verified byte-identical (sha256 recomputed, matches)
before use — nothing was edited.

## What was executed (objective points 1-3)

1. **Policy sha f2baf21a accepted as OWNER_SIGNED.** The candidate file
   `docs/ops/evidence/2026-09-13_governor_v2_cutover_package/account_governor_policy_dxz_4000090541_20260913.OWNER_SIGNED_CANDIDATE.json`
   already carries `status: OWNER_SIGNED` and the four ratified thresholds
   (`min_free_margin_account 68750`, `max_gross_leverage 7.5`,
   `max_abs_currency_net_leverage 4.3`, `max_planned_stop_loss_account 3650`,
   `stage2_cancel_pending_authorized true`) byte-identical to the PROPOSED derivation. Per
   the tool's own design ("naming the sha is the signature" —
   `OWNER_SIGNATURE_BLOCK_20260913.md`), the OWNER's receipt naming this exact sha256 **is**
   the acceptance; no file edit was needed or made. Verified: `sha256sum` on the file =
   `f2baf21a…` (match).
2. **Enforce-activation artifact accepted.** Same pattern:
   `governor_enforce_activation_dxz_4000090541_20260913.DRAFT.json` already carries
   `status: OWNER_SIGNED`, `enforce_authorized: true`,
   `trigger_policy_sha256` == the policy sha above, `activation_decision_ref` pointing at
   the order file below. Verified sha256 = `5ab3b819…` (match, unedited).
3. **Order file committed.** `decisions/2026-09-13_owner_governor_enforce_dxz.md` written
   at the canonical path the adapter requires (`<date>_owner_governor_enforce_<venue>.md`),
   containing the literal line `GOVERNOR-ENFORCE: ACTIVATE DXZ 2026-09-13` on its own line,
   the bound-artifact table (both shas above), the receipt citation as OWNER signature, and
   an explicit "No switch to enforce mode today" section explaining why (chart not attached
   — see next section). Content is the 2026-09-13 draft made real at the canonical path;
   date preserved because the bound hashes were computed against it.

## Objective point 4 — deliberately NOT executed today

The objective and `selected_effect` both gate the enforce switch on the chart attach:
"schaltet den Adapter **nach dem Chart-Attach** auf enforce". Read-only check of the live
snapshot before and after today's work:

```
C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/account_snapshot.json
-> no "schema" key (still the pre-v2 legacy export), time_utc 2026-09-14T14:45:31Z
```

This is the `LEGACY_UNVERSIONED` state, unchanged since the 2026-09-13 package was written
— the monitor v2 chart has not been attached to T_Live. That is an OWNER-only operational
act (`forbidden_actions` bars this task from touching any T_Live file/process/chart/preset).
Consequently:

- The scheduled watcher `QM_StrategyFarm_GovernorDryRunWatch` was left untouched — verified
  still registered `Ready`, action arguments still `--dry-run ... --max-age-seconds 180`,
  no `--enforce`/`--executor` flag. **Not modified by this task.**
- No "first three enforce intervals" exist to report, because enforcement was never
  switched on for the recurring watcher. Reporting fabricated intervals would violate
  "evidence over claims."

**One-off verification only** (read-only, scratch dirs, no T_Live write — same pattern as
the 2026-09-13 probe series in `adapter_dry_run_refusals_20260913.json`, now run against
the real committed artifacts instead of drafts):

```
python -X utf8 tools/strategy_farm/account_governor_action_adapter.py --enforce \
  --policy     docs/ops/evidence/2026-09-13_governor_v2_cutover_package/account_governor_policy_dxz_4000090541_20260913.OWNER_SIGNED_CANDIDATE.json \
  --trusted-policy-sha256     f2baf21a6282942cc99b82ce77caaf46a561247b188340d4e2f06851f01feb70 \
  --activation docs/ops/evidence/2026-09-13_governor_v2_cutover_package/governor_enforce_activation_dxz_4000090541_20260913.DRAFT.json \
  --trusted-activation-sha256 5ab3b819562a0504308434342744b1cd3d52c1e558267be8d520b34a9194fb41 \
  --executor halt-file \
  --enforce-order decisions/2026-09-13_owner_governor_enforce_dxz.md \
  --enforce-venue dxz \
  --halt-dir D:/QM/reports/governor/2026-09-14_scratch_receipts/halt_scratch \
  --halt-receipt-dir D:/QM/reports/governor/2026-09-14_scratch_receipts/halt_receipts_scratch \
  --out D:/QM/reports/governor/2026-09-14_scratch_receipts
```

Result: `mode: enforce`, `enforcement_activated: true`, `activation.bound: true`,
`outcome: ENFORCE_REFUSED_BY_EXECUTOR`, `refusal_reason:
l1_entry_freeze_not_expressible_via_halt_channel`, `actions_executed[0].applied: false`,
`files_written: []`, **rc=3**. Halt scratch dir verified empty after the run. This proves
the entire authorization chain now binds against the real, canonical files (policy +
activation + correctly-named committed order), and the only remaining refusal is exactly
the by-design level-1 refusal documented in the 2026-09-13 package — not a missing
signature. It is a one-time proof run, not a mode switch: the recurring watcher still runs
`--dry-run` only, and no halt file exists anywhere as a result of this task.

Plain governor dry-run re-check (no policy/activation, matches the existing evidence
pattern): `level 1 ENTRY_FREEZE_UNCERTAINTY`, `snapshot_schema_not_v2:LEGACY_UNVERSIONED`,
`dry_run: true` — unchanged from 2026-09-13.

## Acceptance (against the task's `acceptance` list)

- "Policy sha f2baf21a recorded OWNER_SIGNED; activation artifact and order file
  committed" — **met**: policy/activation already carried the ratified bytes and are now
  cited as accepted by name in the committed order file; order file committed at
  `decisions/2026-09-13_owner_governor_enforce_dxz.md`.
- "Adapter stays DRY_RUN_PLAN outside the cutover window; enforce only after chart attach
  inside the window" — **met**: the recurring watcher task is untouched (`--dry-run` only);
  the one-off `--enforce` proof run was refused by the executor before any state change
  (rc=3, no files written), consistent with "outside the window, enforcement cannot
  succeed even if attempted."
- "No AutoTrading change, no order placement, no T_Live chart/preset mutation by this
  task" — **met**: no T_Live path was written by anything in this task; the adapter reads
  `account_snapshot.json` (read-only) and would only write under `--halt-dir`, which was
  pointed at a scratch path and remained empty.
- "First three enforce intervals reported with rc and level" — **not met, correctly
  deferred**: no interval exists to report because enforcement has not been switched on for
  the recurring watcher (gated on the OWNER's chart attach, which has not happened). See
  "Still open" below for exactly what happens once it does.

## Forbidden actions — none taken

No Factory_OFF/ON, no worker/terminal interruption, no T_Live file/process/chart/preset/
account mutation, no AutoTrading change, no order placement, no live deployment, no
gate-threshold/criterion/candidate-universe change, no deletion or overwrite of any
existing verdict/trade stream/evidence, no book construction or live-book mutation, no
inferred authority beyond the printed `selected_effect`.

## Vault mirror — deferred

`G:\My Drive\QuantMechanica - Company Reference` is not reachable from this headless
session (`G:` drive not mapped; `Get-ChildItem`/PowerShell drive lookup fails with "Cannot
find drive"). Per CLAUDE.md source-of-truth order, filesystem state already outranks the
vault mirror, and the canonical git-tracked records
(`decisions/2026-09-13_owner_governor_enforce_dxz.md`, this file) are authoritative. Flagged
as a follow-up for a session with vault access.

## Evidence

- `decisions/2026-09-13_owner_governor_enforce_dxz.md` (this commit)
- `docs/ops/evidence/2026-09-13_governor_v2_cutover_package/account_governor_policy_dxz_4000090541_20260913.OWNER_SIGNED_CANDIDATE.json` (unchanged, commit `88a4874117`, sha256 verified `f2baf21a…`)
- `docs/ops/evidence/2026-09-13_governor_v2_cutover_package/governor_enforce_activation_dxz_4000090541_20260913.DRAFT.json` (unchanged, commit `88a4874117`, sha256 verified `5ab3b819…`)
- `D:/QM/reports/governor/2026-09-14_scratch_receipts/account_governor_action_receipt_c87de2b2b3cfa3b25071096a9908e641c0bfdb4de1bb0b61a1004e17aef73088.json` (today's one-off enforce proof, `ENFORCE_REFUSED_BY_EXECUTOR`, rc=3)
- `D:/QM/reports/governor/2026-09-14_scratch_receipts/halt_receipts_scratch/halt_executor_apply_c87de2b2b3cfa3b25071096a9908e641c0bfdb4de1bb0b61a1004e17aef73088.json` (executor refusal receipt, `files_written: []`)
- Scheduled task `QM_StrategyFarm_GovernorDryRunWatch`: `Get-ScheduledTask` state `Ready`,
  action arguments unchanged (`--dry-run ... --max-age-seconds 180`), verified at execution
  time, not modified.

## Still open (for the cutover window itself, separate OWNER acts)

1. OWNER attaches the monitor v2 chart on T_Live
   (`C:/QM/deploy/governor_v2_20260913/staging/QM_AccountMonitor.ex5`, sha `f98523ee…`);
   `account_snapshot.json` must then report `"schema": "qm.account-monitor.snapshot/v2"`.
2. Once that happens, Claude observes three watcher intervals (the acceptance criterion for
   this task's point 4) and, if they show a clean bound level (no uncertainty reasons,
   reconciled inventories), switches the recurring watcher's invocation from `--dry-run` to
   the `--enforce --executor halt-file` wiring proven above, and reports rc + level for each
   of the first three intervals.
3. Book-v2 cutover order and LIVE_RISK_FREEZE lift remain separate, OWNER-only acts;
   `GOVERNOR-HARDENING` freeze-condition text is unchanged by this task (documentation only,
   per the existing 2026-09-13 update — the freeze itself stays ACTIVE until the OWNER
   lifts it in writing).
