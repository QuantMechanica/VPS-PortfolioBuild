# OWNER signature block — governor v2 enforce cutover (DXZ 4000090541), 2026-09-13

Everything an AI seat can prepare is prepared and machine-verified. What remains are the three
OWNER acts below. Prepared by the Claude seat; read-only against T_Live, no chart attached, no
halt file written, no scheduled enforcement.

## What the OWNER signs, field by field

### 1. The threshold policy
File the OWNER accepts (byte-exact, do not edit — any edit changes the sha and voids act 2):

```
docs/ops/evidence/2026-09-13_governor_v2_cutover_package/account_governor_policy_dxz_4000090541_20260913.OWNER_SIGNED_CANDIDATE.json
sha256 = f2baf21a6282942cc99b82ce77caaf46a561247b188340d4e2f06851f01feb70
```

It is the `…PROPOSED.json` draft (sha256 `ad7070429ff26d948f9d6e40181ed6c1a7c7103c3df7235944b552122b15e401`)
with exactly three fields changed — thresholds and derivation are byte-identical:

| field | PROPOSED | signed candidate |
|---|---|---|
| `status` | `PROPOSED_OWNER_RATIFICATION_REQUIRED` | `OWNER_SIGNED` |
| `authorized_by` | `PROPOSED_BY_CLAUDE_ORCHESTRATOR_2026-09-13` | `OWNER (Fabian) 2026-09-13 -- decisions/2026-09-13_owner_governor_enforce_dxz.md` |
| `valid_from_utc` | `2026-09-14T00:00:00+00:00` | `2026-09-13T00:00:00+00:00` (so the policy is verifiable on the day it is signed) |

The signature is **not** a field inside the file. `account_portfolio_governor._load_bound_policy`
authenticates the policy by the sha256 the OWNER passes to `--trusted-policy-sha256`, plus
`status == OWNER_SIGNED`, `authorized_by` starting with `OWNER`, `account_login == 4000090541`,
and `now` inside `[valid_from_utc, valid_until_utc]`. **Naming the sha is the signature.**

Thresholds being ratified: `min_free_margin_account 68750.0`, `max_gross_leverage 7.5`,
`max_abs_currency_net_leverage 4.3`, `max_planned_stop_loss_account 3650.0`,
`stage2_cancel_pending_authorized true`, validity to `2026-12-14T00:00:00+00:00`.
Documented caveat carried over from the proposal: the Darwinex 1:30/1:15 swing margins behind
`max_gross_leverage` are still recorded UNVERIFIED.

### 2. The enforce-activation artifact
```
docs/ops/evidence/2026-09-13_governor_v2_cutover_package/governor_enforce_activation_dxz_4000090541_20260913.DRAFT.json
sha256 = 5ab3b819562a0504308434342744b1cd3d52c1e558267be8d520b34a9194fb41
```
Schema `qm.account-governor.enforce-activation/v1`. The adapter requires
`status=OWNER_SIGNED`, `authorized_by` starting with `OWNER`, `account_login=4000090541`,
a validity window containing now, `enforce_authorized=true`, `activation_decision_ref` non-empty,
and `trigger_policy_sha256` equal to the signed policy's sha — it is already bound to
`f2baf21a…`. Accepted the same way: `--trusted-activation-sha256 5ab3b819…`.

### 3. The decisions/ order
The OWNER commits `2026-09-13_owner_governor_enforce_dxz.DRAFT.md` from this package as

```
decisions/2026-09-13_owner_governor_enforce_dxz.md
```

Exact filename (the adapter's name pattern is `<date>_owner_governor_enforce_<venue>.md`, not
future-dated) and it must contain verbatim, on its own line:

```
GOVERNOR-ENFORCE: ACTIVATE DXZ 2026-09-13
```

If the OWNER signs on a later date, all three artifacts must carry that date (re-run
`make_governor_drafts.py` with the new `SIGN_DATE`; the shas change).

## The one operational act that is not a signature

**Attach the monitor v2 chart on T_Live** (`C:/QM/deploy/governor_v2_20260913/staging/QM_AccountMonitor.ex5`,
sha `f98523ee…`). Until then `account_snapshot.json` is `LEGACY_UNVERSIONED`, the governor is
pinned at level 1 `ENTRY_FREEZE_UNCERTAINTY` by design, and level 1 is not expressible on the
halt channel — so enforcement would refuse even with all three signatures in place.
T_Live chart work is OWNER-only; no AI seat performs it.

## The command, ready to run once the three acts are done

```
python -X utf8 tools/strategy_farm/account_governor_action_adapter.py --enforce \
  --policy     docs/ops/evidence/2026-09-13_governor_v2_cutover_package/account_governor_policy_dxz_4000090541_20260913.OWNER_SIGNED_CANDIDATE.json \
  --trusted-policy-sha256     f2baf21a6282942cc99b82ce77caaf46a561247b188340d4e2f06851f01feb70 \
  --activation docs/ops/evidence/2026-09-13_governor_v2_cutover_package/governor_enforce_activation_dxz_4000090541_20260913.DRAFT.json \
  --trusted-activation-sha256 5ab3b819562a0504308434342744b1cd3d52c1e558267be8d520b34a9194fb41 \
  --executor halt-file \
  --enforce-order decisions/2026-09-13_owner_governor_enforce_dxz.md \
  --enforce-venue dxz
```

Level 2 additionally needs `--allow-l2-flatten-overaction` (the halt channel has no
entry-freeze-only mode). Level 3 is exact on this channel.

## Proof that nothing else is missing

`adapter_dry_run_refusals_20260913.json` in this package records the adapter probes run on
2026-09-13 with these draft artifacts. With policy + activation + a correctly named order +
`--executor halt-file` all wired, the adapter reached the executor and refused only with
`l1_entry_freeze_not_expressible_via_halt_channel` — the monitor-v1 level-1 state, not a missing
authorization. No halt file was written; the probe used a scratchpad halt directory.
