# FTMO demo D2g6 kill-switch day-anchor diagnosis

- Router task: `4fd8222f-cc62-4e3c-99c1-ecc661e094cf`
- Scope: read-only diagnosis of terminal `81A933A9AFC5DE3C23B15CAB19C63850`
- Deployed book: `FTMO_DEMO_BOOK_V3_D2G6_20260918`
- Source/build commit: `d316791011a307598881dcbc4cd6f6509c65a391`
- Verdict: **EA-side FTMO configuration rollout defect; the pulse warning is not an event-name mismatch.**

No EA, preset, terminal, chart, order, position, halt file, AutoTrading state, or
T_Live state was changed.

## Executive finding

1. `day_key=2026263` is the correct MQL key for **2026-09-21**, not
   2026-09-20. MQL `day_of_year` is zero-based, so 1 January is 0 and
   21 September 2026 is 263.
2. The six installed D2g6 aliases use `anchor_offset=0` and
   `anchor_max_be=0`. Their kill-switch day is therefore derived from FTMO
   broker/server time at broker midnight and the baseline is raw equity. It is
   not the intended FTMO Prague-midnight configuration.
3. For the 20/21 September rollover, the wrong mechanism produced the right
   number by coincidence: the account balance and equity were both
   `99,813.22` at 21:00Z (broker midnight) and at 22:00Z (Prague midnight).
   Thus `day_start_equity=99813.22` is numerically correct for 21 September,
   but the configuration is unsafe for a rollover where balance/equity changes
   during the one-hour gap or where floating P/L exists at reset.
4. No post-rollover intraday re-anchor is observed. All six state files still
   carry `99,813.22` after account balance/equity subsequently moved. The first
   D2g6 attachment on 18 September did necessarily establish a startup-time
   baseline, and the append-only logs do not contain a dedicated event for
   ordinary daily rollovers; those are observability limits, not evidence that
   a later intraday re-anchor occurred.
5. `KS_DAY_ANCHOR_SET` and `KS_BOOK_TAG_SET` are the exact event names. They are
   emitted only by explicit setter calls. The deployed sources call neither
   setter, so `ks_day_anchor_missing:0/6` and `ks_book_tag_missing:0/6` are true
   rollout warnings, not a pulse parser defect.

## 1. Clock and day-key semantics

The deployed include is unchanged from the alias-build commit. The current
file SHA-256 is
`f5675dbc9e7fbe99c73d8635c3a859e40fb49edf1f7fca1a79941acb2d84ba92`.

- `framework/include/QM/QM_KillSwitch.mqh:48-52` converts its argument with
  `TimeToStruct` and returns `year * 1000 + day_of_year`.
- `framework/include/QM/QM_KillSwitch.mqh:119-122` supplies
  `TimeCurrent() + anchor_offset_hours * 3600`.
- MetaQuotes documents `TimeCurrent()` as last-known trade-server time, not
  machine-local or UTC time:
  <https://www.mql5.com/en/docs/dateandtime/timecurrent>.
- MetaQuotes documents `MqlDateTime.day_of_year` as zero-based, with 1 January
  equal to zero:
  <https://www.mql5.com/en/docs/constants/structures/mqldatetime>.
- `framework/include/QM/QM_KillSwitch.mqh:36-40` sets the historical defaults
  to offset `0` and equity-only anchoring.

Therefore the default expression in these aliases is:

`day_key = year(TimeCurrent()) * 1000 + zero_based_server_day_of_year(TimeCurrent())`

For 2026-09-21, that value is `2026 * 1000 + 263 = 2026263`. The ticket title's
interpretation of 263 as 20 September is an off-by-one error.

The raw collector independently proves the boundary difference in the running
account. In
`MQL5/Files/QM/ftmo_trial/FTMO_DEMO_BOOK_V3_D2G6_20260918/trial_telemetry_raw.jsonl`:

- line 309693 / sequence 20149: at `2026-09-20T21:00:00Z`,
  `prague_day_key=20260920`, balance/equity `99813.22/99813.22`;
- line 313671 / sequence 24127: at `2026-09-20T22:00:00Z`,
  `prague_day_key=20260921`, balance/equity `99813.22/99813.22`;
- line 314100 / sequence 24556: at `2026-09-20T22:05:00Z`, the Prague key and
  values remain `20260921` and `99813.22/99813.22`.

The EA logs show `ts_broker=2026-09-21T00:05:*` at about 21:05Z, confirming the
summer server clock was UTC+3 while Prague was UTC+2. The intended stable-season
translation on 21 September was therefore offset `-1`, not `0`.

