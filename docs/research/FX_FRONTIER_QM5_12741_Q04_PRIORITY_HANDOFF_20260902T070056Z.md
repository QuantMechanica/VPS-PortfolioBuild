# FX frontier: QM5_12741 Q04 priority handoff

Date: 2026-09-02 UTC (`2026-09-02T07:00:56.669217Z`); 09:00
Europe/Berlin

Branch: `agents/board-advisor`

Status: the unique append-only Q04 infrastructure retry for `QM5_12741` was
advanced in place with bounded priority metadata. No Card, EA, setfile,
manifest, queue row, tester, terminal, pipeline verdict, or portfolio-gate
object was created or changed.

## Non-duplicate decision

The controlling research record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 study covered all
66 FX relationships and published two hard qualifiers. Both are built and past
Q02:

| EA | Relationship | Canonical frontier |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS, Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The latest
complete census records 123 approved cointegration/coint identities, 123
matching EA directories, zero unbuilt identities, and all 66 scan
relationships accounted for. The Strategy Card extraction and EA-build gates
therefore remained closed: another scan-derived Card, basket manifest, EA, or
Q02 row would duplicate governed work.

The mission's existing-forex fallback applies instead. `QM5_12741` is an
OWNER-approved, closed-bar D1 pooled FX trend sleeve over `AUDUSD.DWX`,
`EURUSD.DWX`, `GBPUSD.DWX`, and `USDCHF.DWX`. Its fixed Kijun, SSL, Aroon,
Waddah-Attar Explosion, and ATR rules are structural; the Card forbids ML,
grid, and martingale behavior. It expects about three trades per member per
year, or roughly 12-14 pooled trades, and cites the published VP / No Nonsense
Forex algorithm. This is continuation of an existing approved Card, not a new
source or edge claim.

## Bound basket package

The package remains hash-stable:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `72bea21c0237c38f79053148515e12d33c8b806483c16b30e23cc19cb5e8157f` |
| EX5 | `47c92e1a7f3ba5ef3578f11065368d581b1f7385768eb716371a95b5b57853be` |
| Basket manifest | `c4e3e1629364122d7f267e8ee911f3e9b36718a9aebbb3487c2afd385c22119d` |
| Logical setfile | `1d6cc31f683f27598a4a8a31d960a2c2a43fff0b394dc9280dff2e1fb30f0c51` |

The logical preset remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The checked-in basket manifest binds the four members to
logical symbol `QM5_12741_NNFX_FX_BASKET_D1`, hosted on `AUDUSD.DWX` D1.

## Exact Q04 advancement

The immutable predecessor chain remains:

| Phase | Work item | State | Verdict |
| --- | --- | --- | --- |
| Q02 | `cab41d73-7573-4648-b58d-ce9fa6df26b3` | done | PASS |
| Q03 | `bf4f1a14-2d2f-4caf-9d94-8076560d8b8d` | done | PASS |
| Q04 | `fc9e29f1-9729-478f-96fb-dd7dcdb5978d` | done | INFRA_FAIL |

The earlier Q04 result is infrastructure-only (`NO_HISTORY` among its fold-F3
failure codes), not a strategy verdict. Its unique append-only retry is work
item `4776406a-a34e-4867-983c-8f3b420e9e92`.

That exact row now carries `priority_track=true` with reason
`board_advisor_fx_existing_card_fallback_q04_infra_retry_after_exhausted_66_pair_frontier`.
Its canonical pending claim rank improved from 6,946 to 1,391 at apply time.

The exact-ID compare-and-swap preserved the row's pending, unclaimed,
attempt-zero, unverdict state and original `updated_at`. It changed only
`payload_json`, created one `priority_track_set` audit event, and left exactly
one open logical Q04 identity. No duplicate or replacement row was inserted.

| Binding | Value |
| --- | --- |
| Preimage payload SHA-256 | `e5c9a13c8a521858620c97aa293733da0fa2d530a2daf10278d20e9acea9766a` |
| Postimage payload SHA-256 | `5d15171f32ca37002dac8005061aa23395a4c2522ef05eed83e7a425336fa233` |
| Audit event | `382243`, `priority_track_set` |
| Reversible journal | `D:/QM/reports/state/qm5_12741_q04_priority_20260902T070056Z.journal.json` |
| Journal SHA-256 | `4baa9bd5ac532130dafa3ba0fca282c62d80b05bf3ecaf6651021f80cc9d2506` |

The row had no active hold, supersession relation, or poison quarantine.

## Capacity and safety

The apply-time five-sample whole-host CPU window was 82.5%, 83.1%, 75.8%,
81.2%, and 84.8%: average 81.48%, maximum 84.8%, below the explicit 97%
ceiling. No logical multisymbol work item was active at apply time. The global
factory mutation lock was acquired in 0.016 seconds and released cleanly. No
manual MT5 dispatch, tester, terminal reservation, or terminal control was
started; paced workers retain execution ownership.

- No portfolio admission, portfolio KPI, Q08 contribution, portfolio gate,
  T_Live manifest, live setfile, deploy artifact, or AutoTrading state changed.
- No strategy mechanic, risk value, historical verdict, status, claim,
  attempt count, or timestamp changed.
- Unrelated staged, unstaged, and untracked shared-worktree changes were
  preserved and excluded from this handoff.

Machine-readable evidence:
`artifacts/qm5_12741_q04_priority_20260902T070056Z_board_advisor.json`.
