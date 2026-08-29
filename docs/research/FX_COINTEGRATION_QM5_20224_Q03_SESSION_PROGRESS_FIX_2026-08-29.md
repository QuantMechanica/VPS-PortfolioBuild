# QM5_20224 FX cointegration Q03 session-progress fix

Date: 2026-08-29 UTC (`2026-08-29T18:37:15Z`); 20:37 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `6c58e0e9318ca41cd7ea25d2b52198970e65a2aa`

Status: fixed the active-run liveness defect that falsely reaped the selected
EURUSD/EURJPY basket Q03 while a second tester session was demonstrably alive.
The existing priority-bound Q03 row remains pending for the paced worker; no
Card, EA, setfile, manifest, queue row, tester, terminal, or portfolio surface
was created or changed.

## Non-duplicate selection

The controlling reputable-source result remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published hard
criterion selected only two of the 66 scanned relationships. Both anchors are
already built and beyond Q02:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

The committed sign-aware coverage audit accounts for all 66 relationships,
with zero uncovered. A new Card or build would duplicate governed coverage,
and neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` repair. The
strategy-card extraction and EA-build gates therefore stayed closed.

The existing fallback remains scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. Q02 work item
`5d1cb89c-25ce-419c-869c-8c9f7afa10c1` is PASS. The same recovered Q03 work
item `3c74eb04-7e19-4aa0-8dcf-3f004faaa946` is pending with
`priority_track=true`; Q04 work item `a525cd8f-4c29-4752-b1af-3c43288f259e`
remains pending behind that dependency.

## Defect and repair

The prior Q03 run launched `run_01` on T4 and reached 94% at `16:47:15Z`.
The same work-item UUID then launched `run_02` at `16:49:36Z`. At `16:53:46Z`,
only 4.17 minutes later, the active-run reaper killed the row as
`NO_FORWARD_PROGRESS` because it kept the claim timestamp (`16:21:16Z`) as
`progress_at`.

The parser already exposed the newer UUID-bound marker as
`latest_session_at`, but Q02/Q03 consumed only percentage progress. This was a
narrow contract gap: a bounded `run_smoke.ps1` retry resets the percentage
stream, so the new session can be live before it emits its first percentage
line.

`tools/strategy_farm/farmctl.py` now applies a
`run_smoke_session_v1` progress contract to Q02/Q03. It accepts only the
existing work-item-UUID-bound MT5 session marker and uses it to advance the
stall clock when it is newer than percentage progress. It does not admit
arbitrary report-root growth. Replaying the exact incident changes the
detector from 32.50 stalled minutes at `16:21:16Z` to 4.17 minutes at
`16:49:36Z`, so the live retry is preserved.

`tools/strategy_farm/tests/test_progress_aware_reaper.py` adds the regression:
a Q03 row older than the 20-minute stall window survives when its same-item
retry session is four minutes old. A truly stalled row still reaches the
existing reaper path after the marker itself becomes stale.

## Package and verification

The selected sleeve remains unchanged and sealed:

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical backtest setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Card schema/ML lint passed with no ML hits. The logical setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the EA remains
structural, fixed-beta, D1, deterministic, and without ML or adaptive refit.

Verification completed:

- `python -m pytest tools/strategy_farm/tests/test_progress_aware_reaper.py -q`
  — 13 passed.
- Related terminal-worker/basket timeout selection — 4 passed, 16 deselected.
- Python compile and `git diff --check` — PASS.
- Exact production-log replay — fresh session marker selected, 4.17 stalled
  minutes, no reap.

## Capacity and handoff

Five one-second host CPU readings were `95.612506%`, `87.642342%`,
`79.797455%`, `78.420236%`, and `82.326172%`. Average CPU was `84.759742%`
and maximum CPU was `95.612506%`, both below the explicit 97% ceiling.

The serialized multisymbol lane rotated to
`QM5_41075_XAU_XAG_WOVERSHOOT_RV_D1`, Q04 work item
`a5b489ed-47f9-4c5e-b3a5-bde07b903413` on T3. No manual dispatch was started.
After that legitimate basket releases the lane, the resident paced worker may
reclaim the same priority-bound QM5_20224 Q03 row. Q04 must not advance before
a canonical Q03 PASS.

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live, AutoTrading, and live/deploy manifests were
untouched. Unrelated shared-worktree changes were preserved.

Machine-readable evidence:
`artifacts/qm5_20224_q03_session_progress_fix_20260829T183715Z_board_advisor.json`.
