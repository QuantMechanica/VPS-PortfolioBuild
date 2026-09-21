# FTMO D2g6 Demo day retro-audit

- Router task: `4505b206-3b25-4205-924b-560f4d7c4bb0`
- Trial: `FTMO_DEMO_BOOK_V3_D2G6_20260918`
- Audited collector prefix: 324,249,149 bytes / 453,275 rows, SHA-256 `402ead4eebded878a1071dcdd667769f78fb7269799765c7ab779ff4852f5bcc`
- Last included sample: `2026-09-21T18:42:39Z`
- Verdict: **1 BEHAVIOR_IDENTICAL / 2 POTENTIALLY_DIFFERENT / 1 MATERIALLY_INVALID**

This was a read-only reconstruction. No terminal, chart, EA, order, position,
halt file, AutoTrading state, or T_Live state was changed.

## Decision

| Prague day | Complete | Class | Prague 00:00 balance/equity | Broker 00:00 balance/equity | Persisted EA anchors | Low equity | Realised P/L | Nearest EA 3% guard | Requests (lower bound) |
|---|---:|---|---:|---:|---|---:|---:|---:|---:|
| 2026-09-18 | yes | **MATERIALLY_INVALID** | unavailable | unavailable | 99,811.51 (2); 99,847.04 (4) | 99,812.09 observed | unavailable; +1.73 observed | 2,960.46 observed only | 11 |
| 2026-09-19 | yes | **POTENTIALLY_DIFFERENT** | 99,813.22 / 99,813.22 | 99,813.22 / 99,813.22 | stale 99,811.51 (2); 99,847.04 (4) | 99,813.22 | 0.00 | 2,961.59 | 0 |
| 2026-09-20 | yes | **POTENTIALLY_DIFFERENT** | 99,813.22 / 99,813.22 | 99,813.22 / 99,813.22 | stale values, then 99,813.22 after Sunday open | 99,813.22 | 0.00 | 2,961.59 | 1 |
| 2026-09-21 | no | **BEHAVIOR_IDENTICAL** | 99,813.22 / 99,813.22 | 99,813.22 / 99,813.22 | 99,813.22 (6) | 99,713.95 | +118.88 partial | 2,895.13 | 4 |

There are **2 structurally valid completed days versus the 14-day minimum**.
The counting rule is explicit in the sidecar: a completed day counts unless it
is `MATERIALLY_INVALID`. The numerically identical 21 September observation is
not counted yet because that Prague day was still open at the cutoff. Twelve
more completed, structurally valid days are required; the result must not be
used to shorten the representative experiment.

These days are **PRE_SUNDAY_LIVE_TRIAL evidence only**. They are not merged
into the clean Sunday 2026-09-27 representative Demo generation.

## Why the weekend days are not `BEHAVIOR_IDENTICAL`

The account itself was flat and unchanged at both clock boundaries on 19 and
20 September. That alone is insufficient. The deployed kill switch derives
its day from `TimeCurrent()`, and the last Friday market tick left server time
at `2026-09-18T23:54:59` until Sunday. Consequently no sleeve executed a
Friday- or Saturday-midnight refresh. The append-only logs prove Sunday
restarts restored the old values:

- magics `107060001` and `114220004`: 99,811.51;
- magics `104030002`, `107000003`, `132130000`, and `412190000`: 99,847.04.

The correct Prague-midnight balance was 99,813.22. The maximum anchor error was
+33.82. The highest (most restrictive) deployed 3% floor was therefore
96,851.63 instead of 96,818.82. Equity never fell below 99,813.22 on either
weekend day, leaving at least 2,961.59 to that guard. There were no requests on
19 September and one pending-order request on 20 September, after Sunday open
and the account-flat 99,813.22 rollover. Thus the defective mechanism was
numerically different but could not change a kill, trade, or headroom decision:
`POTENTIALLY_DIFFERENT`, not `MATERIALLY_INVALID`.

On 21 September, broker midnight (21:00Z) and Prague midnight (22:00Z) both
had balance/equity 99,813.22 and zero floating P/L. All six files persisted
99,813.22. The wrong mechanism was therefore numerically identical for that
day only. This is not an approval of `anchor_offset=0`.

## Why 18 September is invalid

The collector begins at 04:39:24Z, 6 hours 39 minutes after the Prague day
started. Neither midnight boundary is present. Its first row already contains
one XAGUSD position and +32.35 floating P/L, while the six restored anchors
split between 99,811.51 and 99,847.04. The observed low, 99,812.09, remained
2,960.46 above the most restrictive deployed floor, but the missing boundary
means the true FTMO balance anchor, earlier equity path, and whole-day
rule-headroom cannot be reconstructed. That is a material evidence defect.

## Boundary, positions, and risk events

For every available boundary from 18 September 21:00Z onward, samples exist
at both `T-1s` and `T`. There was no floating P/L and no open position at any
broker or Prague midnight. Two XAUUSD pending orders crossed the 19/20
boundaries; a USDCAD pending joined before the 21 September Prague boundary.
Pending orders are not floating P/L, but their counts are retained in the
machine sidecar.

No `KILL_SWITCH_TRIP`, daily-loss halt, manual halt, portfolio halt, flatten,
or next-day halt-reset event occurred for a roster magic. The only matching
risk events were configuration-time `KILL_SWITCH_INIT` and anchor-restoration
events, which are not halts.

## Compliance-sentinel request count

The EA JSONL logs expose framework TradeManager requests (`TM_OPEN`,
`TM_CLOSE`, `TM_MODIFY`, `TM_REMOVE_PENDING`). This is a documented lower
bound because terminal/broker-internal traffic is not logged. Collector
position and pending-order maxima provide the inventory cross-check.

| Prague day | Open | Close | Modify | Remove pending | Total | Peak positions / pending | Sentinel |
|---|---:|---:|---:|---:|---:|---:|---|
| 2026-09-18 | 7 | 1 | 0 | 3 | 11 | 1 / 4 | clear |
| 2026-09-19 | 0 | 0 | 0 | 0 | 0 | 0 / 2 | clear |
| 2026-09-20 | 1 | 0 | 0 | 0 | 1 | 0 / 3 | clear |
| 2026-09-21 (partial) | 2 | 1 | 0 | 1 | 4 | 2 / 3 | clear |

No day exceeded 2,000 requests and no hyperactive pattern is present. Failed
attempts are intentionally included in the request total because they still
represent server-request pressure.

## Reproduction and provenance

The machine-readable result is
[`demo_day_classification.json`](demo_day_classification.json). It binds an
immutable, CRLF-terminated prefix of the still-growing collector by byte count
and SHA-256. Rows were streamed once and grouped by `prague_day_key`; exact
21:00Z broker and 22:00Z Prague boundary rows were paired with their preceding
one-second sample. Daily low equity and first/last inventories came from all
453,275 bound rows.

Request and risk-event counts came from the six append-only `QM5_*.log` files,
restricted to the six roster magics and grouped from `ts_utc` through
`Europe/Prague`. Persisted anchor values/times are bound to the restoration
events plus the six state-file hashes already recorded in the diagnosis. The
rollover inference follows deployed source behavior:
`QM_KillSwitchCheck()` calls `QM_KillSwitchRefreshBrokerDay()`, which changes
and saves the anchor only when tick-derived `TimeCurrent()` produces a new
server-day key.

External FTMO headroom is also retained separately in the sidecar: balance at
Prague midnight minus USD 5,000. It is not substituted for the deployed EA's
3% internal breaker when measuring whether the anchor defect could change an
EA-side decision.
