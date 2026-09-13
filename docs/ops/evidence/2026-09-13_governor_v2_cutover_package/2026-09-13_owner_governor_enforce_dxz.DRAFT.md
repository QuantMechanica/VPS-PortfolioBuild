# OWNER enforce order — account/portfolio governor v2, DXZ live book

**DRAFT — not an order yet.** This file is a draft under `docs/ops/evidence/`. It becomes an
order only when the OWNER commits it as `decisions/2026-09-13_owner_governor_enforce_dxz.md`
(exact filename; the adapter parses the name pattern `<date>_owner_governor_enforce_<venue>.md`
and refuses a future date). Prepared by the Claude seat 2026-09-13; no AI seat commits under
`decisions/`.

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

## The order line the adapter requires (must appear verbatim, on its own line)

GOVERNOR-ENFORCE: ACTIVATE DXZ 2026-09-13

## What this does NOT authorize

- **No AutoTrading toggle.** T_Live AutoTrading stays OWNER-only and is untouched.
- **No deployment, no risk change, no new live promotion.** `OWNER-DEC-RISK-FREEZE` stays ACTIVE;
  this order does not lift it and does not satisfy any other lift condition.
- **No level-1 enforcement.** Level 1 (`ENTRY_FREEZE_UNCERTAINTY`) is not expressible on the halt
  channel and is refused by the executor (`l1_entry_freeze_not_expressible_via_halt_channel`).
- **No level-2 enforcement by default.** The halt channel also flattens open positions, which is
  over-action for a level-2 entry freeze; it requires the separate, explicit
  `--allow-l2-flatten-overaction` flag. Level 3 is exact on this channel.
- **No clearing of a halt.** Lifting a halt needs its own OWNER artifact
  `decisions/<date>_owner_governor_halt_clear_dxz.md` with the line
  `GOVERNOR-HALT: CLEAR DXZ <date>`.

## Preconditions the OWNER should confirm before committing this

1. Monitor v2 is attached on T_Live and its `account_snapshot.json` reports schema **v2**
   (today it is `LEGACY_UNVERSIONED`, which pins the governor at level 1 by design).
2. The dry-run watcher `QM_StrategyFarm_GovernorDryRunWatch` has run against the v2 snapshot
   and reports a stable level with a reconciled order/position inventory.
3. The thresholds and their derivation in the bound policy are reviewed and accepted.

OWNER signature: ______________________  Date: ____________
