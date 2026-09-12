# FTMO request-time slippage stream — first trading-week capture

Task: `f8ffb1c5-83fe-46e7-9bf2-ffa8bbb6e986`  
Predecessor: `17758960-375c-4ce5-80db-a14c261838dd`  
State: **IN_PROGRESS — 2/4 symbols complete; two symbols had no fill**

## Read-only design

`tools/strategy_farm/portfolio/collect_ftmo_slippage_stream.py` attaches only
to the one already-running FTMO demo terminal after proving its process,
account `1514536732`, server `FTMO-Demo`, and exact data-directory identity. It
reads order/deal history and the terminal's broker tick archive. It contains no
trading call, terminal launch/control, scheduler change, or AutoTrading surface.

For market orders, the reference is `order.time_setup_msc`; the latest valid
broker tick at or before that timestamp supplies executable ask for buys and
bid for sells. Quotes older than 2,000 ms fail closed. For pending orders, the
fill/trigger timestamp is used and explicitly identified as such; the original
pending-order setup quote is not misrepresented as the fill reference. Each
observation records request, acknowledgement, and fill timestamps, ticket,
position, magic, volume, fill, quote age, point-normalized signed adverse
slippage, and provenance.

The CLI requires a Monday-UTC start, at least five days, and a fresh direct
child of `D:/QM/reports/ftmo/slippage_stream/`. Outputs are immutable per-run
receipts plus a hash manifest. It is a one-shot extractor: no background loop
or new scheduled task was installed.

## First full-week capture

Window: `2026-09-07T00:00:00Z` through `2026-09-12T10:58:00Z`  
Root: `D:/QM/reports/ftmo/slippage_stream/20260907_20260912_taskf8ffb1c5`  
Manifest SHA-256: `dc2fbc3cb675847254f9db82e0705fffebfeaaa310f74be351d9bf8f2804756e`

| Symbol | Receipt SHA-256 | Fills | Complete | Mean observed adverse points | Status |
|---|---|---:|---:|---:|---|
| GBPUSD | `f6faea120055a6f59ba0be14eb487f4852586ee7fc39147b1511d141f55a592c` | 2 | 2 | -1.0 | `COMPLETE` |
| EURUSD | `207bc175ffd83bfda23d46eaf01437043599a7a7b140f6c9c325327796a306f7` | 2 | 2 | 0.0 | `COMPLETE` |
| USDCAD | `9998246517f250619cd8b04450c576dffea0d4d2b4e530fe4c14bb2f5810cef1` | 0 | 0 | n/a | `MISSING_NO_FILL` |
| USOIL.cash | `42028a25f7d0d6fa658138026cedcbeedce69fb731fac1d68620e98fc0c3d7c3` | 0 | 0 | n/a | `MISSING_NO_FILL` |

The GBPUSD quotes precede their request timestamps by 88 ms and 7 ms. All four
observed GBPUSD/EURUSD fills have fresh bound quotes and complete request/ack/
fill timing. A negative observation is retained as price improvement; it is not
silently floored or converted into a cost-policy threshold.

The two zero-fill rows are not imputed. Four-symbol acceptance therefore
remains unmet until USDCAD and USOIL.cash produce native fills in a Monday-based
window (or a broker fill-quality export supplies equivalent evidence). A future
run must use a new immutable output root and may extend the Monday start through
the first qualifying fills.

## Comparator result

`docs/ops/evidence/2026-09-09_ftmo_shortlist/compare.py` now hash-verifies the
slippage manifest and each receipt, combines the stream with the predecessor's
native commission receipts, and sets `cost_eligible` only when both are
complete.

| Pair | Commission | Slippage | `cost_eligible` |
|---|---|---|---|
| QM5_10706 / GBPUSD.DWX | observed | complete, 2 samples | true |
| QM5_11421 / EURUSD.DWX | observed | complete, 2 samples | true |
| QM5_11422 / USDCAD.DWX | missing, no fill | missing, no fill | false |
| QM5_13054 / XTIUSD.DWX | missing, no fill | missing, no fill | false |

The shortlist still selects zero incumbents: only 2/4 investigation symbols are
cost-eligible, USDCAD/USOIL lack any fill evidence, and matched spread remains
incomplete. No verdict, threshold, roster, or book changed.

- `comparison.json` SHA-256:
  `ee81a7f54e9d6f7507b6537c3a56a980cc8b1a0cef39d269d016d3da9c1344fa`
- `comparison.csv` SHA-256:
  `5529a7b4433a1f68293b38f1d87595dde6ced9b27c36ab9ae85ed11359f24f47`
- Repeat comparator run: both hashes identical.

## Verification and exclusions

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_collect_ftmo_slippage_stream.py \
  tools/strategy_farm/tests/test_ftmo_trial_pulse.py
34 passed

python -m compileall -q \
  tools/strategy_farm/portfolio/collect_ftmo_slippage_stream.py
PASS

git diff --check -- <scoped paths>
PASS
```

No EA source/binary was changed or installed; `framework/EAs`, T1–T12,
`T_Live`, the factory database, terminal processes, positions, orders, and
AutoTrading were untouched. The only external writes are the new immutable
read-only capture receipts beneath the stated report root.
