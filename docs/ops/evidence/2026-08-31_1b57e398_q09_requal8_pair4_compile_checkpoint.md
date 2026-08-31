# Q09 REQUAL-8 pair 4 governed compile checkpoint

- Recorded: `2026-08-31T17:48Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR4_COMPILE_PASS_REVIEW_NOT_OPENED`

## Outcome

Pair 4 now has a faithful V5 recovery port, canonical SPEC and fixed-risk
setfile, plus an authentic governed `COMPILE_EA` result. The exact compile row
finished `COMPILE_OK`; build-check passed with zero compile errors and zero
compile warnings, and the worker emitted a hash-bound EX5.

This checkpoint does not claim a completed build task, code review, Q02 seed,
hold release, or pipeline verdict. The applicable `qm-build-ea-from-card` skill
is build-only and explicitly forbids running a backtest. The generic build-result
schema permits `deferred_p2_smoke` only after a measured pre-launch
`status=no_capacity` refusal. No such refusal was produced because no smoke
backtest dispatch was attempted. Consequently no synthetic waiver or
`build_result.json` was written, the build task remains `pending`, and the next
serial gate is a schema-valid Q01 disposition followed by independent reviews.

## Managed-build recovery and identity preflight

The previously recorded managed build PID `4824` had exited without producing
source or a build-result artifact. Work continued against the same canonical
build task `4e026269-a3e9-4030-8c12-7dd2da788cf4`; no duplicate build task or
spawn was created.

- Recovery card:
  `D:/QM/strategy_farm/artifacts/cards_review/QM5_41218_demark-td-reverse-sequential-h4-requal8.md`
- Recovery-card SHA-256:
  `5d5b5b902e98c8030a0b8432020f4a06e6d7f62bc80bc817b446bdf8b7d666bb`
- Card G0 status: `APPROVED`
- Parent: `QM5_1567_demark-td-reverse-sequential-h4`
- Successor: `QM5_41218_demark-td-reverse-sequential-h4-requal8`
- Target: `EURUSD.DWX H4`
- Active EA registry row: `41218`
- Active magic row: slot 0, `EURUSD.DWX`, `412180000`
- Magic resolver verification: `412180000` present

## Build artifacts

The port preserves the parent DeMark reverse-sequential mechanics and moves its
series reads, trade telemetry, and entry-only news gate onto current V5
framework wiring. Open-position management and exits are not blocked by the
entry news gate.

| Artifact | SHA-256 |
|---|---|
| MQ5 | `6da309ab85b209e5b2b3c739ffc75246d8f78447d47bb3eeff70a50f25b8e7de` |
| EX5 | `c3e6e260c14ec8b7263b35aae3380433d4c48b6b3d34199deb27b2e18eb52f10` |
| SPEC | `468522458de183162e44ad5e7ae8a97fcd81b85a6f4f8798b38cb676700f13fd` |
| Final setfile | `acbfe9a15d24987eb70cad5289429b671f2732a57e81c14e9ec047d1cd2612f4` |

The setfile carries worker-generated build hash
`a6263ed5c42b9ba6436464f59a277b80474c09f22e2ff5ce0a0a195fd30a035e`
and preserves `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

Focused commits, each with explicit pathspecs:

- `9014a0c22d` — source, SPEC, and initial fixed-risk setfile
- `09976d9d6f` — SPEC formatting normalization
- `bc707e6201` — governed EX5 and worker-generated setfile build hash

## Focused verification

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`
- `validate_build_guardrails.py`: MQ5 PASS and setfile PASS, zero findings,
  `qm_news_stale_max_hours=336`
- `build_gate_hardening.py`: zero failures; three expected warnings because the
  approved recovery card is in the runtime `cards_review` reservoir
- Forbidden raw series-access scan: no raw `iClose`, `iHigh`, `iLow`, or
  `iTime` calls in the successor
- Compile worker build-check: `PASS`, zero failures, three card-location
  warnings, zero compiler errors, zero compiler warnings

The source uses `QM_ReadBar`, places the MAE telemetry hook first in `OnTick`,
keeps the two-axis news contract at the 336-hour ceiling, and binds exactly to
`EURUSD.DWX H4`.

## Governed compile evidence

- Compile work item: `a864683a-9f08-4904-aba3-782a71d2e5ee`
- Build-task binding: `4e026269-a3e9-4030-8c12-7dd2da788cf4`
- Exact-row release receipt:
  `docs/ops/evidence/2026-08-31_1b57e398_q09_requal8_pair4_compile_release.json`
- Release-receipt SHA-256:
  `bfcc2afd5dc26fe9e9883445990608ce3c21cd299e85a816d96a57a7acf02a59`
- Release timestamp: `2026-08-31T17:37:42Z`
- Pre-mutation backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260831T173735Z_73de6fd9.sqlite`
- Backup SHA-256:
  `1cde9e8bb7073a6716699fa26f0066344ab3119ced11a78bf9210d0fee67cdab`
- Append-only transition ledger sequence: `2659`
- Audit event ID: `381175`
- Worker claim: `T6`
- Worker interval: `2026-08-31T17:40:24Z` to `2026-08-31T17:41:12Z`
- Verdict: `COMPILE_OK`
- Build-check result: `PASS`
- Authentic compile evidence:
  `D:/QM/reports/work_items/a864683a-9f08-4904-aba3-782a71d2e5ee/QM5_41218/COMPILE_EA/compile_evidence.json`
- Compile-evidence SHA-256:
  `623f29fb3e377041412fb398821cb2da6b50b9ed0eb18605a23120c1ba920f33`
- Build-check report SHA-256:
  `73cbcfbb66c7065aaf4159139934cd9e5c4eb2b6f73bda168a841703c9f43c12`

The compile was requested and executed only through the governed queue. No
terminal was started manually, no active T1-T10 test was interrupted, and no
AutoTrading or live setting was changed.

## Serial boundary

- Pair-4 build task: `pending`
- Pair-4 build-result artifact: absent by design at this checkpoint
- Pair-4 Codex/Claude review tasks: not opened
- Pair-4 Q02 seed count: zero
- Pair-4 manifest hold `2604a1f0-4f58-4597-89ef-432af9093131`: active
- Pairs 5-8: untouched behind pair 4
- Protected `QM5_41162 OPT_CENSUS`: not modified or interrupted

The next actor must resolve Q01 under an authority that permits its one governed
smoke run, then record the truthful build result and allow the controller to
open mechanical Codex and independent Claude reviews. Q02 enqueue and the
pair-4 hold release remain prohibited until both reviews approve.
