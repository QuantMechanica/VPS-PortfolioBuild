# QM5_21502 / QM5_21505 weekly atomic-reverse repair

- Task: `0ad294b7-fca3-4014-b948-fb5ac5ed3aa6`
- Date: 2026-08-17
- Branch: `agents/board-advisor`
- Scope: `QM5_21502_xau-weekly-tsmom` and
  `QM5_21505_xag-weekly-lowvol-momentum` only
- Disposition: **REVIEW_READY**; no pipeline phase or economic verdict was run

## Outcome

Both EAs now prepare the fresh weekly signal before the signal-flip management
pass that may close an owned opposite position. Entry then fails closed whenever
*any* position for the EA's magic remains. This implements the approved cards'
close-then-open semantics without allowing a replacement order after a failed or
unsettled close.

The same two-hunk repair contract was applied to both EAs:

1. Immediately after `Strategy_PrepareWeeklySignal()`, call
   `Strategy_ManageOpenPosition()` again so signal-flip management sees the new
   weekly direction before entry evaluation.
2. Replace the direction-specific entry guard with
   `Strategy_HasOwnedPosition()`, so same-direction means hold and an uncleared
   opposite position blocks entry.

Source anchors after repair:

- QM5_21502: owned-position guard at `.mq5:272`; fresh signal / management
  ordering at `.mq5:437-443`.
- QM5_21505: owned-position guard at `.mq5:367`; fresh signal / management
  ordering at `.mq5:533-539`.

## Failure-mode correction

The originating review correctly found stale signal state and an incomplete
EA-local ownership guard. Its statement that the opposite order necessarily
opens as a hedge was too broad: `QM_EntryHasOpenPosition` in
`framework/include/QM/QM_Entry.mqh` independently rejects an order while the
same magic and symbol remains open. The deterministic pre-fix failure is
therefore a lost weekly reversal (the fresh entry is rejected, the old side may
close on a later tick, and the new-bar entry is not retried), while the local
code still failed to express the card's atomic contract. The repair addresses
both interpretations: close is attempted from fresh state, and entry remains
blocked until flat.

## Regression coverage

One parametrized fixture covers both source files:

`tools/strategy_farm/tests/test_qm5_21502_21505_weekly_atomic_reverse_static.py`

It pins these invariants:

- `QM_IsNewBar` -> `Strategy_PrepareWeeklySignal` -> fresh
  `Strategy_ManageOpenPosition` -> news entry gate -> `Strategy_EntrySignal`;
- exactly two management calls (per-tick safety plus fresh-state weekly pass);
- any owned position blocks entry, with no direction-specific fall-through;
- an opposite close failure blocks entry, a successful close permits entry,
  and a same-direction position remains a hold.

Focused result:

```text
python -m pytest tools/strategy_farm/tests/test_qm5_21502_21505_weekly_atomic_reverse_static.py -q
.....                                                                    [100%]
5 passed in 0.30s
```

Test SHA-256:
`0c58a8e10f94412d5ba742b3a1d5e3c7eac705b6ba6425896724de18283241e5`.

## Build verification

| EA | Pre-fix MQ5 SHA-256 | Repaired MQ5 SHA-256 | Rebuilt EX5 SHA-256 | Strict compile | Strict build check | Guardrails |
|---|---|---|---|---|---|---|
| QM5_21502 | `dd505e2c0dcdc10cc2cf87e049f8bf5a33c7b8d6c7e1faab1200c3545f05577f` | `46579e8498af0a5081496afc4581a37f858b08efc9718ad5823127d4931b27c6` | `0d8a1a355cb48612c754c29d4c11c4afceb83e6a4fa88e4225b3ad477a408a25` | PASS, 0 errors / 0 warnings | PASS, 0 failures / 0 warnings | PASS, stale ceiling 336 |
| QM5_21505 | `aba8cc756fb2aa5d0979520a56658430349f42fb3549e0b23fdcb993db06ed78` | `311deb260e57129d1fb35e5bc2875fc76f755711b2caeb95501e9bfe1bb63887` | `395c4747832acbcdf8a68d8598e53abe5786bdc6c538767c400884cd82b2aea1` | PASS, 0 errors / 0 warnings | PASS, 0 failures / 0 warnings | PASS, stale ceiling 336 |

Evidence:

- QM5_21502 compile:
  `framework/build/compile/20260817_183247/QM5_21502_xau-weekly-tsmom.compile.log`
  (`8dbb02355ee5ff09f92382ba5417c239b978fc29086eef8e13e05b5b126a67a3`)
- QM5_21502 build check:
  `D:/QM/reports/framework/21/build_check_20260817_183354.json`
  (`cd882b5d9c49e1d0fd888d54a1cae3fca8281c8b9dcf9cad6f4019c40de0c231`)
- QM5_21505 compile:
  `framework/build/compile/20260817_183320/QM5_21505_xag-weekly-lowvol-momentum.compile.log`
  (`f004661565b58f394c80b681c805cb9f991f769e0943fabe3cddfeb0f212d3d4`)
- QM5_21505 build check:
  `D:/QM/reports/framework/21/build_check_20260817_183412.json`
  (`631c8856849da015a14cf5ca998d494fed450d639f41f1aeff72a4d2cf6cb670`)

Backtest sets remain `RISK_FIXED=1000`, `RISK_PERCENT=0`; the EA inputs and
guardrail scan retain `qm_news_stale_max_hours=336`.

## Q02 lineage and mandatory requalification

No existing verdict was rebound or edited.

- `QM5_21505`, work item
  `253f23f0-5bb7-4840-b60f-fba2f5ebde9e`, has a Q02 PASS tied to pre-fix MQ5
  `aba8cc...` and EX5
  `0a292b63cfecbc46c33f0dc062b0f4b332c98b2b77e4bbcaf0f393009793a852`.
  Its evidence remains immutable pipeline truth for that defective build, but
  is **SUPERSEDED_FOR_STRATEGY_CONFORMANCE** and cannot promote or be carried
  forward. Summary evidence SHA-256:
  `e77044ecfb0498f7792d43bd1d3bb3cf5b89ebde999e43c336c8d4f78cea0feb`.
- `QM5_21502`, work item
  `14c3ff76-eded-40cf-b857-5e761a042e0e`, was still active on T3 during the
  repair and was not interrupted. It was dispatched from pre-fix MQ5
  `dd505e...`; any terminal result from that row is likewise
  **SUPERSEDED_FOR_STRATEGY_CONFORMANCE** and cannot promote or be rebound.

After this repair passes review, each EA must receive a fresh append-only Q02
work item bound to the repaired EX5 hash above. No successor was enqueued from
this repair ticket because the code remains in REVIEW.

## Scope and safety proof

- No active T1-T10 run was stopped or altered.
- No `T_Live`, AutoTrading, live roster, deploy manifest, or QM5_10771 file was
  touched.
- No pipeline phase was started and no pipeline verdict was inferred.
- `framework/registry/magic_numbers.csv` was not edited; observed SHA-256:
  `f1571c0a690920eae420f9d723f3a071a32ffd1cafb8d45c1f76a594e24f9e30`.
- `framework/include/QM/QM_MagicResolver.mqh` was not edited; observed SHA-256:
  `7981a1cc34132790aac478bdbaf46067b4c9725866482953cd6f28ed39305aef`.
