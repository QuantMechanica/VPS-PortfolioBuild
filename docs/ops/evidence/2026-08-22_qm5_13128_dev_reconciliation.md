# QM5_13128 development reconciliation and OWNER draft

Date: 2026-08-22  
Router task: `a18eb6cf-f3d7-49f5-8662-381b839b00c9`  
Scope: development only; no deploy or T_Live mutation  
Disposition: `CANDIDATE_SOURCE_READY_COMPILE_HELD`

## Reconciled proposed contract

The one consistent proposed state is:

- mechanical NDX.DWX H1 pre-FOMC drift, entry at broker hour 21 on D-1;
- mandatory flat-before-statement exit at broker hour 20 on the event date;
- the OWNER-ratified event-anchored news exemption: `OFF/NONE/OFF`, not the
  inconsistent legacy Q10 `PRE30_POST30/DXZ` pair;
- eight official 2026 meeting dates with explicit validity through 2026-12-31;
- INIT and entry fail closed beyond the validity horizon;
- fixed-risk requalification only: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- no deployment until the current registry blocks, pipeline proof, and an
  OWNER-signed manifest are all closed.

The exemption is narrow and already ratified in
`decisions/2026-07-24_news_blackout_exemptions.md`. It does not waive news risk
generally. Its compensating control is the strategy's mechanical event-date
exit before the statement. The old Q10 set used an active framework blackout
that can return before the exit path; its result must not be reused for this
candidate.

The approved card still says the compiled table ends in 2025. The proposed
2026 extension therefore remains an explicit OWNER card-amendment item in the
draft; this task does not silently rewrite the approved card or clear the
registry's `REQUAL_REQUIRED/BLOCKED` markers.

## Candidate and hashes

Commit `4112f5b07` contains:

| Artifact | SHA-256 |
|---|---|
| MQ5 source | `4e6e18c1967ae802aa31190b7ca75329eb451ddee88706f8f1dd546506172d25` |
| Development reconciliation set | `d0a3fa0b0a9bebca8fe6c0631ee6d64fdc1fe930ea401fc47b6c49f5c880c614` |
| Candidate EX5 | **unset — governed compile is activation-held** |

The new set is separate from the nine setfiles already modified by the earlier
governed compile worker. Those concurrent/generated changes were preserved and
not included in this commit.

Source changes are contract-preserving except for observability/hardening:

- direct MAE tracking is first in `OnTick`;
- the entry request is explicitly zero-initialized;
- the bounded D1 readiness count has its reviewed performance annotation;
- structured diagnostics identify calendar membership, ATR/quote/stop failures,
  entry readiness, order results, and the event-date close result;
- `INIT_OK` identifies the event-anchored exemption and flat-before-statement
  invariant.

## Governed build state

The previous DL-089 compile utility row `3077b39c…` failed on source hash
`e2bd93…`. Its 100 compiler messages were cascading infrastructure errors after
the claimed T6 include tree lacked `Include/Trade/Trade.mqh`; its independent
hardening findings were also fixed by this candidate.

After commit, an append-only governed compile request was created:

- work item: `3c893190-0297-4efb-b810-ad7f602ff63d`;
- state: pending;
- hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- no compile or pipeline verdict exists;
- no Q02 row is created until that utility succeeds.

The hold was not bypassed or released. The OWNER draft JSON therefore leaves
`candidate.ex5_sha256` null and is mechanically non-deployable.

## Seven-point minimum requalification proof

1. **Exact build binding.** Governed compile evidence must bind the MQ5 hash
   above to an EX5 hash. The candidate-set hash must be copied unchanged into
   every downstream receipt.
2. **Known-event replay.** Q02 must replay a known 2026 meeting (prefer
   2026-07-29) and show `ENTRY_GATE_DIAGNOSTIC`/`ENTRY_GATE_READY` on D-1,
   `FOMC_ENTRY_ORDER_RESULT open_ok=true`, and an event-day
   `FOMC_FLAT_EXIT_RESULT close_ok=true` on the exact binary/set pair.
3. **Broker 20/21 boundary probe.** Using real NDX.DWX ticks and the tester's
   recorded server time, prove an executable H1 boundary exists at entry hour
   21 and exit hour 20. Convert the official statement time to broker time for
   that date. Fail the proof if the first executable close tick is at or after
   the statement/blackout boundary.
4. **Per-gate evidence.** Receipts must retain calendar key/membership,
   position state, new-H1-bar reachability, D1-history readiness, ATR, quote,
   stop distance, exemption identity, and entry/exit order result. Missing
   diagnostics are an evidence failure, not assumed PASS.
5. **News semantic regeneration.** All Q02–Q10 evidence is rerun under
   `OFF/NONE/OFF`, justified only by the ratified event-anchored exemption. The
   prior `PRE30_POST30/DXZ` Q10 is explicitly stale for this candidate.
6. **Horizon proof.** A tester start after 2026-12-31 must fail initialization
   or entry with `SETUP_DATA_STALE`; no event-table inference or date guessing
   is allowed. Annual table extension requires a new reviewed build.
7. **Authority boundary.** Only pipeline evidence supplies the requalification
   verdict. Deployment additionally requires an OWNER-signed manifest pinning
   EX5, setfile, calendar/card amendment, evidence, and rollback hashes, followed
   by separate read-only deploy verification with AutoTrading off.

## OWNER manifest template

The machine-readable draft is
`docs/ops/evidence/2026-08-22_qm5_13128_dev_reconciliation_owner_draft.json`.
It already pins the source/set candidate and the read-only current-live rollback
reference:

- current live EX5: `364867a9fe8d58478ade5526aad19deb377a35b313cfdac29763bb2eb82d273b`;
- current live set: `3aa27e4b869a4f1e0dac25457d3c5056664613e58e3b41556b78a5db18549ffb`.

It remains `DRAFT_BLOCKED`, with `deploy_authorized:false`,
`autotrading_authorized:false`, a null EX5 hash, null OWNER signature, and the
existing registry block reasons retained.

## Focused verification

```text
python -m pytest tools/strategy_farm/tests/test_qm5_13128_dev_reconciliation.py tools/strategy_farm/tests/test_build_guardrails.py -q
23 passed in 0.93s
```

`build_gate_hardening.py` returned zero failures, including the direct MAE,
request initialization, and exact NDX.DWX registry checks.
`validate_build_guardrails.py` returned PASS for both source and candidate set.
`git diff --check` passed (line-ending notice only).

No terminal was started, stopped, or interrupted. T_Live files, profiles,
positions, and AutoTrading were not modified. This is not a pipeline verdict or
deploy approval.
