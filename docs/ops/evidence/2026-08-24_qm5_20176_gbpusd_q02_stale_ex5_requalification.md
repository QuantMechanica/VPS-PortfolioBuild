# QM5_20176 GBPUSD Q02 current-binary requalification

Date: 2026-08-24
Branch: `agents/board-advisor`
Farm task: `58078cc6-7fd7-4f74-8005-1e2cd4e316b0`
Claim: `manual:codex:agents/board-advisor:QM5_20176:q02-stale-ex5-recovery:20260824T014332Z`

## Outcome

One append-only Q02 successor was enqueued for the diverse FX cell
`QM5_20176 / GBPUSD.DWX / H4` after authenticating a pre-spawn stale-EX5
infrastructure failure. The historical failure row remains terminal and unchanged.

- Source row: `ef31c371-fbe9-4eff-b0c2-9087e1df49b7`
  (`failed / INFRA_FAIL`)
- Successor row: `af304ebb-ad80-4d11-851a-18ead4add591`
  (`pending`, created `2026-08-24T01:44:45+00:00`)
- Successor provenance: `farmctl.append_only_exact_row_rerun`
- Farm payload flags: `historical_work_item_preserved=true`,
  `repaired_infra_rerun=true`, `priority_track=true`

## Non-collision selection

The highest-diversity newly approved build candidate, `QM5_41137` on WTI, was
already being claimed and built by another paced agent. Its build landed in
`154a3042c` and its approved-card binding in `3c908bbed`. I therefore did not
touch that EA and selected the mission's priority-2 path: an unclaimed, diverse
GBPUSD Q02 cell blocked solely by infrastructure lineage.

The farm claim was acquired before mutation and assigned to
`codex:agents/board-advisor`; no other open `QM5_20176 / GBPUSD.DWX / Q02` row
or competing claim existed at selection time.

## Diagnosis

The source row's authenticated evidence is:

`D:\QM\reports\work_items\ef31c371-fbe9-4eff-b0c2-9087e1df49b7\QM5_20176\Q02\preflight_failure.json`

Evidence SHA-256:
`05dd639358a67be7329fef0046d1f2b1b1005455c52fd31b7fd495bb4f269db3`.

The terminal worker refused the staged job before spawning MT5 because its
immutable row expected EX5 `9c06c3867f31e0fa1fadc0537f9392c91aaafb3a2c94810e00894af876070fa9`,
while the canonical source path already contained EX5
`ca4d09c0598f62a8f93303ce7e3a36d03dada86aa5e38b908d038d3dda7f5134`.
The evidence detail is `dispatch_ex5_source_sha256_mismatch`; this was not a
strategy result and no tester was launched.

The canonical execution identity at recovery time was:

| Binding | SHA-256 |
| --- | --- |
| MQ5 | `c75d3b4e3767e131da08f99c0b84fe78936109af13df2a201acf7bf29b443f40` |
| EX5 | `ca4d09c0598f62a8f93303ce7e3a36d03dada86aa5e38b908d038d3dda7f5134` |
| GBPUSD H4 setfile | `f2e51fcd5bd7cece748341c353b210b1d0f197e5f7c2f140d8a047743bf54378` |

The setfile is unchanged from the source row and remains fixed-risk:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. The successor payload
also seals `risk_fixed=1000.0`, `risk_percent=0.0`, `expected_symbol=GBPUSD.DWX`,
and `expected_period=H4`.

The current EX5 lineage is not speculative: Q02 row
`c272d160-2384-4e88-bab8-ee27c7ede52a` completed `PASS` on XAUUSD.DWX with the
same MQ5/EX5 pair. This recovery adds the missing current-binary GBPUSD cell
without rebuilding or changing strategy mechanics.

## Validation and enqueue controls

- `validate_build_guardrails.py` passed with 11 files and no findings.
- `validate_spec_doc.py` passed (`PASS=1`, `FAIL=0`).
- The EA registry entry and all six deterministic magic allocations are active;
  GBPUSD uses slot 1 under EA ID 20176.
- The approved card is structural, H4, deterministic and low-frequency. It uses
  a DMI/MACD/Donchian/D1-EMA trend stack derived from the named Steve Hopwood
  ForexFactory source archive; no ML or banned indicator was introduced.
- The guarded append-only command required the exact terminal source row,
  authenticated its evidence and payload, verified current hashes, preserved
  the original row, rejected duplicate/open rows, and admitted the active custom
  history archive for GBPUSD.DWX (108 rows).
- Immediately after enqueue, host CPU load sampled at 1%, with three terminal64
  processes. No manual dispatch, tester run, or extra terminal was started; the
  normal farm scheduler owns the pending row.

## Safety boundary

No EA source, setfile, portfolio gate, T_Live manifest, deployment manifest, or
AutoTrading state was changed. This unit only repaired a canonical farm binding
and enqueued Q02. It does not authorize live use.
