# OWNER enforce order — account/portfolio governor v2, DXZ live book

**RATIFIED 2026-09-14** via `OWNER-DEC-GOVERNOR-V2-ENFORCE-20260913` (receipt
`1a184219-1525-40fa-9f0c-0287833b2e4f`, receipt sha256
`82eaf6b9ac28e6d09c56faa18a672c02c1f08543f56ecf0cec38485034958714`, decided_at_utc
2026-09-14T13:45:21Z, OWNER chat: "Los gehts, alles freigegeben und gemaess Vorschlag
entschieden! Ausser RAM Zukauf"). Committed by the Claude seat under the explicit
execution authority of that receipt (`selected_effect`: "Claude schreibt die Receipts,
committet die Order-Datei mit deinem Wortlaut, schaltet den Adapter nach dem Chart-Attach
auf enforce (halt-file) und meldet die ersten drei Intervalle."). Drafted 2026-09-13 as
`docs/ops/evidence/2026-09-13_governor_v2_cutover_package/2026-09-13_owner_governor_enforce_dxz.DRAFT.md`;
this is that draft's content made real at this canonical path, with the date preserved
(2026-09-13) because the bound artifact hashes below were computed against that date.

- Venue: DXZ (Darwinex Zero live book), account `4000090541`
- Decision id: `OWNER-DEC-GOVERNOR-ENFORCE-DXZ-20260913`
- Scope: authorizes `tools/strategy_farm/account_governor_action_adapter.py --enforce`
  against the bound policy below, over the EA-native halt channel
  (`QM/halt/<ea_id>.halt`). It authorizes **nothing else**.

## Bound artifacts (the adapter refuses on any byte drift)

| Artifact | Path | SHA-256 |
|---|---|---|
| Policy (OWNER_SIGNED) | `docs/ops/evidence/2026-09-13_governor_v2_cutover_package/account_governor_policy_dxz_4000090541_20260913.OWNER_SIGNED_CANDIDATE.json` | `f2baf21a6282942cc99b82ce77caaf46a561247b188340d4e2f06851f01feb70` |
| Enforce activation | `docs/ops/evidence/2026-09-13_governor_v2_cutover_package/governor_enforce_activation_dxz_4000090541_20260913.DRAFT.json` | `5ab3b819562a0504308434342744b1cd3d52c1e558267be8d520b34a9194fb41` |
| Monitor v2 binary | `C:/QM/deploy/governor_v2_20260913/staging/QM_AccountMonitor.ex5` | `f98523ee…` (cutover package) |

Both artifact files were verified byte-identical to their committed 2026-09-13 versions
(commit `88a4874117`) before this order was written — the OWNER's receipt names these
exact hashes, so naming them here again is the ratification, not a new document.

## The order line the adapter requires (must appear verbatim, on its own line)

GOVERNOR-ENFORCE: ACTIVATE DXZ 2026-09-13

## What this does NOT authorize

- **No AutoTrading toggle.** T_Live AutoTrading stays OWNER-only and is untouched.
- **No deployment, no risk change, no new live promotion.** `OWNER-DEC-RISK-FREEZE` stays
  ACTIVE; this order does not lift it and does not satisfy any other lift condition.
- **No level-1 enforcement.** Level 1 (`ENTRY_FREEZE_UNCERTAINTY`) is not expressible on
  the halt channel and is refused by the executor
  (`l1_entry_freeze_not_expressible_via_halt_channel`).
- **No level-2 enforcement by default.** The halt channel also flattens open positions,
  which is over-action for a level-2 entry freeze; it requires the separate, explicit
  `--allow-l2-flatten-overaction` flag. Level 3 is exact on this channel.
- **No clearing of a halt.** Lifting a halt needs its own OWNER artifact
  `decisions/<date>_owner_governor_halt_clear_dxz.md` with the line
  `GOVERNOR-HALT: CLEAR DXZ <date>`.
- **No switch to enforce mode today.** As of this commit (2026-09-14) the monitor v2
  chart has not been attached to T_Live — `account_snapshot.json` is still
  `LEGACY_UNVERSIONED` (verified read-only at 2026-09-14T14:45Z) — so the governor stays
  pinned at level 1 by design and the scheduled watcher
  (`QM_StrategyFarm_GovernorDryRunWatch`) keeps running `--dry-run` only. This order makes
  enforcement *possible* once the chart is attached; it does not activate it today.

## Preconditions the OWNER confirmed before this order (per the receipt)

1. Thresholds and their derivation in the bound policy: reviewed and accepted (receipt
   question text names all four values and the 1:30 swing-margin assumption explicitly as
   unverified).
2. Monitor v2 attach on T_Live and the dry-run watcher observing a stable v2 level: still
   pending — scheduled for the cutover window, a separate operational act (T_Live chart
   work is OWNER-only; no AI seat performs it).

OWNER signature: Mission Control receipt `1a184219-1525-40fa-9f0c-0287833b2e4f`, 2026-09-14T13:45:21Z.