## 2. Deployed-build binding and missing calls

`docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/RECEIPT_alias_builds.md:1-14`
binds the aliases to the six canonical sources and include tree at `d316791011`.
Read-only SHA-256 readback of the installed
`MQL5/Experts/QM_FTMO/*.ex5` files exactly matched receipt rows 7-12:

| EA | installed alias EX5 SHA-256 |
|---|---|
| 10403 | `fbe198f7210b52853741ae3c987416b0b51ebd2a521c70fe18b71061de27ebcc` |
| 10700 | `5dcb1a235f5b78cdff274eaa32e48d4713d19f1415da3a2153c98e48b501d6a1` |
| 10706 | `e6701607ef44e02733558bde9cf096aed9ab8e83a57fea4d64c84ad6259574e4` |
| 11422 | `76e59831ca36c4bd55312686c56c1266f1f11c784b4942250e362b9a9a6c5bb1` |
| 13213 | `85b5d4ed6443d77cc24db2b8046a42473e9e0572407680731d0e60733ad9d2e8` |
| 41219 | `e00915b9ac7cbffe177680863f77871262629a42dc64e5385e4580707b1d10ae` |

The six current MQ5 source hashes also exactly match the receipt and none has
changed since `d316791011`. At that revision, each source has one
`QM_FrameworkInit` call and zero occurrences of both
`QM_KillSwitchSetDayAnchor` and `QM_KillSwitchSetBookTag`:

| EA | `QM_FrameworkInit` line | day-anchor calls | book-tag calls |
|---|---:|---:|---:|
| 13213 | 439 | 0 | 0 |
| 10706 | 388 | 0 | 0 |
| 10700 | 393 | 0 | 0 |
| 11422 | 256 | 0 | 0 |
| 10403 | 408 | 0 | 0 |
| 41219 | 163 | 0 | 0 |

`framework/include/QM/QM_Common.mqh:357` calls `QM_KillSwitchInit` with no
FTMO override. `QM_KillSwitchInit` preserves the default configuration and
writes it to state (`QM_KillSwitch.mqh:469-535`). The runtime logs corroborate
this: `KILL_SWITCH_INIT` reports the unscoped
`QM\\halt\\portfolio_dd.signal`, and there are zero setter events for all six
magics.

## 3. Live state readback

All files below contained `day_key=2026263`,
`day_start_equity=99813.22`, `anchor_offset=0`, and `anchor_max_be=0` when
re-read after the later account movement.

| EA / magic | state write UTC | state SHA-256 |
|---|---|---|
| 13213 / 132130000 | 2026-09-20 21:05:00Z | `455b7aa6e85a344957d69fa5087e3bc2c83ffc7b792fd7d4a2f5e9def8e5028f` |
| 10706 / 107060001 | 2026-09-20 21:05:02Z | `59000c84aacc7f986ec6fb84d92322517b93c421aea20dcc646f542c3fb2bb5f` |
| 10700 / 107000003 | 2026-09-20 22:05:00Z | `fe3e6b4ad0125b32c01b6cd286bfe52fd4280074aa869c48b69117ddd1b01271` |
| 11422 / 114220004 | 2026-09-20 21:05:13Z | `f904389bf676b93b2879c0b6726943dad5f62d59882d61b8a71d6b75d3e51ede` |
| 10403 / 104030002 | 2026-09-20 22:05:00Z | `687270e2415b7da75fec0055833bd2082936bd6e344964146821704b55918a97` |
| 41219 / 412190000 | 2026-09-20 22:05:00Z | `4b2faa5cbb277b29d04cf35fd7bb2cdbb27274dc666f1a684f1eee15f39445ee` |

This also corrects a second premise in the ticket title: the 13213 state file
was written at 21:05Z (23:05 CEST), not 22:05Z. The three 22:05Z writes do not
prove Prague configuration; those slower sleeves simply reached their first
post-boundary kill-switch check then. Their persisted offset remains zero.

`QM_KillSwitchRefreshBrokerDay` recomputes the anchor only when the derived key
changes and then saves state (`QM_KillSwitch.mqh:258-276`). Every normal check
calls it (`QM_KillSwitch.mqh:622-635`). It does **not** emit
`KS_DAY_ANCHOR_SET`; it emits only a reset event when clearing a prior halt.

