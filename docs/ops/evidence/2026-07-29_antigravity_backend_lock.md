# Antigravity backend lock

Date: 2026-07-29
Authority: OWNER

The persisted agent/lane key `gemini` remains a compatibility identifier only. Every
execution path behind that key resolves to Antigravity's `agy.exe` through the ConPTY
wrapper. The npm/Node `gemini-cli` executable and bundle fallbacks were removed; a missing
`agy` binary now fails loudly rather than reviving the deprecated client.

Receipts emitted by the orchestration wrapper include `execution_backend=agy`. Existing
task IDs, lane assignments, scope identities and the Credential Manager target remain
compatible. This change does not launch an agent, write the farm DB, or start the Factory.
