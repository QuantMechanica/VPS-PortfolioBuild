# OWNER Vorlage — M06 identity attestation proposal

Status: **INERT / NOT SIGNED / NOT ACTIVATED**. Review artifact: `2026-09-05_m06_live_identity_attest.md`; code `ba221f9c4f`.

The signed-pointer prerequisite and the ACTIVE-freeze signing guard form a circular dependency. The proposed resolution is a narrowly scoped future ceremony that authenticates the unchanged current book while preserving ACTIVE. The new CLI implements only its unsigned evidence preparation. It does not implement that ceremony or change current consumers.

Current evidence outcome: REFUSED because no fresh independent observation was available under this task's no-T_Live-access constraint. There is no eligible real-book attestation to sign yet.

Before a future decision, an authorized operator captures the complete risk_freeze.measure observation outside T_Live, binds it to the current manifest, pointer, freeze and source-tool hashes, records capture provenance, and evaluates it within 300 seconds. Review must confirm identical roster, binary, preset and risk hashes and unchanged input hashes. A copied baseline is not an observation. Any drift aborts this path and requires the ordinary change process.

OWNER decisions, to be recorded on the existing Mission-Control card:

1. Accept or reject the fresh current-identity evidence and its independent provenance.
2. If accepted, authorize the precise identity-only signing ceremony and define how consumers authenticate it without authorizing composition/risk changes. Review that separate implementation before execution.
3. Decide whether freeze condition 1 is satisfied by the resulting consumer evidence. Do not infer satisfaction from the signature alone.
4. Decide any freeze lift separately, only after all three conditions are evidenced. News and governor conditions remain independent.
5. Treat any new-version activation as a separate ceremony after the required authority exists.

This Vorlage grants no authority. Purchase, AutoTrading and live changes remain outside this task. Canonical integration is exclusively a Claude+OWNER close-out.
