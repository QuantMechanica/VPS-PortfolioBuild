# FTMO Break & Retest / NNFX recovery, 2026-09-22

OWNER continuation: use available capacity on the already authorized FTMO
programme. Parent tasks: N-RECOVERY `cd3b761c-54d4-4b71-ba7e-f60018df57d3`
and R-RECOVERY `df1cae9b-76c7-4020-b732-9c2be501584d`.

## Findings and work

- 11963, 11964 and 11965 already have rejected cards dated 2026-09-12.
  Their missing builds are not an untested edge: undefined formulas or
  unsupported, saturated NNFX stacks were rejected on paper. No revival.
- 12038 is a rejected near-duplicate of approved 20078. No duplicate build.
- 9241 and 20078 lacked active magic rows. The governed allocator added exactly
  3 and 7 card-declared rows, respectively; both identity/magic/resolver checks
  PASS. No unrelated retired rows removed; no new identity collisions.
- 36001/36003/36004/36008 already contained most of the August review fixes.
  None had an authenticated COMPILE_OK. Their old EX5 files remain historical
  evidence until governed replacement.
- 36008 could repeatedly close half the remaining position after TP1 succeeded
  but the subsequent break-even modification failed. Its repair checks durable
  position/magic-scoped deal history and retries only the SL. Unreadable history
  fails closed. The check runs before the TP1 price threshold, so a retracement
  does not disable a protection retry.
- 14 backtest presets regenerated with current inputs and fixed $1,000 risk.
  `mq5_hash` binds source; `build_hash: pending` honestly awaits the binary.
  The old 36004 regression incorrectly conflated those two hashes and was fixed.
- Four exact source/evidence-bound rebuild registrations prepared. Each expires
  when a current COMPILE_OK exists. No strategy or portfolio gate is waived.
  Source/evidence LF attributes prevent the prior CRLF identity-drift problem.
- Existing 36008 Q02 `18865d7c-baba-43d3-8327-2ffc2896a1f3` is held by
  COMPILE_GATE_BROKEN_SOURCE. Retain that work item; do not create a second canary.

## Validation at source repair

- Four EA regression suites plus eight new authority tests: **35 passed**.
- Existing exact-authority and worker-lineage tests scoped to these four
  registrations: **8 passed** (16 including the new authority tests).
- A wider backlog-suite attempt: 137 passed, 1 skipped, 9 failed because this
  partial worktree lacks unrelated historical source/evidence fixtures. These
  are not represented as passing; no unrelated fixture or gate was weakened.
- Compile, smoke, independent review and economic backtest are still required.

## Economic interpretation

No success rate is inferred from the cards' promotional historical/Monte Carlo
figures. They are explicitly unevidenced. This work removes build blockers;
it does not establish 80% success or a fast payout. The previous BR1Ã¢â‚¬â€œBR3/NNFX-H1
prescreens had no survivors. Final ranking remains whole-account calendar time
to first positive net payout, with unconditional probability and cost stress.

## Evidence

`baseline.json` preserves the pre-mutation files, registry rows and task/work
history. `magic_allocation.json` records the bounded canonical allocation.
`QM5_*_compile_authority.json` and `compile_registrations.json` bind rebuild scope
to exact sources and immutable evidence. Runtime receipts are added separately.

## Recovery outcome: six authenticated compiles (2026-09-22)

The pending-compile statements above describe the initial repair snapshot.
They are superseded by `compile_success_summary.json`: **6 COMPILE_OK + 6
build_check PASS**, with exact MQ5/EX5 and evidence hashes, and 24 symbol presets.
Compiled binaries and hash-stamped presets are preserved with the source branch.

