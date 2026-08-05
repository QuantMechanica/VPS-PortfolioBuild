# QM5_20217 WTI Weekend Gap Momentum Build And Q02 Enqueue

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency energy candidate was researched, approved,
allocated, built, strictly validated, committed, and handed to paced Q02:

- EA: `QM5_20217_wti-wkend-mom`.
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202170000`.
- Mechanic: on a genuine Friday-to-Monday boundary, buy a Monday open above
  the completed Friday high plus `0.10` times lagged 90-D1 return volatility,
  or sell below the completed Friday low minus the symmetric buffer.
- Lifecycle: one consumed attempt per Monday, first-following-D1 exit,
  two-calendar-day stale repair, `3.0 * ATR(20,D1)` hard stop, and no target.
- Q01: PASS with zero final compile errors/warnings and zero build-check
  failures/warnings.
- Backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Q02: exactly one priority-track work item enqueued; screening remains
  pending and no performance, decorrelation, certification, or portfolio
  verdict is claimed.

## Sources And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/CHAN-TGIF-WTI-WKENDMOM-2026/source.md`.

- Ernest P. Chan, *Algorithmic Trading* (2013), Chapter 7 Example 7.1,
  supplies the exact prior-high/low opening-gap direction, `0.10` multiplier,
  lagged 90-session return-volatility sample, and session lifecycle. The
  source carriers are FSTX and GBPUSD, not WTI.
- Hoelscher, Mbanga, and Nelson (2017), "TGIF? The Weekend Effect in Energy
  Commodities," *Journal of Finance Issues* 16(1), 47-68,
  DOI 10.58886/jfi.v16i1.2264, supplies peer-reviewed WTI weekend context. It
  does not test this opening-gap continuation rule.

The WTI carrier, genuine Friday-to-Monday restriction, D1 attachment, ATR
stop, fixed-risk contract, spread ceiling, and next-D1 exit are QM
translations. No source performance, CFD basis, frequency, drawdown, or
portfolio-correlation claim was transferred.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,274 registry rows and 390
cards and returned `CLEAN`, with no fuzzy match above threshold. Manual review
separates the mechanic from the material neighbors:

- `QM5_9151` applies the Chan opening-gap family to GDAXI, UK100, and GBPUSD
  H1 sessions, not genuine-weekend WTI D1.
- `QM5_12750` fades positive WTI Monday gaps and `QM5_12779` buys negative
  gaps toward a fill. This EA continues positive and negative breakaway gaps
  and has no fill target.
- `QM5_12596` is an unconditional Monday WTI short; `QM5_20117` is a
  Thursday-surge Friday reversal; neither uses the Monday open against the
  completed Friday range and lagged volatility.
- `QM5_12567` is a two-day commodity oscillator pullback, not a weekend-gap
  or prior-extreme continuation rule.

The WTI carrier, genuine weekend sequence, prior-range break, lagged
volatility buffer, same-direction entry, and next-D1 lifecycle are jointly
load-bearing.

## Allocation And Commits

- Research source packet, G0 decision, and canonical card: `3e18f296c`.
- Registry row, magic row, regenerated resolver, and initial backtest set:
  `bc3f4a3e9`.
- EA source/binary, SPEC, approved/build card references, Q01 status, and
  final fixed-risk set hash: `956130d24`.
- EA registry: `20217,wti-wkend-mom`.
- Magic registry: `XTIUSD.DWX`, slot 0, magic `202170000`.
- Generated resolver: 15,486 rows kept, zero dropped, registry SHA-256
  `AB8C31EBB8C6665D24F5B9100ACEF4CE069CDDBD9673A27FDF108B020E488A03`.

The paced-fleet artifact pump created `bc3f4a3e9` while the strict build was
in progress. It captured exactly the new registry, magic, regenerated
resolver, and initial generated setfile paths. The final source, binary, and
set build hash were committed explicitly in `956130d24`.

## Q01 Evidence

- Canonical and approved card schema lints: PASS; no missing sections or ML
  library hits.
- G0 card guard: PASS.
- EA build authorization guard: PASS for EA ID 20217 and the allocated magic
  row.
- Seven-section SPEC validator: PASS.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- Resolver regeneration tests: five passed.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_000514/QM5_20217_wti-wkend-mom.compile.log`.
- Compile summary:
  `D:/QM/reports/compile/20260805_000514/summary.csv`.
- Strict V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260805_000513.json`.
- EX5 size: 372,818 bytes.

The repository-wide registry validator reports 1,412 pre-existing legacy
issues across the broader registry and exits nonzero. A target-filtered read
found zero issue containing EA 20217, `wti-wkend-mom`, or magic `202170000`;
the candidate-specific registry/build guards passed. No unrelated registry
debt was modified.

Artifact SHA-256 values after the Q02 status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `FFDC5667552A1E53996784B1BA77713018550097236559F5C431EA2CE5F7EEB0` |
| Canonical card | `BEA64DA66CCE7310E35FC5E7EE14692A2C24C98EE744B806E2229DEA56CBAD08` |
| Approved card | `BEA64DA66CCE7310E35FC5E7EE14692A2C24C98EE744B806E2229DEA56CBAD08` |
| MQ5 | `9D041C8F156ADC7FF75E49E0BDE9F46F087D3DD39F1E4666E4A31E62671C5C70` |
| EX5 | `7B45E698DF37B0C0967F5FA51DE884F2B1DB93AA8167FBE88F9DFC872823023C` |
| SPEC | `3C03F61FC5D18659CE6AE01B8E70BE856382583D957CEBEDB4614C65DF888A8F` |
| Backtest set | `3D9F563D0B75F29AE9681576DEB921536738966399CEFB23A5883E07BB37EEE7` |

## Q02 Handoff

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20217 --symbols XTIUSD.DWX --max-part2-per-run 0

It selected exactly one `never_tested` item, zero stranded items, and one
priority-track item. Immediately before the guarded apply, the explicit
factory-only process scan found six active terminals: T2, T3, T5, T6, T7,
and T10. This was below the seven-terminal CPU ceiling.

The identical scope plus `--apply` inserted exactly one row:

| Field | Value |
|---|---|
| Work item | `4eaf26f4-d7e7-4915-9e3f-9f0c4213d157` |
| Phase | Q02 |
| EA | QM5_20217 |
| Symbol | XTIUSD.DWX |
| Setfile | `QM5_20217_wti-wkend-mom_XTIUSD.DWX_D1_backtest.set` |
| State at confirmation | pending, attempt 0 |
| Priority track | true |
| Created UTC | 2026-08-05T00:08:14+00:00 |

A read-only SQLite URI query confirmed exactly that durable row. The apply
started with 1,651 pending items against a 7,000 queue ceiling and added no
part-2/recovery item. The `ENQUEUED` card state records a handoff only, not a
Q02 PASS.

## Safety Boundary

- No manual backtest or downstream phase was launched.
- No live/demo/shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- No T_Live terminal, file, setting, or manifest was opened or changed.
- The portfolio gate and T_Live manifest were not touched.
- No terminal was started, stopped, reserved, reaped, or altered.
- The factory mutation lock and queue ceiling were not bypassed.
- Existing unrelated working-tree changes were preserved and excluded from
  every task commit.
