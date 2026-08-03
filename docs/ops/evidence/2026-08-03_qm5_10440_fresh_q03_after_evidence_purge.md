# QM5_10440 fresh Q03 after evidence purge

Date: 2026-08-03

Router task: `13fcd6a0-15a9-445f-95f8-a5d6dcfa6ffd`

Code commit: `8877592c2` (`fix(q03): allow sealed rerun after evidence purge`)

## Outcome

PASS for the enqueue contract. A new append-only Q03 work item,
`e9af192f-d525-42b0-8727-4b260aaeaf51`, was created for
`QM5_10440 / NDX.DWX / H1` from fresh Q02 PASS predecessor
`0b2bfb03-063c-49b2-b779-6c5c160730e6`. The factory claimed it naturally on
T1; it was `active` with no verdict when this evidence was written. No pipeline
verdict is inferred here.

Historical Q03 rows `9c7700c3-45df-42cc-8476-e37a7ef3adc3` and
`b1adfe17-625c-425d-a1d9-46135f35ae15` were not changed.

## Blocked identity

The required base identity was:

- EA: `QM5_10440_mql5-ohlc-mtf`
- symbol / timeframe: `NDX.DWX / H1`
- setfile: `C:\QM\repo\framework\EAs\QM5_10440_mql5-ohlc-mtf\sets\QM5_10440_mql5-ohlc-mtf_NDX.DWX_H1_backtest.set`
- historical base Q03: `9c7700c3-45df-42cc-8476-e37a7ef3adc3`,
  `done/PASS`
- purged evidence reference:
  `D:\QM\reports\work_items\9c7700c3-45df-42cc-8476-e37a7ef3adc3\QM5_10440\20260528_175754\summary.json`

The other cited evidence-backed row,
`b1adfe17-625c-425d-a1d9-46135f35ae15`, uses
`QM5_10440_mql5-ohlc-mtf_NDX.DWX_H1_backtest_ablation_04.set`; it is not the
base-setfile identity and remains ineligible as the append-only target.

## Contract change

The existing exact Q03 command remains the only entry point. A fallback is
allowed only when all of these checks pass under `BEGIN IMMEDIATE`:

- one exact terminal Q02 PASS predecessor is supplied and its evidence exists;
- the predecessor payload and current canonical MQ5, EX5 and setfile bytes have
  the same complete execution identity;
- `--expected-current-ex5-sha256` is present and matches the canonical EX5;
- `RISK_FIXED > 0` and `RISK_PERCENT = 0`;
- the explicitly named Q03 target has the same EA, symbol and setfile identity,
  is terminal, and its referenced evidence is absent;
- every other terminal Q03 row for that exact identity also has absent evidence;
- no pending/active exact-identity Q03 exists; and
- no terminal Q03 is already bound to the current EX5, including the cited
  purged target itself.

Any retained exact-identity evidence, identity mismatch, malformed source
payload, current-binary terminal result, open row, or artifact/hash drift is a
fail-closed refusal. The pre-spawn seal check now covers these fresh Q03 rows as
well as fresh Q02 seeds.

The new payload records the immutable source row and payload hash, purged
evidence path, all purged identity-row IDs, fresh Q02 predecessor, canonical
setfile identity, current MQ5/EX5/setfile hashes, runner identity, and fixed-risk
values. It inserts a new row and never updates a historical row.

## Production enqueue

An online SQLite backup was written before the live insert:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10440_q03_fresh_20260803T102856Z.sqlite`

The exact command was first exercised successfully against an online-backup
copy, then applied once to production:

```text
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_10440 --phase Q03 --from-work-item-id 0b2bfb03-063c-49b2-b779-6c5c160730e6 --append-only-rerun-of 9c7700c3-45df-42cc-8476-e37a7ef3adc3 --rerun-reason "OWNER 2026-08-03: 10440 Requalifikation on the new calendar-bundle binary after Q03 evidence purge" --expected-current-ex5-sha256 d9e7d5cdc1998aadf649287af6a5c13a854e42cddbda28c5732d03b34b8b70db
```

Created row: `e9af192f-d525-42b0-8727-4b260aaeaf51`.

Its sealed bindings read back from the production database were:

| Binding | Value |
|---|---|
| MQ5 SHA-256 | `0f22973a0e89166d76c39a5ef3bdaede5f6063ca37166ab9e18c69179a4d513b` |
| EX5 SHA-256 | `d9e7d5cdc1998aadf649287af6a5c13a854e42cddbda28c5732d03b34b8b70db` |
| Setfile SHA-256 | `9f85efc8e4c518d47b5fc9a1ed0e51aecff86f814ca3cb8a73b766fb1246c057` |
| Expert | `QM\QM5_10440_mql5-ohlc-mtf` |
| Symbol / period | `NDX.DWX / H1` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Fresh-Q03 fallback | `true` |
| Purged identity rows | `9c7700c3-45df-42cc-8476-e37a7ef3adc3` |

## Append-only verification

Full-row canonical JSON hashes were calculated immediately before and after
the live insert. Both stayed identical:

| Historical row | Before SHA-256 | After SHA-256 | State |
|---|---|---|---|
| `9c7700c3-45df-42cc-8476-e37a7ef3adc3` | `38342aa774c20ef583b2cd604459c52f7910c48f376a59209b4e5e0ec8d7b2cd` | `38342aa774c20ef583b2cd604459c52f7910c48f376a59209b4e5e0ec8d7b2cd` | `done/PASS`, updated `2026-05-28T18:04:59.809769Z` |
| `b1adfe17-625c-425d-a1d9-46135f35ae15` | `0fb8fa09f177487b0361c899fa0df66c0e79585e4d8b80820c608c86e5874225` | `0fb8fa09f177487b0361c899fa0df66c0e79585e4d8b80820c608c86e5874225` | `done/PASS`, updated `2026-07-07T21:07:07+00:00` |

## Focused verification

```text
python -m py_compile tools/strategy_farm/farmctl.py
PASS

python -m pytest -q tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_candidate_repair_enqueue.py
41 passed, 4 subtests passed in 12.75s

python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_10440_mql5-ohlc-mtf
PASS; 208 files checked; no findings; max news stale hours 336
```

The tests cover the successful purged-evidence fallback, byte-for-byte
historical-row preservation, purged mismatched-target refusal, retained sibling
evidence refusal, current-binary terminal dedupe, fixed-risk sealing, and
pre-spawn binary drift refusal.

No terminal was started or stopped manually, no active run was interrupted,
and no T_Live or AutoTrading setting was touched.