| EA | Candidate | Presets | Remaining work |
|---|---|---:|---|
| 9241 | H1 engulfing-zone retest | 3 | Actual governed smoke and current build/intake review |
| 20078 | M15 prior-session POC retest | 7 | Independent implementation review bb697211, then smoke/intake |
| 36001 | NNFX McGinley / SSL / WAE | 5 | Actual governed smoke and current build/intake review |
| 36003 | NNFX HMA / zero-lag MACD / STC | 3 | Same |
| 36004 | NNFX ALMA / QQE / volume flow | 4 | Same |
| 36008 | Gold NNFX KAMA / Vortex / TSI / WAE | 2 | Same; retain existing Q02 18865d7c |

Independent source review 52728403 accepted the first five implementations and
reproduced their scoped regressions. POC arithmetic/boundary amendment 6c5219a9
was accepted before implementation. Implementation review bb697211 is separate:
it explicitly adjudicates hard broker TP versus the card's closing-price phrase,
and PRE30_POST30 versus its 15-minute news minimum. Compile cannot settle these.

POC source commit cfa03950b0 includes seven presets, full SPEC, and two passing
pytest tests with 33 executable assertions extracted from actual MQL function
bodies (syntax translated to C#). These cover profile ties/coverage/high endpoint,
sparse data, BUY/SELL stops, restart touch consumption, RSI endpoints and entry
filters. They are not native MT5 execution or profitability evidence.

The original five build tasks are TODO for actual smoke/current build artifacts.
POC original build 751d8eb5 retains the explicit independent-review dependency.
No duplicate builds or canaries were created; no Q-gate or live promotion made.

### Frozen 2019 reachability diagnostic, not an economic backtest

Script commit 7e8c43caa3 preceded its data read. On 2019 M1-derived H1 observations,
the actual 9241 entry-function harness found 137 EURUSD, 119 GBPUSD and 97 XAUUSD
raw signals (353 total). `retest_reachability_2019.json` records input/source hashes.
This only demonstrates reachable entries. It excludes spread/news/position
suppression and rounding, uses a stated ATR proxy, and is not a trade count,
profit factor, or payout probability. Native MT5 parity remains required. No
2020â€“2025 files were opened for this diagnostic and no thresholds were tuned.

### Scheduling and economic priority

Retest candidates are the nearer fit for the speed hypothesis; measure their
cost-adjusted trade density and account contribution first. D1 NNFX candidates
must earn a place by marginal book benefit; their names or card marketing figures
carry no speed credit. Previously rejected 16 BR and 8 faster-NNFX cells remain
rejected/unknown, with zero admitted survivors. 11963/11964/11965 stay rejected;
12038 stays a duplicate of 20078.

Incumbent PAYOUT80 evidence remains context: modeled payout-by-30/45/60/90 days
is zero in that frozen diagnostic; its 80% lower-bound cutoff is approximately
1,300 converted calendar days. This is neither a new candidate result nor an
actual-bank-receipt forecast. No fast 80% strategy has been established.

### Reset continuity

Two physical worktree MQ5 files had reverted exactly to the pre-recovery base;
committed HEAD and authenticated canonical source still agreed. Exact base
copies and the matching old 36008 SPEC were archived and HEAD restored; see
`worktree_restore.json`. No new
logic change or repeated compile was needed. The worktree is intentionally
partial: do not stage missing unrelated tracked files or reset canonical changes.

## Governed execution follow-on

Coordinator task `ea8b4312-e092-481b-ad10-b08a8c18fced` (priority 79) resumes
actual worker-bound smoke/build/intake on the six ORIGINAL build tasks. It must
resolve the dispatch path under current Custom-history policy, preserve the
existing 36008 Q02 and honor POC implementation review. It cannot reuse the
unrelated basket-only smoke recovery authority or invent smoke/capacity evidence.
This is a scheduled infrastructure/execution follow-on, not a started backtest.

Durable source/build commits: 958e6d991d, 41c271b988, 7e8c43caa3, cfa03950b0,
87b5e693be. All six EX5 changes passed the pre-commit exact-source/binary
COMPILE_OK provenance guard. N-RECOVERY and R-RECOVERY deliveries are in REVIEW.
