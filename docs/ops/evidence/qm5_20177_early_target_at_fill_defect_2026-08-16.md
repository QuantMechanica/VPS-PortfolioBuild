# QM5_20177 - targets computed from geometric level, not fill - CONFIRMED - 2026-08-16

Router task `9e6b271a-a1eb-4627-a374-eb07e951c646` (priority 92, triage_failure).
`QM5_20177_carney-ab-cd-pattern-h4-r1-recovery`. No gate change, no T_Live, no code
edited (confirm/refute + audit + proposed fix only, per task scope).

## Verdict: CONFIRMED

`Strategy_ManageOpenPosition` computes T1/T2 purely from the pre-entry projected `D`/`C`
harmonic pivot levels and never checks them against the price the position actually
filled at. Six real trades across two symbols (all trades observed in both runs) show
the partial close firing 0-2 seconds after entry and the full close firing 0-8 seconds
after entry, every single time. This is not a strategy edge - the position round-trips
for the spread on every entry because the "target" was already behind the fill price
the moment the order landed.

## Code (`framework/EAs/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery/QM5_20177_carney-ab-cd-pattern-h4-r1-recovery.mq5`)

- Entry (long branch, short is symmetric): `req.price = ask` (line 233) is sent only
  after `touch_ok` (price within `projection_touch_atr_mult * ATR` = 0.5xATR of the
  projected `D`, lines 222-224) **and** `confirm_ok = (c1.close > c2.high)` (line 225) -
  i.e. the confirmation bar must already have closed *beyond* the touch bar's extreme
  before the order is sent. By construction the fill can already be a meaningful
  fraction of the `D->C` leg away from `D`.
- Targets, set once at entry and fixed for the life of the trade (lines 332-333):
  `t1 = D + t1_fib*(C-D)`; `t2 = D + t2_fib*(C-D)` with `t1_fib=0.382`, `t2_fib=0.618`
  (setfile-confirmed, `framework/EAs/.../sets/*_backtest.set`).
- Check (lines 335-337): `t1_hit = is_buy ? (bid >= t1) : (ask <= t1)` against **current**
  bid/ask - nothing here, or anywhere else in the file, compares `t1`/`t2` to
  `PositionGetDouble(POSITION_PRICE_OPEN)`. If the fill itself is already past `t1` (and
  possibly `t2`), the very first tick of `Strategy_ManageOpenPosition` after entry fires
  the partial, and often the full close, immediately.

This is exactly the `required_work` hypothesis in the router task - confirmed, not
refuted.

## Real trade evidence (report.htm Deals/Orders + structured logger, both runs)

USDJPY.DWX Q02 run `D:\QM\reports\work_items\c7f7a083-837c-470e-9501-fec5eb566f28\QM5_20177\20260816_181004\raw\run_01\report.htm` (all 4 trades in the run):

| entry time (broker) | dir | fill | partial close | delta | full close | delta |
|---|---|---|---|---|---|---|
| 2018.11.19 04:00:00 | short | 112.693 | 112.697 | **0s** (same second) | 112.696 | 8s |
| 2019.03.01 04:00:02 | long | 111.651 | 111.648 | 1s | 111.649 | 1s |
| 2021.02.09 04:00:00 | short | 105.126 | 105.128 | 2s | 105.129 | 2s |
| 2022.06.07 04:00:00 | long | 132.232 | 132.232 | **0s** (same second, same price) | 132.231 | 0s |

Structured logger (`logger_sample.jsonl`) for the first trade confirms the partial fires
on the **identical broker timestamp** as the entry, not merely the same second by
report-table rounding: `TM_OPEN` and `TM_PARTIAL_CLOSE` both stamped
`ts_broker: 2018-11-19T04:00:00`, `reason: QM_EXIT_STRATEGY` (the fib-target exit, not a
stop). Entry order carried `sl: 113.08` (`ENTRY_ACCEPTED` payload) - with
`sl_atr_mult=1.0` this pins `D = 113.08 - ATR14`, i.e. `D` sits *above* the 112.693 fill
by roughly one ATR, consistent with price having already fallen from `D` through the
touch/confirm bars before the sell order was ever sent.

GBPUSD.DWX Q02 run `D:\QM\reports\work_items\ba38e217-fc92-4265-8678-f6c910f898e8\QM5_20177\20260816_180825\raw\run_01\report.htm` (first 2 of 6 trades, same signature):

| entry time (broker) | dir | fill | partial close | delta | full close | delta |
|---|---|---|---|---|---|---|
| 2019.11.20 04:00:00 | short | 1.29062 | 1.29069 | 1s | 1.29069 | 2s |
| 2020.03.05 12:00:00 | long | 1.29196 | 1.29189 | **0s** | 1.29187 | **0s** |

