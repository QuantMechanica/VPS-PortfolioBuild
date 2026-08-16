# QM5_10000 SL/TP normalization equivalence canary

Date: 2026-08-17 (Europe/Berlin)

Router task: `b817fcb3-f650-4c60-9645-809f88363e03` (priority 86)

Branch: `agents/board-advisor`

## Outcome

The requested one-EA rebuild and append-only Q02 handoff are complete. The
new Q02 work item is still pending, so the required exact metric comparison
cannot yet be made and **no equivalence verdict is claimed**.

- Rebuilt EA: `QM5_10000_ff-tasayc-cci-breakout` only
- Build commit: `8904844fb79ad64b2e5a49a67c65f3af57f81594`
- Fresh Q02 work item: `78979d0f-1587-4ecf-b880-5eb1d792802d`
- Source baseline retained unchanged: `0e75dab8-9be1-47ca-93ee-df50b1afcd63`
- Current canary state: `pending`, attempt 0, unclaimed, no evidence path
- Review disposition: `CANARY_ENQUEUED_PENDING`; equivalence remains
  fail-closed and unproven until terminal Q02 evidence exists.

## Baseline of record

The immutable baseline summary is:

`D:/QM/reports/work_items/0e75dab8-9be1-47ca-93ee-df50b1afcd63/QM5_10000/20260723_003136/summary.json`

It records USDJPY.DWX H1, model 4, 2018-07-02 through 2022-12-31, result
`PASS`, with these exact run metrics:

| Metric | Baseline | Fresh canary | Exact match |
|---|---:|---:|---|
| Profit factor | 0.90 | unavailable | not evaluated |
| Trades | 1,190 | unavailable | not evaluated |
| Net profit | -5,852.88 | unavailable | not evaluated |
| Drawdown | 8,316.56 (8.27%) | unavailable | not evaluated |

The baseline binds EX5 SHA-256
`6046003fff14bad6b312be2606aaa555210a87ec8fd49dd04c5159e656e3bf12`,
MQ5 SHA-256
`f49c12e5c7a4cef379597440d6cafd6dd9c048eee5ed3b9aba4694f037368ef4`,
and setfile SHA-256
`7c00d3f2e3f705b61cfbaf6675a1de742b6dc3bc53df3305f61d10ea6379698b`.

## Controlled rebuild

Before rebuilding, the EA had no pending or active work item. The strict build
was run for exactly `QM5_10000_ff-tasayc-cci-breakout`:

```powershell
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_10000_ff-tasayc-cci-breakout -Strict
```

Focused verification:

- Strict build report:
  `D:/QM/reports/framework/21/build_check_20260816_235056.json` — `PASS`, zero
  failures and zero warnings.
- Compile summary:
  `D:/QM/reports/compile/20260816_235056/summary.csv` — `PASS`, 0 errors and
  0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260816_235056/QM5_10000_ff-tasayc-cci-breakout.compile.log`.
- Build guardrails: `PASS`; news stale maximum remains 336 hours.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`.
- USDJPY setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

The fresh execution identities are:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `180b04c70bd27b4f94556589810c0b9c6726be12badb76f25a8702823e336b3a` |
| EX5 | `334bef9ee9cd7f872437eb617d8572f05d5e34789b7d2d3992f4fbb464c46a8d` |
| USDJPY setfile | `8d408c63f89a4637b85e97f1a170f05dd4967548d8b18c5ccd77d1a697aea2f2` |

## Archived-source correction

The two normalization edits in the archived pre-rekey EA were reverted in the
same build commit. Its momentum-band trail again computes the raw archived
expressions:

```mql5
const double vwap_sl = g_session_vwap - atr_half;
const double vwap_sl = g_session_vwap + atr_half;
```

No archived EA was rebuilt.

## Append-only Q02 handoff

The ordinary current-binary rerun path correctly refused the pre-binding legacy
PASS (`stale_pass_source_binding_missing_or_invalid`). The canonical governed
pre-binding migration path was then used:

```powershell
python tools/strategy_farm/farmctl.py seed-fresh-q02 `
  --ea QM5_10000 `
  --old-work-item-id 0e75dab8-9be1-47ca-93ee-df50b1afcd63 `
  --requal-reason "Equivalence canary for framework commit 8cabfe613 plus caller normalization commit 3d853ab6b: rebuild only QM5_10000 and require exact USDJPY Q02 metrics; preserve the pre-binding PASS baseline row." `
  --expected-current-ex5-sha256 334bef9ee9cd7f872437eb617d8572f05d5e34789b7d2d3992f4fbb464c46a8d
```

This created exactly one successor, work item
`78979d0f-1587-4ecf-b880-5eb1d792802d`, bound to the fresh MQ5, EX5, and
setfile hashes above. It inherited USDJPY.DWX H1 and the exact baseline window
2018-07-02 through 2022-12-31. Custom-history archive admission is `ACTIVE`.
The old PASS row was not altered.

At the final queue snapshot there were seven active factory work items (the
configured ceiling) and 1,003 eligible pending items. The canary was rank 222
under the canonical claim selector. It was not reprioritized or manually
dispatched, and no active T1-T10 run was interrupted.

## Acceptance boundary

When the fresh work item reaches terminal evidence, compare its reported
`profit_factor`, `total_trades`, `net_profit`, and `drawdown` against the table
above using exact values. Any difference refutes behavioral neutrality. Until
then the only supported verdict is `NO_EQUIVALENCE_VERDICT`.

No T_Live file, AutoTrading state, portfolio gate, deploy manifest, or live
configuration was touched. No terminal was started manually.
