# FTMO Rulepack V2 evidence-chain coherence — 2026-09-04

Router task: `a4fb4108-4da7-46c3-830f-97c0dd45d4b6`  
OWNER decision: `OWNER-DEC-FTMO-RULEPACK-COHERENCE-20260904`  
Receipt: `decisions/2026-09-04_owner_receipts_briefing_2_4.md`

## Result

The authorized evidence-chain repair is implemented and remains research-only:

- Minted `docs/ops/evidence/2026-09-02_ftmo_official_rules_snapshot.json` in the evaluator's required `qm.ftmo-official-rules-snapshot/v1` schema.
- Snapshot identity: SHA-256 `d055f71cd2f4c094928a3b19861f0a4ae29654718808117a44458963e9c3d7f8`.
- The snapshot preserves the 2026-09-02 retrieval instant, incorporates the economic facts field-for-field from the separately sealed economic-terms snapshot, and binds every normalized claim to one or more named official-provider sources.
- The 2026-09-02 raw response bodies were not retained. Byte counts, response hashes, and Last-Modified values are therefore `null`; none were reconstructed or invented. The limitation is explicit in the snapshot envelope.
- Rulepack `FTMO_2S_100K_SWING_V2` now binds all seven source records to that official-rules snapshot. Its LF raw SHA-256 is `042fbcf9d7fd5c520473c6715200f22706b34cd036ba4d3d8d87228890ea5924`; canonical SHA-256 is `5505a56dc22fc463c852f13f11de534179b0165d2bf849bc2bb90900caf159d2`.
- The standalone evaluator now pins profile version 2, `as_of=2026-09-02`, the new snapshot/path/SHA, the Rulepack V2 raw SHA, the complete V2 normalized-claim set, and exact field-level provenance.
- FTMO Q02/standalone preparers and isolated-work-item source scopes now point at the same snapshot. Program-status and dossier canonical pins were advanced with the rulepack identity.
- `.gitattributes` pins both the new snapshot and Rulepack V2 to LF so their byte identities are stable across checkouts.

No FTMO rule or evaluation threshold changed. No purchase, deployment, `T_Live`, terminal, or AutoTrading action was performed.

## Source verification boundary

The normalized rule facts were checked against the official FTMO origins on 2026-09-04. This check corroborates the sealed 2026-09-02 normalized record; it does not backfill unavailable 2026-09-02 response bytes. Economic component provenance remains bound to:

- `https://ftmo.com/en/2-step-challenge/`
- `https://ftmo.com/en/scaling-plan/`
- `https://ftmo.com/en/trading-symbols/`

The rule snapshot also names the exact official Trading Objectives, news, weekend, EA-policy, and forbidden-practices origins used by the rulepack.

## Verification

- `python tools/strategy_farm/target_rulepacks.py` — PASS; V2 canonical SHA-256 `5505a56dc22fc463c852f13f11de534179b0165d2bf849bc2bb90900caf159d2`.
- Focused evaluator, Q02 preparer, standalone preparer, and isolated-runner suite — `176 passed`.
- The evaluator test suite includes fail-closed mutation tests for source paths/SHA, profile/as-of, normalized claims, and field-level claim provenance.

Verdict: **REVIEW — authorized implementation complete; Claude/OWNER close-out remains required.**
