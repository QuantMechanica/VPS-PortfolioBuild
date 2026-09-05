# M06 — current-book identity attestation (INERT, REVIEW)

Task `ebe10705-7b35-4ea3-a239-77b4afb500a6`. Code commit `ba221f9c4f` on `agents/codex-identity-attest-20260905`; integration belongs to Claude+OWNER. The new explicit `--attest-current` mode creates unsigned proposals. It never signs or writes the runtime pointer, changes the freeze, or accesses T_Live. The current-book proposal is **REFUSED: FRESH_BOUND_OBSERVATION_MISSING**. This is a completed proposal-path implementation, not an authenticated deployment claim.

## State contract

The current freeze requires an authenticated signed pointer as condition 1, while the legacy signed writer requires an explicit lift. That cycle is real: `risk_freeze.py:430` checks the freeze; `generate_live_deployment_pointer.py:223` calls it before a signed write. Neither guard was weakened.

| Freeze / pointer state | Requested transition | Result and authority |
|---|---|---|
| ACTIVE / current unsigned pointer | Diagnose unchanged current book | New INERT proposal, freeze remains ACTIVE |
| ACTIVE / complete fresh byte-identical observation | Attest-current proposal | ELIGIBLE_FOR_OWNER_REVIEW, signed=false; no runtime effect |
| ACTIVE / missing, stale or drifting observation | Attest-current proposal | REFUSED, reason recorded; freeze remains ACTIVE |
| ACTIVE / proposed composition or risk change | Sign or activate | Existing guard blocks; no exception added |
| ACTIVE / OWNER-approved identity proposal | Authenticate current identity | Separate future Mission-Control ceremony and consumer decision; not implemented or authorized here |
| ACTIVE / all three conditions evidenced | Lift freeze | Separate explicit OWNER lift; never inferred from an attestation |
| LIFTED / signed pointer | New version activation | Separate existing deployment ceremony; not part of this task |

The proposed future exception concerns identity evidence for the already deployed book only. A version change still requires the full activation ceremony. Merely signing an identity proposal does not satisfy consumer authentication, news contract or governor enforcement.

## Implementation and evidence

`generate_live_deployment_pointer.py:193` dispatches only the explicit flag to a separate parser. That parser rejects legacy signing/output arguments. `live_identity_attest.py:53` independently hashes roster membership, binary bytes, setfile bytes and the risk vector. `:79` binds the manifest, frozen baseline and existing pointer, including account, server/phase completeness, per-sleeve binary hashes, risk expectations and aggregate fingerprints. `:152` defaults to printing only; its sole write operation creates proposal.json and receipt.json in a new canonical evidence child. Input byte hashes are rechecked before output. Reparse aliases and T_Live paths are refused.

The observation contract is `qm.live-identity-observation/v1`: `source_tool=risk_freeze.measure`, the canonical source-tool SHA256, manifest/pointer/freeze byte SHA256s, captured_at_utc, and the complete measurement. Its file SHA256 must be supplied separately. It must be at most 300 seconds old and not future-dated. Every observed fingerprint must match the frozen baseline. This hash-bound observation is still evidence for human review, not a cryptographic assertion of who captured it. An authorized independent capture and provenance review remain necessary before any ceremony.

The task excludes T_Live access, so this run did not recapture live binaries or presets. D:/QM metadata alone cannot prove their current bytes. The 24-sleeve manifest, pointer metadata and refreshed freeze baseline are internally consistent; the actual proposal correctly refuses eligibility because no fresh detailed observation exists. The prior freeze-status report is neither fresh nor a complete measurement and was not repackaged as one.

Artifacts: `2026-09-05_m06_identity_attest_proposal/reviewed/{proposal,receipt}.json` and `verification.json`. The directory also retains the initial pre-final-path-check run. Both CLI default dry-run and explicit proposal-only write returned exit 2 with exactly the missing-observation reason. All three D:/QM inputs retained their exact byte hashes; freeze remained ACTIVE and pointer unsigned. JSON bytes are protected from checkout newline conversion by the local .gitattributes.

Validation: **58 tests passed**, including existing freeze/pointer regressions; **28 focused tests passed again** after the final lexical-path check. Tests use real temporary preset/binary fixture bytes and cover successful unsigned proposals, each identity dimension, all input hash bindings, stale/future observations, malformed risk, account/aggregate drift, missing evidence, T_Live/alias refusal, legacy argument rejection, no legacy writer invocation, no default writes, receipt hash binding and no input mutation. Existing unrelated Python escape warning only.

The G:/Drive audit file was unavailable to the headless account. The routed specification and local code/state establish the findings above. The OWNER Vorlage is stored under canonical evidence, as required by the scheduled cycle, rather than the payload's general docs/ops location. No production integration, freeze lift, live deployment or purchase occurred.