At collector sequence 75162 (`2026-09-21T06:49:15Z`), the account had moved to
balance/equity `99809.42/99805.59` with two open positions, while all six state
files still had `day_start_equity=99813.22` and the hashes/write times above.
Thus no intraday re-anchor is observed on 21 September. The source also restores
a same-key persisted anchor on restart (`QM_KillSwitch.mqh:175-255`) instead of
silently replacing it.

## 4. Is the 21 September FTMO anchor correct?

FTMO's current primary documentation says the Maximum Daily Loss limit is
recalculated at 00:00 CE(S)T from the account balance recorded then, while
account equity is what must remain above the resulting limit:
<https://ftmo.com/en/trading-objectives/>.

**Answer:** the value `99,813.22` is correct for this particular rollover
because the collector proves balance and equity were both `99,813.22` at
22:00Z, Prague midnight. The kill-switch implementation/configuration is not
correctly aligned: it armed the new key at broker midnight for the active
21:05Z sleeves and it is configured to raw equity rather than an explicit FTMO
balance-derived mode. No actual rule breach or weakened numeric baseline is
evidenced for 21 September; the defect is a future-rollover exposure.

The framework comments call `max(balance,equity)` the intended FTMO option
(`QM_KillSwitch.mqh:124-130,562-573`). FTMO's public rule currently says
midnight balance. `max(balance,equity)` is at least as conservative as balance
when floating equity is higher and equals balance when equity is lower, but it
should be documented as a deliberate internal cushion rather than asserted to
be the exact external formula.

## 5. Pulse interpretation

`tools/strategy_farm/ftmo_trial_pulse.py:504-545` scans the roster-bound magics
and counts the exact `KS_DAY_ANCHOR_SET` and `KS_BOOK_TAG_SET` strings.
`ftmo_trial_pulse.py:631-652` explicitly documents them as attach-time setter
proofs, not rollover events. `QM_KillSwitchSetBookTag` emits the former book
event at `QM_KillSwitch.mqh:545-559`; `QM_KillSwitchSetDayAnchor` emits the day
event at `QM_KillSwitch.mqh:574-594`.

The pulse's `0/6` counts are therefore correct. The missing events plus the
state values prove the calls did not happen. A parser/event-name-only fix would
mask the EA-side omission.

## 6. Proposed repair (not applied)

The next OWNER/Fable-authorized maintenance build should:

1. Add a fail-closed FTMO execution contract to all six sleeves (preferably in
   one governed framework initializer rather than six copy-pastes). After
   `QM_FrameworkInit`, it must successfully apply a book tag and a Prague day
   anchor before `INIT_OK`; any failed setter must return `INIT_FAILED`.
2. For the current 21 September stable-season topology, the existing API call
   would be `QM_KillSwitchSetDayAnchor(-1, true)`. The `true` mode is the
   framework's documented conservative internal cushion. The book tag must be
   the governed FTMO book identifier, not the unscoped default.
3. Do not hard-code `-1` as an all-year truth. The include already documents
   US/EU DST divergence windows where `-2` is needed
   (`QM_KillSwitch.mqh:562-570`). The durable fix is a tested Prague-calendar
   key/boundary helper or a governed seasonal schedule, with boundary tests for
   both stable seasons and both divergence windows.
4. Emit a distinct `KS_DAY_ROLLOVER` event from
   `QM_KillSwitchRefreshBrokerDay` containing old/new key, server time,
   effective Prague time, offset/mode, and selected anchor. Keep
   `KS_DAY_ANCHOR_SET` as configuration proof.
5. Extend the pulse to parse each expected magic's state file and compare the
   persisted configuration and translated date with the roster's FTMO
   contract. A state value of `anchor_offset=0` or a missing governed book tag
   should remain actionable even if an old setter event exists in an append-only
   log.
6. Reconcile the framework's `max(balance,equity)` wording with FTMO's current
   balance-at-midnight rule and encode the chosen conservative policy as a named
   mode. Do not infer that semantic choice from a boolean whose name is not
   externally auditable.

No rebuild or running-demo deployment belongs to this diagnosis ticket.

## Verification performed

- Bound installed EX5 hashes to the alias receipt.
- Bound all six current source hashes to the receipt and confirmed no diff from
  `d316791011`.
- Counted initializer/setter calls directly from the six source blobs at the
  deployed revision: `QM_FrameworkInit=1`, both setters `=0` per source.
- Read all six live state files twice and bound their values, write times, and
  SHA-256 hashes.
- Compared append-only collector rows immediately before/at both broker and
  Prague midnight and after subsequent balance/equity movement.
- Reviewed the live EA event streams and pulse scanner/event contract.
- `git diff --check` is required on this artifact before commit.
