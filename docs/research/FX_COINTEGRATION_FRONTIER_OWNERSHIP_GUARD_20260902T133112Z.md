# FX cointegration frontier — ownership-guard handoff

Date: 2026-09-02 UTC (`2026-09-02T13:31:12Z`); 15:31
Europe/Berlin

Branch: `agents/board-advisor`

Status: no safe non-duplicate portfolio mutation remained. The fixed 66-pair
frontier is fully mechanized, the preferred anchors are beyond Q02, every
clean admissible FX-basket fallback already has a priority-bound Q02 row, and
the one stale execution binding that still needs repair overlaps pre-existing
staged and unstaged work on the exact same EA paths.

## Frontier result

The controlling study remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its fixed v3 universe
contains all 66 unordered relationships. The latest complete reconciliation
records 123 approved cointegration/coint identities, 123 matching EA
directories, and no unbuilt approved identity. A new scan-derived Card, EA,
basket manifest, registry allocation, or Q02 row would therefore duplicate
governed coverage.

The two hard-survivor anchors have no current Q02 setup blocker:

| EA | Relationship | Current terminal chain |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS (`e4890d77`), Q04 PASS (`94f89f07`), Q05 FAIL (`82cab3d1`) |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS (`76cb11ee`), Q04 FAIL (`ff2cb183`) |

## Existing-card fallback audit

The clean, structurally admissible fallbacks are already advanced as far as a
headless paced wake can safely take them:

| EA | Current exact row | State |
| --- | --- | --- |
| `QM5_12507` | `547c4fd3`, EURUSD/GBPUSD logical Q02 | pending, unclaimed, attempt 0, priority |
| `QM5_12512` | `acbad967`, three-pair logical Q02 | pending, unclaimed, attempt 0, priority |
| `QM5_10717` | `65319749`, current-binary FX8 logical Q02 | pending, unclaimed, attempt 0, priority; its stale predecessor has a canonical supersedes edge |
| `QM5_10718` | `31f12573`, current-binary FX8 logical Q02 | pending, unclaimed, attempt 0, priority |

Appending another row or rewriting priority metadata on any of these would be
duplicate work. Paced workers retain claim and dispatch ownership.

Two unqueued builds were deliberately rejected as fallbacks. `QM5_34008` is
still BLOCKED by review task `72b63c06`: its approved card does not define the
package-to-leg risk allocation needed for card-faithful sizing, and its
execution-contract registry entry is absent. `QM5_37001` remains RECYCLE under
task `92c3eb98`: the checked-in EA fits a univariate OU process, not the
approved two-leg spread package. Neither has Q02 authorization.

## Actionable frontier protected from concurrent absorption

`QM5_10025` remains the next genuine market-neutral FX continuation. Pending
USDJPY/H4 Q02 row `e49888a1-6dbe-45b7-bb4f-29461bbcfb0c` is bound to EX5
`030e7acc...`, while the current worktree EX5 is `49fcc59b...`; no canonical
supersedes edge exists yet.

That repair was not taken over. The exact scope already had six porcelain
entries spanning staged and unstaged changes to the EA source, EX5, USDJPY
setfile, SPEC, and two recovery-evidence files. The current worktree source
hash is `db7424ef...`. Superseding or seeding against those uncommitted files
would either absorb another worker's changes or bind a noncanonical build.
All six entries were preserved byte-for-byte and excluded from this commit.

Once their current owner commits and the exact paths become clean, re-read the
hashes and Q02 lineage. If `e49888a1` is still the only unsuperseded open
USDJPY row and remains stale, preserve it with one canonical supersedes edge,
then use the governed current-binary append-only Q02 seed path. Do not stage or
commit the present foreign changes as part of that continuation.

## Capacity and safety

The five one-second whole-host CPU samples were 53.934714%, 54.812425%,
53.520724%, 53.645469%, and 57.762159% (average 54.735098%, maximum
57.762159%). The explicit 97% CPU ceiling did not bind; the stop is solely the
non-duplication and shared-worktree ownership guard.

No Card, EA, EX5, setfile, manifest, registry, magic, queue row, priority,
verdict, supersedes edge, tester, terminal, or AutoTrading state changed. No
portfolio-admission/KPI/Q08-contribution surface, portfolio gate, T_Live path,
or live/deploy manifest was touched.

Machine-readable companion:
`artifacts/fx_cointegration_frontier_ownership_guard_20260902T133112Z_board_advisor.json`.
