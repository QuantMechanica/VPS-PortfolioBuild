# QM5_41490 anchor-clock range-breakout research instrument

Task `955537dd-63d2-4f84-a1b1-c4d2499b78c4` produced a reviewable V5 research
instrument for the three harness-v2 golden cells. The source, identity, magic
rows, implementation, specification, exact presets, and focused contract test
are committed on `agents/codex-orchestration-12` at `7d28a5e53b`. Local strict compilation is
PASS at 0 errors and 0 warnings. No governed Q02 row was invented, so all three
economic-comparison labels remain `UNKNOWN`.

## Durable result

- Approved card of record:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41490_anchor-clock-range-breakout.md`
  (`type: research_instrument`, `g0_status: APPROVED`, R1-R4 all PASS). Its
  post-seal file SHA-256 is
  `3edb95626c052612dda4ce5f1b788b535a16de959c9f49d3cf255f56949c256c`.
- Sealed research source: `QM-RESEARCH-2026-0013`, source hash
  `be46ba59baca625ee17711b44963a53ae9bc3de1bfccba4e118762e1ad897218`.
- Identity: EA 41490 / `anchor-clock-range-breakout`, reserved in commit
  `88c716a193`.
- Governed magic allocation, committed separately in `f355e6b546`:

  | slot | symbol | magic |
  |---:|---|---:|
  | 0 | USDJPY.DWX | 414900000 |
  | 1 | NZDJPY.DWX | 414900001 |
  | 2 | EURUSD.DWX | 414900002 |

- Implementation:
  `framework/EAs/QM5_41490_anchor-clock-range-breakout/`.
- Exact cell presets: A2 NZDJPY, A3 USDJPY, and A4 USDJPY. Every preset uses
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, DXZ PRE30/POST30 news controls, and
  `qm_news_stale_max_hours=336`.
- `anchor_clock` is the runtime enum `SERVER_RAW | GMT3_EQUIVALENT | UTC`.
  Non-server modes use `QM_BrokerToUTC` and `QM_UTCToBroker`; the fixed GMT+3
  06:00/18:00 anchor projects to broker 05:00/17:00 in winter and
  06:00/18:00 in summer.
- `OnInit` validates bounded input relationships without freezing A2, A3, A4,
  or one clock mode, and logs `INIT_OK` only after framework initialization.
- The strategy retains the hardened dual-send/OCO cleanup, one-attempt daily
  state, current-stop risk basis, two-grid-bar trail, flat cleanup, and
  mandatory news blackout from the reviewed 13213/41485 lineage.

The generated EX5 is retained only as a working-tree build output. It is not
staged because a new binary must be committed with its governed compile
receipt after reviewed integration. Its SHA-256 is
`2b5c3f5631e56bea973d11afc86bc08641f9536fbf28874fe155cbeb9a5ab15e`
(457286 bytes).

## Verification

| check | result |
|---|---|
| strict `build_check.ps1` | PASS; 0 failures, 0 warnings |
| MetaEditor compile | 0 errors, 0 warnings |
| EA contract + allocator/resolver tests | 27 passed |
| build guardrails | PASS; 4 files, 0 findings, stale-news maximum 336 |
| symbol-scope validator | `SINGLE_SYMBOL_OK`; 0 violations |
| sealed-source/card verification | PASS |

The checked-in contract test binds all three preset maps, fixed-risk and news
rails, identity/magic rows, the absence of tradable symbol literals in the EA,
the non-frozen clock enum, and winter/summer GMT+3 projections. Machine-readable
details are in `verification.json`; the strict-build report and governed
allocator report are preserved in this directory.

## Golden comparison

| cell | harness n | harness E[R] | harness PF | harness worst-year DD | MT5 Q02 | label |
|---|---:|---:|---:|---:|---|---|
| A2 NZDJPY | 970 | +0.0570 | 1.122 | 21.00R | absent | UNKNOWN |
| A3 USDJPY | 893 | +0.0675 | 1.161 | 21.87R | absent | UNKNOWN |
| A4 USDJPY | 821 | +0.0753 | 1.184 | 18.56R | absent | UNKNOWN |

`golden_comparison.json` binds the exact preset hashes and comparison rules.
These are research labels, not pipeline verdicts.

## Remaining governed work

The compile/Q02 portion cannot safely be enqueued from this authoring branch:

1. `enqueue-compile` resolves the EA from the canonical checkout and offers no
   source-commit argument. The canonical workers cannot import this EA until
   the review integration is complete. This task explicitly forbids writing or
   integrating `C:/QM/repo`, so no premature compile row was created.
2. The requested experiment has two independent USDJPY arms (A3 and A4), while
   first-Q02 discovery currently assumes one canonical setfile per EA/symbol.
   Its replacement-setfile path is restricted to append-only cascade phases.
   A reviewed exact-arm route is therefore required to preserve both USDJPY
   identities rather than silently selecting one.
3. EURUSD is a future-instrument registry slot only; the approved three-cell
   batch intentionally contains no EURUSD preset or Q02 row. The control plane
   must not synthesize an undeclared cell to satisfy symbol-universe discovery.

The canonical controller dry-run confirmed zero enqueue and refused the EA as
`EA_DIRECTORY_MISSING`, with its source, identity row, and active magic rows
also absent from the canonical checkout. The attempted router handoff made no
update: build-task REVIEW is fail-closed on a committed, hash-bound
`build_identity.json` and returned `D6_BUILD_IDENTITY_MISSING`. Creating that
identity prematurely would also violate the EX5 commit guard, which requires a
matching governed `COMPILE_EA` receipt. `compile_admission_dry_run.json` and
`blocker_state.json` preserve the exact stable facts without inventing rows.

After review integration, run the governed compile, preserve its receipt, and
enqueue the three exact arms through an identity-preserving Q02 route. Only
authentic pipeline evidence may replace the `UNKNOWN` labels.

No terminal was started, no active backtest was interrupted, no pipeline phase
was run, and T_Live and AutoTrading remained off.
