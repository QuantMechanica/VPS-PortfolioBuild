# QM5_10718 logical FX8 Q02 priority handoff

Date: 2026-09-02 UTC (`2026-09-02T03:36:38.909828Z`); 05:36
Europe/Berlin

Branch: `agents/board-advisor`

Status: the unique rebuilt logical Q02 row for `QM5_10718` was advanced in
place with a bounded priority payload. No Card, EA, setfile, manifest, queue
row, tester, terminal, pipeline verdict, or portfolio-gate object was created
or changed.

## Non-duplicate decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 study tested all
66 FX relationships and published only two hard qualifiers. Both are built
and beyond Q02:

| EA | Relationship | Canonical frontier |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The latest
complete reconciliation records 123 approved cointegration/coint identities,
123 matching EA directories, zero unbuilt identities, and all 66 scan
relationships accounted for. The Strategy Card extraction and EA-build gates
therefore remained closed: another scan-derived Card, basket manifest, EA, or
Q02 row would duplicate governed work.

The mission's existing-forex fallback applies instead. `QM5_10718` is an
approved structural D1 FX8 carry basket that rebalances weekly, holds the two
highest-carry currencies against the two lowest-carry currencies, and stands
flat outside its realized-volatility regime. Its approved Card cites Lustig,
Roussanov and Verdelhan (RFS 2011) and Menkhoff et al. (JF 2012). It uses no
learned model, grid, martingale, or banned indicator.

## Bound logical package

The package rebuilt earlier in this fleet cycle remains hash-stable:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `92fa06a272aa4805e31c6caac4f1ad9feeaf91fec18c349a616bf2cae00f8f00` |
| EX5 | `10358a8dd852cd495265fc4099dfb7d9fecc711a047d98a4ff5eafbba51a91cc` |
| Basket manifest | `8dc0776c1aac52f566b0f0b33f390f34d222bae8bc20992f7740bcce5d0b458f` |
| Logical setfile | `cbc4602cc7685d7db68e9e17603916e4b66706ba9566248bf975c2a4782bd680` |

The logical preset remains `RISK_FIXED=500`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The governed compile receipt is
`docs/ops/evidence/2026-09-02_qm5_10718_fx8_mae_rebuild_q02_enqueue.md`;
it records `COMPILE_OK`, zero compiler errors, zero compiler warnings, and a
strict build-check PASS.

## Exact Q02 advancement

Work item `31f12573-d903-4386-a857-cad2b445d63a` for
`QM5_10718_FX8_BASKET_D1` now carries `priority_track=true` with reason
`board_advisor_fx_existing_card_fallback_logical_q02_after_exhausted_66_pair_frontier`.
Its canonical pending rank improved from 7,220 to 1,436.

The exact-ID compare-and-swap preserved the row's `pending`, unclaimed,
attempt-zero, unverdict state and its original `updated_at`. It changed only
`payload_json`, created one `priority_track_set` audit event, and left exactly
one open logical Q02 identity.

| Binding | Value |
| --- | --- |
| Preimage payload SHA-256 | `a2a9616a5e058f543b5515a7ed0f1204ac956dd79fb75888abb4662fa214d3ea` |
| Postimage payload SHA-256 | `957994dd62e6db1149fecf539e000a600a624b1b9d7bba2f237b3004ccba5231` |
| Audit event | `382087`, `priority_track_set` |
| Reversible journal | `D:/QM/reports/state/qm5_10718_logical_q02_priority_20260902T033638Z.journal.json` |
| Journal SHA-256 | `24d39820653bec025698c7cfaf034f20c18353d174d4ee1e1acbb2ee31dad070` |

The row had no active hold, supersession relation, or poison quarantine. No
duplicate work item was inserted and no tester was manually dispatched.

## Capacity and safety

The apply-time five-sample whole-host CPU window was 67.3%, 61.9%, 73.5%,
71.2%, and 66.0%: average 67.98%, maximum 73.5%, both below the explicit 97%
ceiling. No multisymbol work item was active at apply time. The global factory
mutation lock was acquired normally in 0.032 seconds and released cleanly.

Resident paced workers own execution when queue and lane ordering permit it.
This handoff asserts no Q02 or economic result.

- No portfolio admission, portfolio KPI, Q08 contribution, portfolio gate,
  T_Live manifest, live setfile, deploy artifact, or AutoTrading state changed.
- No strategy mechanic, risk value, historical verdict, status, claim,
  attempt count, or timestamp changed.
- Unrelated staged, unstaged, and untracked shared-worktree changes were
  preserved and excluded from this handoff.

Machine-readable evidence:
`artifacts/qm5_10718_fx8_q02_priority_20260902T033638Z_board_advisor.json`.
