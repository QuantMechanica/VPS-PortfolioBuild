# DXZ-Q8 fail-closed gate matrix — 2026-07-16

Status: **IN REVIEW / BLOCKED / NO SEMANTIC APPROVAL / NO RUNTIME EFFECT**

Machine-readable contract:
`docs/ops/evidence/dxz_q8_fail_closed_gate_matrix_20260716.json`

## Decision

The Q8 path is tightened, not made easier. Historical attractiveness may decide
which repairs deserve compute, but only fresh Gold evidence may admit a sleeve.
The stages are deliberately separate:

| Stage | What it answers | Can it promote? |
|---|---|---|
| `SELECTOR` | Is the old history interesting enough to investigate? Locked 2018–2022 only; at least 20 closed round trips, commission-adjusted PF at least 1.10 and absolute zero-filled monthly correlation at most 0.30 to every frozen Q6 sleeve. | No |
| `EARLY_SCREEN` | Are identity, approvals, build closure, data segments, calendars, costs and the trial ledger complete enough to spend test capacity? | No |
| `TARGET_BINARY_PAIR_GATE` | Do two designated, isolated `TARGET_BINARY_REQUAL` runs of the same frozen target reproduce on every bound stream and artifact axis? | Prerequisite only |
| `Q00`–`Q11` | Does the fresh target earn the canonical V5 evidence, in order? | Yes, but only exact `PASS` at every phase |
| `Q12` | Does the eight-sleeve portfolio pass synchronized intraday MTM, margin and risk tests? | Only exact `PASS_PORTFOLIO` plus OWNER signature |
| `PROSPECTIVE` | Does new post-freeze behavior support the already frozen thesis? | Never repairs an earlier failure |

Operationally, `Q00` must freeze the semantics before Development acts and
`Q01` must pass on the target build before the two Target runs start. The
Pair-Gate then closes reproducibility before the same frozen target continues
through `Q02`–`Q11` and reaches Q12.

`PF >= 1.10` and 20 trades therefore remain a historical selector, not a
replacement for Q02, Q10, Q11 or Q12. Canonical phase requirements remain
sourced from `docs/ops/PIPELINE_PHASE_SPEC.md`; this proposal grants no
low-frequency or portfolio-rescue exception. The 9.5% DD, 4.0% worst-day and
1.0% individual-risk limits below are additional proposed Q8 portfolio gates,
not thresholds from that canonical phase specification.

## Gold-only admission

Every canonical phase from `Q00` through `Q11` must say exactly `PASS`. Q12 must
say exactly `PASS_PORTFOLIO`. Internal adjudication may retain only `KEEP`, never
`KEEP_CANDIDATE`. In particular, `PASS_SOFT`, `FAIL_SOFT`, `INVALID`,
`EDGE_SOFT`, `KEEP_CANDIDATE`, partial, report-only, missing and unknown evidence
all block admission. Aggregate portfolio performance cannot rescue a non-Gold
sleeve.

Promotion identity is exactly
`(ea_id, symbol, timeframe, variant_id)`. All four values must match the Card,
execution contract, target manifest, both run receipts and gate artifacts. There
is no fallback to an EA-only row, sibling symbol, sibling timeframe, default
variant or alias.

## Reproducibility, costs and statistics

The two Target runs are designated before execution and run serially in isolated
roots outside T_Live and T1–T10. The Pair-Gate directly verifies the same
hash-bound Target manifest, Card, EX5/set artifact override, sealed reference,
five-axis cost contract and window contract. Source/include closure and the
data, calendar, news and risk approvals remain independent Q00/Q01 and
pre-result-ledger gates. They must be hash-bound upstream, but the Pair artifact
does not directly attest or replace them. The Pair-Gate is fail-closed on any
mismatch in its directly verified bindings, missing value or unledgered extra
attempt.

The executable Pair-Gate checks ten ordered identity axes: trades, signals,
entries, exits, lots, outcome signs, exact PnL, daily MTM, intraday MTM and
margin. Each receipt payload hash is verified independently. The Pair-Gate also
re-opens and hashes the fresh runtime log, parsed telemetry, transaction marker
and canonical Q08 stream under the exact ordinal run directory; relative,
cross-run, sandbox and symlink-escaped paths fail. It reconstructs every claimed
complete axis from those physical artifacts and rejects a receipt descriptor
whose count or SHA-256 differs. Parsed telemetry, Magic, joins, exit reasons and
Q08 enrichment are independently re-derived from the physical raw log rather
than trusted as self-declared sidecar fields. Full receipt payloads are not
compared to each other because run IDs, timestamps and sandbox paths must
differ.