Six real trades, two symbols, four different years/regimes, one pattern every time: the
"trade" is a spread-sized round-trip that starts and ends within single-digit seconds.
This matches the router payload's own EURUSD/WS30 trade counts (8/6/8/14 trades, PF=0.00,
losses sized like spread not stop) exactly.

## Consequence already flagged by the router task, reconfirmed here

`QM5_20177` was RETIRED on the frequency-floor rule using trade counts this defect
produced - that retirement is not a valid strategy verdict and must not stand. The
OWNER-authorized `QM5_20177` variant (2026-08-16 decision item 5) must wait for the
repaired base; building it on the current code would inherit the same defect.

## Proposed fix (per the router task's own framing - not a partial-suppression patch)

Reject the entry, don't just skip the partial: an entry whose T1 is already satisfied at
signal time is an entry that should not have been taken (a later partial-suppression
patch would still take a trade for a "reversal from D" that has already reversed most of
the way to `C`, changing the risk/reward this strategy is supposed to have, not just its
bookkeeping).

- In `Strategy_EntrySignal`, after computing `d_proj`/`C` for each branch (lines
  221/265) and before setting `long_ok`/`short_ok` (lines 229/273), compute `t1` with the
  same formula used in `Strategy_ManageOpenPosition` and require the signal price to be
  strictly on the correct side of it: long needs `ask < t1`; short needs `bid > t1`.
  Fold this into the existing `long_ok`/`short_ok` boolean alongside `touch_ok` /
  `confirm_ok` / the cooldown check.
- Re-derive `t1_fib`/`t2_fib` sensitivity: with `confirm_ok` requiring a full bar's close
  beyond the touch extreme, the confirmation gap itself may routinely consume more than
  38.2% of a typical `D->C` leg for this symbol/timeframe - the fix above will reject a
  large fraction of current "signals" as designed, which is the correct behavior, but
  card authors should know expected trade frequency drops accordingly.
- After the fix, requalify Q02 for `QM5_20177` on all currently-attempted symbols
  (USDJPY, GBPUSD, EURUSD, WS30, NDX, XAUUSD) - none of the existing verdicts are
  evidence about the strategy.

## Audit: is this a generic class or a QM5_20177 quirk?

Scoped the audit to the EAs actually at risk - pattern/harmonic/wave-projection
strategies that compute a partial-close target from a level fixed at signal time (the
generic mechanism named in the task), not the full ~370-file population that merely
calls the shared `QM_TM_PartialClose` framework helper (that helper is exit-mechanism
plumbing; the defect is specifically in what feeds it a target). Checked by file:

- **`QM5_20177`** (this EA) - **BUGGY**, confirmed above.
- **`QM5_11902_bermuda-triangle-123-fib-extension-h1`** - correct: computes
  `g_signal_tp1/tp2` from `PositionGetDouble(POSITION_PRICE_OPEN)` (line 522, 536-537),
  not from the pre-entry swing level. Good counter-example - the framework pattern is
  capable of doing this right.
- **`QM5_1376_harmonic-gartley-xabcd-h4`** - correct: same `POSITION_PRICE_OPEN`
  anchoring (line 492).
- **`QM5_20087_carney-three-drives-h4-r1-recovery`**,
  **`QM5_20088_carney-crab-pattern-h4-r1-recovery`**,
  **`QM5_20179_pesavento-abcd-pattern-h4-r1-recovery`** (the other three EAs in the same
  `-r1-recovery` cohort as this one), plus **`QM5_12939_carney-alternate-bat-h4`**,
  **`QM5_1445_carney-three-drive-h4`**, **`QM5_1482_carney-three-drive-harmonic-h4`**,
  **`QM5_1593_carney-bat-pattern-h4`**, **`QM5_1645`/`QM5_1649_carney-cypher-pattern-h4`**
  - all have a literally **empty** `Strategy_ManageOpenPosition() {}` - no runtime
    target-vs-price check exists to have this specific bug (their exits, if any, are
    fixed SL/TP set once at order-send, a different question this task did not audit).

So among the 11 EAs checked, `QM5_20177` is the only one carrying this specific defect -
it looks like an outlier in its own cohort (it alone got custom-written management
logic), not evidence of a codebase-wide pattern. That said, this audit covered 11 of the
~34 EAs whose filenames suggest pattern/harmonic/wave-projection strategies (`harmonic-`,
`-abcd-`, `gartley`, `butterfly`, `bat-`, `crab`, `cypher`, `three-drive`,
`goodman-wave-theory`, `vegas-wave`, etc. under `framework/EAs/`) - the remaining ~23 were
not checked and are a reasonable scope for a follow-up ops_issue task before calling the
class fully cleared.

No factory OFF/ON, no T_Live, no code edited as part of this diagnosis.
