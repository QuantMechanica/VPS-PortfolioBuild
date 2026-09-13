# Freeze condition 1 (SP-A1/A2) — the identity route, and the exact OWNER act left

Prepared by the Claude seat 2026-09-13. Read-only against T_Live; no pointer write, no freeze
mutation, no AutoTrading. Freeze `OWNER-DEC-RISK-FREEZE` stays ACTIVE throughout.

## Why the signing route is a dead end without a lift (proven)

`generate_live_deployment_pointer.py --signed` calls
`risk_freeze.assert_live_book_mutation_allowed("mint a signed T_Live deployment pointer")`
(generate_live_deployment_pointer.py:222-225) **without** the identity-exception arguments, and
the guard refuses on an ACTIVE freeze. Verbatim refusal captured 2026-09-13:

```
LIVE_RISK_FREEZE_BLOCKED: operation=mint a signed T_Live deployment pointer; status=ACTIVE;
held=True; drift=none; lift_rule=All three conditions met AND an explicit written OWNER lift. ...
```

So condition 1 cannot be met by minting while the freeze is ACTIVE, and the freeze cannot be
lifted until condition 1 is met. That circle is real — but it is not the only route.

## The route that does not need a lift

`live_deployment_pointer_auth.authenticate_deploy_stamp(..., identity_exception_enabled=True)`
returns `RANK_OK / OWNER_ATTESTED_CURRENT_IDENTITY` when the OWNER has attested the *unchanged*
current book. That satisfies condition 1's operative half — "consumers read authenticated instead
of UNKNOWN" — with the pointer left unsigned, the roster untouched, and the freeze ACTIVE.
`verify_live_deployment_contract.py --allow-attested-current-identity` is already wired to it
(verify_live_deployment_contract.py:674-690, 1620-1625).

## What was executed today

1. **Fresh read-only observation** (`risk_freeze.measure`): `ok=true`, 24 sleeves, 21 binaries,
   total RISK_PERCENT 9.7499, `problems=[]`.
   `observation.json` sha256 `71079fc6b42cbedef50915d530ba5dec46bfd53e56d9988204a14a680e8b851d`
2. **Inert attestation proposal** (`--attest-current --write-proposal`), observation age 0.03 s:
   `proposal/proposal.json` sha256
   `6e7e0b981ed1ee2533b5ce153e9ba62a5b4aa5d08e98914683b4c07934200863`,
   status **ELIGIBLE_FOR_OWNER_REVIEW**, `failures: []`, every observed fingerprint identical to
   the frozen baseline (roster `b4833cbf…`, binary `5f42b74e…`, setfile `d70994e3…`,
   risk `8132b3e6…`), `freeze_status: ACTIVE`, `signed: false`, `runtime_pointer_write: false`.
3. **Consumer authentication attempt** against the standing OWNER attestation receipt
   `510a2922-3519-4cd9-bcf1-32b812e16cb7` — refused with exactly one reason:
   `RECEIPT_NOT_OWNER_ATTESTATION_OF_THIS_PROPOSAL`.
4. **`verify_live_deployment_contract.py`** with the flag: pointer binding `MISMATCH` rank 3,
   single reason `IDENTITY_ATTESTATION_REFUSED: RECEIPT_NOT_OWNER_ATTESTATION_OF_THIS_PROPOSAL`.
   Without the flag it reads `UNKNOWN` rank 1 (`SIGNED_NOT_TRUE`, `APPROVED_BY_MISSING`) —
   the exact UNKNOWN that condition 1 names.

## Why the 2026-09-06 attestation does not carry

The OWNER did already attest on 2026-09-06 (receipt `510a2922…`, decision
`OWNER-DEC-LIVE-IDENTITY-SIGN-20260905`). Two independent reasons it cannot be consumed:

- **Proposal staleness.** The 09-05 proposal binds `risk_freeze.py` at sha `df6d44e0…`; the file
  is now `1bfa26d0…` (LIFT_CONDITIONS prose was edited 2026-09-13). `load_context` re-reads the
  bound source tool every time, so that proposal is permanently void. Hence today's re-mint.
- **Receipt shape.** `live_identity_consumer.evaluate` demands a machine-readable receipt:
  `decision_id == "OWNER-DEC-LIVE-IDENTITY-CURRENT-<proposal_sha256>"` and
  `selected_effect == "ATTEST_CURRENT_PROPOSAL_SHA256=<sha>;FREEZE=ACTIVE;NO_ACTIVATION"`.
  The 09-06 card was written in German prose with a date-based decision id, so it misses on both
  fields. The consumer was implemented stricter than the card the OWNER signed.

## The one OWNER act that remains

One Mission-Control decision card, decided YES by OWNER, recorded in
`D:\QM\reports\state\owner_decision_receipts.jsonl` with these exact field values:

```
decision_id     = OWNER-DEC-LIVE-IDENTITY-CURRENT-6e7e0b981ed1ee2533b5ce153e9ba62a5b4aa5d08e98914683b4c07934200863
selected_effect = ATTEST_CURRENT_PROPOSAL_SHA256=6e7e0b981ed1ee2533b5ce153e9ba62a5b4aa5d08e98914683b4c07934200863;FREEZE=ACTIVE;NO_ACTIVATION
decided_by      = OWNER
decision        = YES
decided_at_utc  >= 2026-09-13T16:34:27+00:00 (the proposal's created_at_utc) and <= now
schema          = qm.owner-decision-receipt/v2
```

What the OWNER is attesting: that the 24-sleeve book running on T_Live today is the unchanged
book the freeze baseline describes. It signs no pointer, writes no runtime file, changes no risk,
authorizes no activation and does not touch AutoTrading.

Then, with no further OWNER involvement:

```
python -X utf8 tools/strategy_farm/live_identity_consumer.py --allow-attested-current-identity \
  --identity-proposal docs/ops/evidence/2026-09-13_m06_attest_current/proposal/proposal.json \
  --identity-attestation-receipt-id <new receipt_id>
python -X utf8 tools/strategy_farm/verify_live_deployment_contract.py \
  --manifest D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json \
  --allow-attested-current-identity \
  --identity-proposal docs/ops/evidence/2026-09-13_m06_attest_current/proposal/proposal.json \
  --identity-attestation-receipt-id <new receipt_id>
```

## Sequencing warning

The proposal binds `tools/strategy_farm/risk_freeze.py` byte-for-byte. **Any** edit to that file —
including updating the `LIFT_CONDITIONS` status prose — permanently voids this proposal and forces
a re-mint plus a new OWNER card with a new sha. Land the LIFT_CONDITIONS text edit **first**, then
re-mint, then attest. Re-minting is one command (the observation + proposal step above) and needs
no OWNER involvement.
