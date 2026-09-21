# Execution record — OWNER-DEC-FTMO-DEMO-ACCOUNT-GEN2-20260927 (task 90847e73)

Authority: `execution_contract_sha256 75fd4ed5cd750da378b358391b7714cb9224667762a4aeb710ef100d0c6acba0`
(OWNER receipt `46ea4491-29b0-4428-90d2-51d88abf447e`, choice **A** — fresh FTMO Free-Trial account).
Operator: Claude (headless orchestration cycle), read-only reconnaissance only per `implementation_mode: APPLY_AND_VERIFY`
gated on OWNER credential handover.

## Status: BLOCKED — awaiting OWNER credential handover

Checked, in order:

1. `.private/secrets/ftmo_demo_gen2_20260927.md` — **does not exist**. This is the OWNER-designated
   handover path per `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` §1 ("OWNER creates the
   Free Trial ... writes login, server and password into `.private/secrets/ftmo_demo_gen2_20260927.md`
   ... or names login + server in chat and puts only the password there"). Only the prior generation's
   file (`ftmo_demo_20260906.md`) is present in that directory.
2. `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` — `DEMO_ACCOUNT_IDENTITY` row confirms: "DECIDED A ...
   **Awaiting credentials**". No update since the OWNER decision was recorded (2026-09-21 ~19:55Z).
3. No login/server string appears in this session's conversation or task payload.

Every `allowed_action` in the task payload (retarget terminal / install second instance, verify
balance 100000.00 with zero positions/orders, bind identity into the genesis manifest, update
`FTMO_SUNDAY_LAUNCH_STATUS.md`/OPEN_ITEMS/Vault) requires a login and server to act on. None can be
performed against a real account without that input. No terminal, chart, preset, or T_Live
object was touched; `forbidden_actions` were not approached.

## What did not happen (explicit, per containment clause)

- No terminal retarget or second-instance install attempted.
- No genesis-manifest edit (the manifest that exists,
  `docs/ftmo/genesis/FTMO_DEMO_GENESIS_MANIFEST_FTMO_DEMO_BOOK_V3_D2G6_20260918.*`, is the current
  D2g6 generation and was not touched).
- No AutoTrading, order, or T_Live action of any kind.
- No credential was requested from or supplied in this chat channel; none is stored here.

## Required next input (unchanged from runbook §1 / status table)

OWNER creates a 100k 2-Step Standard MT5 Free Trial in the FTMO client area (human MFA — the one
step Fable cannot perform) and hands over login + server (via chat is fine) and password via the
existing secure channel — never into the repo, Vault, or a chat transcript. Deadline per runbook:
before Saturday 2026-09-26 12:00Z, else the Sunday 2026-09-27 launch slips a week (I7 in the
runbook's input table).

## Evidence

- `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` §1, §0 row I7
- `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` — `DEMO_ACCOUNT_IDENTITY` row
- `.private/secrets/` directory listing (this session): only `ftmo_demo_20260906.md` present,
  `ftmo_demo_gen2_20260927.md` absent
- No-change dedupe state hash: `5fc85435653641a4f2729c54f94dc22cdaf694682cfdafc1a4d1a99fc1bb12bd`
  (`D:\QM\strategy_farm\state\orchestration_no_change\claude\90847e73-4144-56a5-9cbd-77fc2da293f6\`)

## Recommended router state

`BLOCKED` — external human input required (OWNER FTMO client-area action), not an agent defect.
Re-run this task once `.private/secrets/ftmo_demo_gen2_20260927.md` exists; if the blocker facts
above are unchanged on a later check, no new timestamped evidence file is to be created (use the
dedupe helper).
