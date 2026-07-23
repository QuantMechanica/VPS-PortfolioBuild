# DXZ Q8 target-build preflight — 2026-07-16

Status: **BLOCKED / NO BUILD AUTHORITY**  
Runtime effect: **NONE**  
Builds launched: **0**  
Backtests launched: **0**  
T_Live mutations: **0**

OWNER direction received in chat: **RECORDED / UNSEALED**. It confirms that
the human OWNER has no remaining objection to continued in-scope preparation.
Because it contains neither the exact artifact hashes nor the required OWNER
approval and Research/Quality-Business/Quality-Tech reviews, it is not represented
as a Card-v2, build or framework approval.

This is the mandatory `qm-build-ea-from-card` preflight for the two proposed
Q8 extensions. It records why Development must not compile either repaired
variant yet. A general instruction to continue work is not a substitute for
the role-specific, hash-bound approvals required by the Cards.

## 12567 / XNGUSD.DWX / D1 / C_XNG_BASE35_POLICY

Result: **BLOCKED**.

Checks that pass:

- the existing EA folder and source use slug `cum-rsi2-commodity`;
- the XNG D1 magic allocation exists at slot 2 / magic `125670002`;
- the existing Base-35 test set declares XNG, D1, slot 2 and threshold 35;
- the ablation predeclaration and its SHA-256 sidecar are intact.

Blocking checks:

- no canonical, approved Card-v2 exists for the exact four-part target;
- the approval request is `IN_REVIEW / BUILD BLOCKED`, with OWNER approval and
  Research/Quality-Business/Quality-Tech reviews pending;
- the execution registry has no exact `variant_id=C_XNG_BASE35_POLICY` row and
  explicitly blocks the current unqualified variant;
- the current binary implements fixed Friday-close behavior, not the proposed
  session-aware no-weekend contract;
- `ea_id_registry.csv` has duplicate active 12567 rows without a visible
  OWNER-approved exception record;
- the five-digit ID and 18-character slug conflict with the ranges stated by
  the current build skill and therefore require an OWNER-approved registry
  exception or a Development repair;
- the SPEC's referenced source directory and a canonical EA-local Card are
  absent.

The approval draft's old `variant_id: XNG_BASE35` discrepancy was repaired in
this preflight: every proposal reference now names only
`C_XNG_BASE35_POLICY`. This normalization grants no approval.

## 1556 / XAUUSD.DWX / D1 / C_POLICY_REPAIR

Result: **BLOCKED**.

Checks that pass:

- EA ID 1556 and slug `aa-zak-mom12` have an active registry allocation;
- XAU D1 magic allocation exists at slot 4 / magic `15560004`;
- folder, source, set header, symbol and timeframe agree;
- the policy-repair predeclaration and its SHA-256 sidecar are intact.

Blocking checks:

- the legacy Card says `g0_status: APPROVED` while its source artifact also
  describes itself as draft/PENDING; no adequate Card-v2 approval trail is
  present;
- the `C_POLICY_REPAIR` packet is explicitly `IN_REVIEW`, with OWNER approval
  and Research, Quality-Business and Quality-Tech reviews pending;
- reuse of EA ID 1556 for the material policy change is not OWNER-approved;
- the execution registry has no exact `variant_id=C_POLICY_REPAIR` row and is
  `BLOCKED`;
- current MQ5, EX5 and XAU set are legacy artifacts, not the repaired policy;
- the parallel Master-EA module duplicates the legacy semantics and needs an
  OWNER-authorized sync-or-disable disposition with Quality-Tech review.

## Work allowed while builds remain blocked

Development may improve generic, read-only qualification tooling outside EA
source and framework includes. In particular, the isolated Target runner may
capture and hash-bind fresh tester-agent logs so existing `ENTRY_ACCEPTED`,
`TM_CLOSE` and `EQUITY_SNAPSHOT` evidence is no longer discarded. That work
must not mark daily MTM complete because the current runtime lacks initial and
final snapshots, and it cannot synthesize intraday MTM or margin evidence.

This allowed tooling work is now implemented and regression-tested. It also
binds the manifest-authoritative Magic and makes the Pair-Gate reverify all four
runtime artifacts—the captured log, parsed telemetry, transaction marker and
canonical Q08 stream—physically and reconstruct all claimed complete axes from
their content. Telemetry and Q08 enrichment are re-derived from the raw log,
and a non-bijective Q08/log join now fails already at the Target single-run
boundary. It grants no Card, build, pipeline or deployment approval and does
not change either target's blocked build status.

## Required hand-off before Development may build

1. Approve one exact Card-v2 for each target and bind its content hash.
2. Record the role-specific Card, no-weekend, ID-reuse/grandfathering and
   Master-module decisions.
3. Add exact four-part execution-registry rows.
4. Only then implement the Card-authorized EA/set changes and run strict
   compile. Pipeline phases and backtests remain a separate, later action.
