# Governed MT5 terminal update runbook

## Purpose and authority

This runbook is the only supported QuantMechanica procedure for changing an
MT5 terminal build. Every terminal update creates a new evidence epoch: results
from different terminal/tester builds are not silently treated as identical.

An update requires an explicit OWNER window naming the seats. Research-seat
authority does not extend to T1-T10, T_Live, or FTMO. T_Live and FTMO always
require their own OWNER window. Agents never enable AutoTrading.

## Invariants

- Never rely on background LiveUpdate as the deployment mechanism.
- Never manually start `terminal64.exe` to trigger an update.
- Establish one verified golden copy before touching any target.
- Stop only the terminals named by the OWNER; never interrupt an active
  backtest. Factory seats require Factory OFF and an idle-process census.
- Copy only an explicit binary allowlist. Preserve `Bases/Custom`, `config`,
  `profiles`, `MQL5`, account state, and all history data byte-for-byte.
- Record `terminal64.exe` and `metatester64.exe` versions and hashes in every
  test receipt. `metaeditor64.exe` is included only if its golden hash differs.
- Retain a per-seat pre-update backup until the post-update identity and
  manifest checks are accepted.
- Re-arm the seat's update guard before any test launch.

## Preflight

1. Record OWNER decision, named seats, UTC window, operator, free RAM, process
   census, Factory state, AutoTrading state, and current file versions/hashes.
2. Refuse if a named seat has `terminal64.exe`, `metatester64.exe`, or a tester
   agent active; if an unnamed terminal would need stopping; or if free RAM is
   below the task's bound.
3. Select a golden terminal already on the target build. Hash the explicit
   allowlist (`terminal64.exe`, `metatester64.exe`, and only when needed
   `metaeditor64.exe`). Record file version, size, last-write UTC, and SHA-256.
4. Compare the golden terminal's custom-history signed manifest to the
   canonical manifest. This is an evidence check, not permission to copy
   history.
5. For each target, hash its protected roots (`Bases/Custom`, `config`,
   `profiles`) or record a deterministic inventory snapshot. Record the current
   binary hashes and the terminal profile `origin.txt` binding.
6. For a guarded research seat, use the exact guard tool in `Restore` mode and
   preserve its receipt. Inspect again before copying. Do not launch MT5.

## Golden-copy deployment

For each OWNER-named idle seat, one at a time:

1. Create a timestamped backup directory outside the terminal root. Copy the
   target's existing allowlisted binaries into it and hash the backup.
2. Copy each golden binary to a temporary file in the target root, hash the
   temporary file against the recorded golden hash, then atomically replace the
   corresponding target binary. Do not recursively copy a terminal directory.
3. Verify the installed version, size, and SHA-256 immediately. If any value
   differs, restore all allowlisted binaries for that seat from its backup and
   stop.
4. Recompute the protected-root inventory and the custom-history signed
   manifest. Any unexplained change is a stop condition and requires rollback.
5. Re-apply the research LiveUpdate ACL guard where applicable, then inspect it
   for zero pending payloads, an exact SYSTEM write deny, no whole-program
   firewall rule, and the correct `origin.txt` binding.

The vendor installer or a staged LiveUpdate payload may be used only when an
OWNER decision explicitly requires it and the payload is hash-pinned. It must
still operate on one idle named seat, preserve the protected roots, and pass all
of the same post-copy checks. Background polling is never acceptance evidence.

## Reference-cell reproducibility gate

1. Use the governed research controller, Model 4, the accepted reference EX5
   and setfile hashes, `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and
   `qm_news_stale_max_hours <= 336`.
2. The receipt must record both terminal and tester build/version/hash.
3. Compare native metrics and report hash inputs with the last accepted
   reference epoch. Any material mismatch stops rollout and is reported to the
   OWNER; it is never normalized away or used to overwrite earlier evidence.
4. Verify custom-history manifest identity again after the run.

## Fleet ceremony

Fleet rollout is a separate OWNER-authorized event:

1. Set Factory OFF and wait for T1-T10 to become idle without interrupting
   active tests.
2. Update one canary seat from the golden binary allowlist, complete the
   reference-cell gate, and hold for review.
3. Update remaining seats sequentially, verifying each receipt and protected
   roots. Never mutate T_Live or FTMO under fleet authority.
4. Re-enable Factory only after every intended seat has the same accepted
   terminal/tester build and hash pair, custom-history manifests verify, and
   the OWNER/orchestrator accepts the new evidence epoch.

## Rollback and evidence contract

Rollback restores only the allowlisted binaries from the named backup, verifies
their hashes and protected-root inventories, and re-arms all applicable update
guards. A rollback is itself a new evidence event.

The durable receipt must include: OWNER decision, window, seat and profile
identity, pre/post process census and free RAM, golden source, copied paths,
pre/golden/post/backup hashes and versions, protected-root inventory hashes,
custom-history manifest verification, guard receipts, tester journal evidence,
reference metrics, AutoTrading observation, and the final disposition. Earlier
receipts and verdicts are immutable.
