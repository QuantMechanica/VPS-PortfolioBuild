---
title: Portfolio and T6 Deployment
owner: OWNER
last-updated: 2026-07-22
---

# 03 — Portfolio and T6 Deployment

No research, build, smoke, or intermediate phase approval implies deployment
permission. Deployment is an exact-artifact operation authorized by OWNER.

## Preconditions

- all prescribed test phases are PASS on version-bound evidence;
- the execution contract is complete and approved;
- the portfolio constraints and live-risk allocation are recorded;
- an OWNER-signed deploy manifest names source, binary, setfile, symbol, timeframe,
  magic, hashes, target terminal, and rollback artifact;
- T6/T_Live verification follows the active live runbook with AutoTrading off.

## Steps

1. Verify the manifest signature and every referenced hash.
2. Confirm the target terminal and account; reject any T1-T5/T_Live path ambiguity.
3. Capture pre-deploy terminal, process, file, chart, EA, magic, and AutoTrading
   state read-only.
4. Apply only the manifest-authorized copy/configuration actions.
5. Verify deployed hashes and configuration with AutoTrading off.
6. Record the result. Enabling trading is a separate OWNER action.

## Exit

- **Verified:** exact artifacts are present and the read-only verification bundle
  matches the manifest.
- **Rejected:** any hash, target, account, configuration, or evidence mismatch
  stops the deployment without substitution.
- **Rollback:** use only the manifest-bound rollback procedure and OWNER authority.
