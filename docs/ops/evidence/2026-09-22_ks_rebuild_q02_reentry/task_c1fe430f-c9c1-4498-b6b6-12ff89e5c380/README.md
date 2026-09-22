# KS rebuild Q02 re-entry blockers — task c1fe430f

## Disposition

REVIEW. The QM5_10403 provenance defect has a fail-closed code fix and exact,
hash-bound supplemental authority, but the append-only Q02 and identity proof
remain **NOT RUN** until this worktree commit is integrated into the canonical
checkout. QM5_10706 remains **NOT_EQUIVALENT** on its base-preset control and
the D2g6-selected ablation-02 predecessor remains unbindable from retained
evidence. Nothing in this artifact authorizes deploy, evidence inheritance, a
pipeline verdict, or a proof-contract change.

| EA | Result | Consequence |
|---|---|---|
| QM5_10403 | Exact supplemental parameter authority implemented and tested; canonical Q02/proof not run | Integrate this commit, then run the dry-run/apply Q02 successor and identity proof |
| QM5_10706 | Selected predecessor EX5 cannot be authenticated; base control remains NOT_EQUIVALENT | Keep selected identity blocked; use a fresh selected-preset Q02 and its own Q03-Q10 chain |

## QM5_10403 — immutable supplemental authority

Canonical `farmctl requalify-q02` currently refuses predecessor
`d02bec84-87fe-43a9-94d4-2795ec46cea7` with
`parameter_change_provenance_not_authenticated`. The completed compile receipt
`98873ebc-8231-4eb5-850a-e7f00d9b3598` freezes the original authority file at
SHA-256 `065a0cd3...`; adding a `registrations` array directly to that file would
invalidate the receipt and cannot authenticate it retroactively.

The patch therefore adds a supplemental-authority contract to `farmctl.py`.
It accepts no wildcard and binds all of the following before the existing Q02
append-only path can proceed:

- source Q02 work item `d02bec84-87fe-43a9-94d4-2795ec46cea7`;
- compile work item `98873ebc-8231-4eb5-850a-e7f00d9b3598`, compile-evidence
  SHA-256 `b4803818...`, EX5 `88ba0eab...`, and MQ5 `65d4c206...`;
- the original frozen authority path/hash;
- source setfile `9a6fab05...`, current setfile `61c7fe83...`, symbol/timeframe,
  and every one of the 12 semantic parameter differences;
- the supplemental document path/hash itself.

The authority document is
[qm5_10403_parameter_change_authority.json](qm5_10403_parameter_change_authority.json).
The complete requalification test file passes (11 tests), including positive
authentication and a fail-closed mutation of the current setfile hash. A direct
read-only call against the real compile receipt returns
`parameter_change_provenance_authenticated` with schema
`qm.q02-parameter-change-authority/v2`.

No canonical mutation was attempted: the task explicitly prohibits writes to
`C:/QM/repo`, while the live controller imports from that checkout. Therefore
there is no new Q02 row and no honest `EQUIVALENT_EXACT`/`NOT_EQUIVALENT` proof
result for 10403 in this cycle. After integration, the governed sequence is the
same pinned predecessor: canonical dry-run, canonical append-only apply, wait
for its terminal Q02 evidence, then run and verify the identity proof.

## QM5_10706 — selected preset binding

The selected predecessor `7cf004b7-f4cf-42cb-80cc-d5c98f119ce4` is a real
Q02 PASS for the ablation-02 set, but its database row has NULL EX5, MQ5, and
setfile hashes and its payload has none of the accepted EX5 identity fields.
Its retained summary, report, and tester.ini contain no binary digest.
`farmctl requalify-q02 --dry-run` consequently refuses with
`source_ex5_sha256_missing` before enqueue.

Two binaries are historically plausible: `01e34b20...` was the repository
binary before the run, while `2f461f6b...` was committed shortly afterward;
an inventory records the EX5 mtime at the exact run start. That is useful
forensics, not a cryptographic binding. Selecting either hash would manufacture
lineage, so no governed bind was made.

The D2g6 manifest itself is unambiguous: its selected source is
`QM5_10706_tv-mon-ls_GBPUSD.DWX_H1_backtest_ablation_02.set`, sealed there as
source SHA-256 `056f2c12...` and strategy identity `8182d0ff...`; the live
package output is `QM5_10706_GBPUSD_H1_live_trial.set` and its package binary is
`eaffda6f...`. The base set is only a diagnostic control and cannot replace the
selected-preset proof. Exact bindings are in
[qm5_10706_timing_analysis.json](qm5_10706_timing_analysis.json).

## QM5_10706 — deal 15 mechanism and live consequence

The two governed Model=4 base-control reports were re-parsed, without starting
a terminal. Of 303 deal rows, exactly one timestamp moves: deal 15, an **exit**,
from `2018.09.12 13:03:44` to `13:03:47` (+3 s). All 151 entry timestamps and
every compared non-time field are exact. Deal 15 buys out the prior short at
price `1.30294`, volume `2`, profit `98.00`, comment `sl 1.30293`.

This is not a timer-driven entry:

- the framework arms `EventSetTimer(1)` only when `MQL_TESTER == 0`;
- `QM_FrameworkOnTimer` performs kill-switch day refresh/chart refresh only;
- entries and open-position management remain on `OnTick`.

The rebuilt tester log supplies the causal sequence: it modifies ticket 14's
break-even SL to `1.30293` at `13:03:45`, then the stop fires at `13:03:47`.
The rebuilt MQ5 includes commit `2a7647ae9d`, whose new `side_ok` guard delays a
break-even modification until the stop is on the valid market side; the
predecessor MQ5 does not. The observed replay is economically exact, but the
mechanics change is **not economically null in general**: delayed stop
installation can leave live exposure open for extra ticks and can change the
eventual fill or PnL under another tick path. No entry can fire between ticks
from OnTimer.

The proposed `EQUIVALENT_TIMING` clause is recorded in
[equivalent_timing_proposal_v1.json](equivalent_timing_proposal_v1.json). It is
proposal-only and has not changed `identity_equivalence_proof.py`. It requires
exact economics, zero entry shifts, frozen tick data, repeated determinism, and
unchanged trade-operation event paths. This 10706 pair explicitly fails the
proposal because the stop-modification path changed and the selected EX5 is
unbound; its current verdict remains `NOT_EQUIVALENT`.

## Verification and safety

Machine-readable checks are in [verification.json](verification.json).

- `test_q02_post_binding_requalification.py`: 11 passed.
- Direct real-receipt supplemental authentication: PASS.
- Full deal-list comparison: 1/303 timestamp shifts, +3 seconds; 0 entry
  shifts; 0 non-time mismatches.
- No Q02 row, verdict, proof contract, T_Live file, terminal, AutoTrading
  setting, deploy package, or canonical-checkout file was mutated.

The required next review action is integration of this worktree commit. Only
then can the canonical controller create 10403's append-only Q02 successor.
10706 needs a fresh governed selected-preset seed/chain; it must not be
backfilled with an inferred historical EX5 hash.