`FULL` also means every actual Target-manifest sleeve appears exactly once at
its declared ordinal; self-declared job counts cannot hide a missing sleeve.
The Target runner itself now rejects missing entry/exit bijections before a
technical `PASS`, while retaining only the known request-versus-fill entry gap
as an explicit incomplete axis.

The runner now binds the expected Magic by strictly re-opening the hash-bound
Target manifest, checking the designated ordinal and unique four-part sleeve,
and validating the same value across receipt, telemetry, log and Q08 rows. Its
SHA-256 is unchanged within each run, bound into every receipt and identical
between the designated Pair runs. Exit reasons can close only for a complete
bijective Q08/log join. The current
runtime still leaves actual entry fill price, complete exit reasons for
broker-side/partial closes, daily MTM boundary snapshots, intraday MTM and
margin incomplete. A Pair `PASS` is therefore presently impossible rather than
silently weakened.

All research attempts enter an immutable trial ledger before results exist. The
ledger includes failed, aborted, repeated and missing runs—not only survivors.
Q10 computes DSR, PBO, FDR and Monte Carlo evidence from the complete declared
trial family. The canonical hard limits remain DSR greater than zero, PBO below
5% and FDR q-value below 0.10; proxy or partial statistics block Q10.

Five cost axes are mandatory per sleeve and Target run and again at portfolio
level:

1. commission;
2. historical spread provenance and coverage;
3. current spread parity;
4. swap;
5. adverse slippage and gap stress.

Missing, null, degraded or result-selected cost evidence blocks the chain.

## No-weekend and portfolio truth

No-weekend is zero-tolerance and null-intolerant: weekend exposure count and
seconds, positions and pending orders after the effective cutoff, post-cutoff
entries and unresolved close retries at market close must all be exactly zero.
Unknown or uncovered regular, holiday or early-close sessions are not treated as
zero. News and entry gates may never suppress mandatory risk reduction.

Q12 uses synchronized intraday mark-to-market and margin, including floating and
realized P&L, common-currency conversion, overlapping exposure, dynamic/minimum
lots, stressed gaps and margin. Exit-only, daily-only and unsynchronized curves
are diagnostics, not portfolio truth.

The primary Q6/Q8 comparison uses the same total commanded risk budget, starting
equity, account currency, calendar, cost and margin model. The budget value is
not invented here; OWNER must hash-bind it before the run. At that equal-risk
basis this in-review matrix adds the following proposed Q8 portfolio gates,
while every canonical Q12 requirement remains in force:

- synchronized intraday MTM drawdown at most 9.5%;
- stressed worst broker-day loss at most 4.0%;
- at most 1.0% risk per sleeve/EA/strategy/symbol.

The Q12 artifact must also report the empirical distribution of drawdown depths,
durations, recoveries and worst days with observation counts. No bootstrap run
count, seed or pass threshold is introduced by this draft. Bootstrap may become
gating only through a separate pre-result approval; the empirical distribution
report itself is mandatory.

## Do we have enough backtests?

Enough for triage and repair design: yes. The legacy streams reveal the XNG
threshold-selection issue, the 1556 first-week-of-month defect, approximate
economics and diversification candidates.

Enough to call the repaired Q8 book qualified: no. There are currently zero
valid two-run Pair-Gates for
`12567:XNGUSD.DWX:D1:C_XNG_BASE35_POLICY` and
`1556:XAUUSD.DWX:D1:C_POLICY_REPAIR`, no fresh Gold chain `Q00`–`Q11` for both
extensions and no fresh Q12 portfolio PASS. Reusing the old 53-trade 1556 stream
or the hindsight-selected XNG entry-30 stream would answer the wrong question.

## Approval boundary

This matrix is an `IN_REVIEW` proposal. It does not approve either Card-v2,
change any source or set, launch a backtest, alter T_Live, allocate risk, deploy
or toggle AutoTrading. Until the semantic signatures and every stated gate are
hash-bound, both extension sleeves and the Q8 book remain `BLOCKED`.
