# QM5_12512 logical FX-pairs Q02 priority handoff

Date: 2026-09-01 UTC (`2026-09-01T01:06:14Z`); 03:06 Europe/Berlin

Branch: `agents/board-advisor`

Status: the unique existing logical Q02 row for `QM5_12512` was advanced in
place by changing only its bounded priority payload. No Card, EA, setfile,
manifest, new queue row, tester, terminal, or portfolio-gate object was
created or changed.

## Outcome

The frozen 66-pair source frontier contains no unbuilt relationship. The
latest complete census records 123 approved cointegration/coint identities,
123 matching EA directories, and zero unbuilt identities. Both published hard
qualifiers are already beyond Q02:

| EA | Relationship | Canonical frontier |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS, Q04 FAIL |

The remaining unpriority fixed-pair rows are stale behind later economic
verdicts. The most recent rank-60 continuation, `QM5_20246` USDJPY/EURGBP,
also completed Q03 PASS and then Q04 FAIL on 2026-08-31. A new Card or EA
would therefore duplicate governed coverage or weaken the published source
criterion.

The mission's existing-forex-card fallback applies. Work item
`acbad967-bf94-4565-9e51-db193de01bf9` for the existing
`QM5_12512_FX_PAIRS_THRESHOLD_H1` logical basket now carries
`priority_track=true`. Its canonical pending rank improved from 8,469 to
1,422. The row remains pending, unclaimed, attempt zero, and unverdict; exactly
one matching open Q02 identity exists.

## Why this is not a new scan claim

`QM5_12512` is an already-approved, already-built structural pairs card. It
contains three fixed market-neutral relationships:

- EURUSD / GBPUSD;
- EURJPY / GBPJPY; and
- AUDUSD / NZDUSD.

This handoff does not claim that any relationship is a new discovery. It
advances the existing logical basket only, after the new-pair path proved
exhausted.

The July duplicate-guard record assessed `QM5_12512` before a worker-bound
logical identity existed. Since then, Q01 work item
`9ca7d432-68b1-50e7-9de6-1e40710b6634` produced a hash-bound PASS with 628
trades, and the governed enqueue path appended exactly one logical Q02 seed.
The physical-host fanout is not being revived or duplicated.

The card evaluates H1 bars but estimates only 20–60 trades per year per
configured pair. It uses fixed beta 1.0, a five-bar time stop, symmetric
long/short legs, deterministic z-score thresholds, and no adaptive refit,
machine learning, grid, or martingale.

## Artifact and risk binding

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `064032709516804323192a8bfe9cb6d45d68bbf57d2529cab264974e222f38de` |
| EX5 | `bb31cb2b92679e02916ba8e9b63b749d9c51af0e9b6474057f477604a8b21a1c` |
| Basket manifest | `2fceab6414057c8e25c1813daa9e0afdf2212197d843b0c8b16cfc9bb5e30021` |
| Logical setfile | `10697e9af07e0718fd4260a7dbc41f6cf59838e3122ac41badc2cf2aabf9b1d3` |

The current MQ5, EX5, and logical setfile hashes exactly match the sealed Q01
PASS identity. The setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The approved source record cites Philippe Morissette's
public `bt` pairs-trading example at commit
`2630651f212c025f0cec351d6319ad81d587ad6e`.

## Guarded queue mutation

The mutation changed only `payload_json.priority_track`, its bounded reason,
and handoff provenance. It used the exact work-item ID, full preimage payload,
pending/unclaimed/attempt-zero predicates, and a one-row compare-and-swap.
The row had no active hold, supersede relation, or poison-pill quarantine.
`updated_at` was deliberately preserved.

| Binding | Value |
| --- | --- |
| Preimage payload SHA-256 | `b1708e5b52fa3930a19640136620c3876b58f38ec219299b9b8fe13367b3d82b` |
| Postimage payload SHA-256 | `515b2f7a6d07479cd315183b8dd36f3c8c15d29ee75cbb562ee982c07bc9a3b4` |
| Audit event | `381251`, `priority_track_set` |
| Reversible journal | `D:/QM/reports/state/qm5_12512_logical_q02_priority_20260901T010607Z.journal.json` |
| Journal SHA-256 | `eac3b2931b526a8193a23915917302fe906e9bbf6758318b89ccde8dcafaf63f` |

No duplicate queue row, alpha change, verdict change, or manual dispatch was
made.

## Capacity and paced-fleet handoff

The apply-time five-sample CPU window was 92.1%, 96.2%, 78.0%, 89.9%, and
94.5% (average 90.14%, maximum 96.2%). Both measures remained below the 97%
hard ceiling.

T8 already owned the serialized multisymbol lane for
`QM5_20161_XAUUSD_XAGUSD_OLS_D1`, Q03 work item
`11cbafc9-5452-45d6-8a11-a81bc33473c1`. It was left undisturbed. No manual
MT5 launch was attempted; resident paced workers own Q02 after the lane and
queue permit it.

## Verification and scope

- SPEC validation passed.
- Build guardrails passed with zero findings.
- Symbol-scope validation returned `BASKET_OK` with zero violations.
- The basket-manifest and basket-work-item suites passed: 65 tests.
- The legacy approved Card produced no ML hits. Its headings predate the
  current card-linter names, so no new extraction or schema claim is made.
- The current build guard reports no active EA-registry row, and the live
  factory correctly refused an ad-hoc build check. No rebuild or compile was
  attempted; advancement relies on the hash-matching Q01-approved binary.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live, AutoTrading, live/deploy manifest, or Q08 state
was touched. Concurrent unrelated worktree changes were preserved and are not
part of this handoff.

Machine-readable evidence:
`artifacts/qm5_12512_logical_q02_priority_20260901T010607Z_board_advisor.json`.
