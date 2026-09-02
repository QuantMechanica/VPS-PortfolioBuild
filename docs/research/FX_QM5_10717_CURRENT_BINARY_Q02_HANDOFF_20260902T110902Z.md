# FX frontier: QM5_10717 current-binary logical Q02 handoff

Date: 2026-09-02 UTC (`2026-09-02T11:09:02Z`); 13:09 Europe/Berlin

Branch: `agents/board-advisor`

Status: one approved, low-frequency FX8 market-neutral basket was advanced to
one current-binary logical Q02 item. No new scan-derived Card or EA was created.

## Non-duplicate decision

The controlling 66-relationship study remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Both hard qualifiers are
built and past Q02:

| EA | Relationship | Current governed frontier |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The latest
complete reconciliation records all 66 relationships covered, 123 approved
cointegration/coint identities, 123 matching EA directories, and zero unbuilt
approved identities. Creating another scan-derived Card, basket manifest, EA,
or Q02 row would duplicate governed work, so the mission's existing-forex-card
fallback applies.

## Selected existing FX sleeve

`QM5_10717_edgelab-xsec-fx-momentum` is an OWNER-approved D1 FX8 basket sourced
from Menkhoff, Sarno, Schmeling, and Schrimpf (2012), *Currency Momentum
Strategies*, *Journal of Financial Economics* 106(3). Its R1-R4 gates are all
PASS.

The mechanics are structural and low-frequency: once per week, rank the eight
major currencies by 63 closed D1 returns, pair the strongest with the weakest
and the second strongest with the second weakest, and skip new exposure in the
top realized-volatility decile. Each of the two legs has a hard D1 ATR stop.
There is no ML, grid, martingale, averaging, or HFT path.

The checked-in `basket_manifest.json` binds logical symbol `FX8_BASKET_D1` to
28 FX crosses, hosted on `EURUSD.DWX` / D1. Its SHA-256 is
`9aea91d105f8ff70a9993d646259d3d2a1e87a608ea477651ac8f16673235e6a`.
The logical backtest preset is fixed-risk only:

| Binding | Value |
| --- | --- |
| `RISK_FIXED` | `1000` |
| `RISK_PERCENT` | `0` |
| Setfile SHA-256 | `e6cf041bce7de65c935edbeab71bd5c5e6f6524dcbc5732f280ad3ad3684548b` |

## Current-binary queue repair

Governed compile work item `9f797114-aa19-4a82-ad10-65c18157170a` is
`done / COMPILE_OK`. Its receipt binds:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `0278b5ddef713e76617c4ae4bc9c97b21217e88578e36a1a09d5ebe10faef970` |
| EX5 | `3d5680d0022df60ca523630822515e5f1cf86a2e7bc4d512eda45065cb8ce463` |

The only logical Q02 seed, `7dd70134-a2a0-4ecf-a706-5f4609a094be`, was still
pending, unclaimed, attempt zero, and unverdict, but it sealed the pre-repair
EX5 hash `72c118b0...`. It could not safely dispatch the repaired binary.

The stale row was preserved byte-for-byte and given a canonical
`work_item_supersedes` edge with no fabricated successor. Before that mutation,
the helper created the full SQLite backup
`D:/QM/strategy_farm/state/backups/farm_state_before_supersedes_20260902T104711Z.sqlite`
with SHA-256
`ab37ef1f910bfa08c747f8591f838b27f858657b2636b9f13f9d469c2d15b4b9`.

`seed-fresh-q02` previously treated a superseded pending seed as a permanent
duplicate. Commit `4519677517b1db0b01f5f5ccf34876b1cdfcbf4e` closes that
append-only tooling gap: both its open-row guard and its prior-seed guard now
exclude rows present in `work_item_supersedes`. The regression suite passed 48
tests in 32.60 seconds, including
`test_fresh_q02_seed_ignores_canonically_superseded_prior_seed`.

The canonical enqueue then created exactly one current-binary work item:

| Field | Value |
| --- | --- |
| Work item | `65319749-3c0b-4636-9131-305c34100a08` |
| Phase / logical symbol | `Q02` / `FX8_BASKET_D1` |
| State at verification | pending, unclaimed, attempt 0, no verdict |
| Priority | `priority_track=true` |
| Host | `EURUSD.DWX` / D1 |
| EX5 binding | `3d5680d0022df60ca523630822515e5f1cf86a2e7bc4d512eda45065cb8ce463` |

A direct post-commit query found exactly one unsuperseded open logical Q02 for
`QM5_10717`: the new work item above. No per-pair fan-out or duplicate row was
created. Paced workers retain dispatch ownership.

## Capacity and safety

The final five-sample whole-host CPU window was 43.114%, 46.382%, 43.878%,
43.606%, and 46.8%: average 44.756%, maximum 46.8%, below the explicit 97%
ceiling.

- No dispatch tick, tester, backtest, terminal reservation, terminal control,
  or AutoTrading action was started.
- No Card, EA source, EX5, setfile, basket manifest, registry, or magic row was
  changed in this handoff.
- No portfolio admission, portfolio KPI, Q08 contribution, portfolio gate,
  T_Live manifest, live setfile, or deploy artifact was touched.
- Unrelated staged, unstaged, and untracked shared-worktree changes were
  preserved and excluded from the commits.

Machine-readable evidence:
`artifacts/qm5_10717_fx8_current_binary_q02_enqueue_20260902T110902Z_board_advisor.json`.
