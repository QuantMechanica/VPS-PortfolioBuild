# M06 unchanged-identity consumer exception

RESULT: REVIEW. Router task `9f80f58c-2faa-4dfe-a35a-bd019771779f`. Isolated commit **`ebade2116d`**, branch `agents/codex-identity-consumer-exception-20260905`. **85 focused tests pass**. The flag is default off, no production consumer was enabled, no runtime pointer or freeze was written, and no T_Live path was accessed.

## Behavior

The new metadata consumer recognizes condition 1 only after revalidating the exact inert proposal against the current canonical pointer, freeze and source-tool bytes, the pointer's manifest, and the hash-bound observation. It recomputes all roster, binary, set-file and risk fingerprints using the existing proposal evaluator. Observation age is checked at proposal creation: 300 seconds is accepted, 301 seconds or a future observation is refused. The original proposal bytes must match a separate OWNER attestation in Mission Control. Proposal/observation schema changes and any later manifest-version or file-byte change refuse.

Pointer authentication exposes `identity_exception_enabled=False` and an explicit evidence context. The existing verifier wires that path to `--allow-attested-current-identity`, `--identity-proposal` and `--identity-attestation-receipt-id`. Enabled authentication still binds the caller's actual pointer object, manifest bytes, LIVE status and book; it cannot authenticate a different stamp using a valid proposal. Missing epoch fields remain UNKNOWN rather than receiving an invented activation time. Morning-brief parity is unchanged with the flag off.

The freeze mutation guard can report condition 1 SATISFIED through the same explicit context, while still raising `RiskFreezeBlocked` for an ACTIVE book. This distinction is required: satisfying one condition never authorizes a writer or a new-version activation. Other conditions and the explicit OWNER lift remain necessary. The durable freeze document is never modified. Metadata-only recognition does not open paths mentioned inside sleeve measurements or manifests; deployed-file validation remains a separate existing verifier responsibility.

## Exact receipt binding

The canonical Mission-Control ledger is the sole receipt source. The metadata CLI provides no alternate receipt-file option. A valid receipt must have the exact supplied receipt ID, occur once, use the current v2 receipt schema, have a valid canonical receipt checksum, be OWNER/YES, and be dated between proposal creation and consumption. The OWNER-visible card must bind the SHA-256 of the **raw proposal file bytes** with:

```
decision_id: OWNER-DEC-LIVE-IDENTITY-CURRENT-<64-character proposal SHA-256>
selected_effect: ATTEST_CURRENT_PROPOSAL_SHA256=<same SHA-256>;FREEZE=ACTIVE;NO_ACTIVATION
```

These fields fit the existing Mission-Control store; the selected effect comes from the card's YES effect, not user notes. This is a concrete receipt contract for the review round, not a receipt created by Codex. Policy receipt `70ec12e4-cff9-485a-a440-ed1f113b4b5c` authorizes implementation but cannot substitute for this distinct attestation.

For read-only metadata inspection after review, the isolated module `tools/strategy_farm/live_identity_consumer.py` accepts the same three flags as the verifier and prints a result; it has no write mode. With no enabling flag it performs no input reads and returns `IDENTITY_EXCEPTION_DISABLED`. A new proposal should bind the actual integrated source-tool bytes; changing that source after an observation correctly invalidates its binding.

## Verification and current evidence

Command from the isolated branch:

```
python -m pytest tools/strategy_farm/tests/test_live_identity_consumer.py tools/strategy_farm/tests/test_live_identity_attest.py tools/strategy_farm/tests/test_risk_freeze_prevention.py tools/strategy_farm/tests/test_verify_pointer_binding.py -q
```

**85 passed in 8.91 seconds.** Coverage includes disabled-path equality/laziness, an exact attested positive case, every bound-file byte hash, roster/binary/set-file/risk drift, observation age and version, manifest version, absent/duplicate/wrong-owner/NO/wrong-proposal/policy-only/corrupt/premature receipts, pointer caller drift, ACTIVE freeze write refusal, and the verifier's actual flag hook using fixture files. Fixture input bytes remain unchanged. `git diff --check` and Python compilation pass.

[Metadata audit](2026-09-05_m06_consumer_exception/metadata_audit.json) at 21:21:17Z records the policy YES, **zero separate hash-bound identity attestations**, the ACTIVE freeze and exact runtime metadata hashes. It read only D:/QM/reports/state metadata. No actual attestation acceptance or runtime rollout is claimed. [Implementation patch](2026-09-05_m06_consumer_exception/consumer_exception.patch). Code stays isolated; canonical evidence is committed on board-advisor for Claude+OWNER review.
