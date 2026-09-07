# Q08.5 `empty_strategy_params` lineage audit

Date: 2026-09-07

Router task: `49f79e94-45f3-4c59-aba8-5ff4297a2e2d`

Requested disposition: `REVIEW`

## Result

The class is a historical producer defect, not a Q08.5 reader misbinding and
not a gate-criterion defect. Before commit `395eb5fc84` (2026-07-19),
`gen_setfile.ps1` wrote `card_defaults_source=not_found` and no explicit
`strategy_*` assignments when it could not find a card. The affected EAs did
declare strategy inputs. MT5 therefore ran the compiled input defaults, while
the stored set artifact did not declare those values.

For every one of the eight rows whose own verdict is the defect:

- the Q08 aggregate binds the fresh baseline trades and the Q08.5 parser to
  the same path and SHA-256;
- that exact Q08 set contains zero strategy assignments at run time;
- the retained Q07 seed-42 artifact also contains zero strategy assignments;
  where the run summary remains retained, its source and deployed hashes match
  and are stable during the run; and
- the Q07/Q08 economic mechanics are behavior-equivalent to the new explicit
  sets because MT5 used the same compiled defaults, but the explicit artifact
  lineage is incomplete and therefore correctly fail-closed at Q08.5.

The two oldest Q07 report trees (`8c0de140` and `32c48193`) have been pruned;
their DB predecessor verdicts and zero-parameter seed artifacts remain. Their
Q08 aggregates retain the exact baseline identities and 235/113-trade runs.
No evidence supports a tester-export or neighborhood-reader path mismatch.

The reported “18 rows” comprises eight actual INVALID verdicts and ten rows
whose append-only rerun reason references the defect. It is not 18 new empty
sets. The sealed census and all row-level fields are in
`lineage_audit.json`.

## Per-row disposition

| Row | EA | Symbol | Q08 baseline set | SHA-256 | Params | Trades | Row result | Cause / action |
|---|---|---|---|---:|---:|---:|---|---|
| `8c0de140` | QM5_10287 | XAUUSD.DWX | `QM5_10287_cinar-ichimoku_XAUUSD.DWX_D1_backtest.set` | `bec3bf990052` | 0 | 235 | INVALID | Historical empty set; successor `5901ae3b` is already PENDING with 6 params. Do not duplicate. |
| `32c48193` | QM5_1230 | XAUUSD.DWX | `QM5_1230_carver-dynvol-mav_XAUUSD.DWX_D1_backtest.set` | `2fe1b2581e42` | 0 | 113 | INVALID | Historical empty set; successor `b429d45f` completed FAIL_SOFT with 10 params. |
| `02cf605e` | QM5_11179 | USDJPY.DWX | `QM5_11179_ft001-ema-ha_USDJPY.DWX_M5_backtest.set` | `7ef786c24e0c` | 0 | 594 | INVALID | Historical empty set; successor `40a802ca` completed FAIL_SOFT with 10 params. |
| `40a802ca` | QM5_11179 | USDJPY.DWX | same canonical name, repaired bytes | `ca173ee6a443` | 10 | 594 | FAIL_SOFT | Reference-only mention of the prior defect; own baseline is full. |
| `1da1645c` | QM5_10148 | EURNZD.DWX | `QM5_10148_tii-signal_EURNZD.DWX_D1_backtest.set` | `ffe0a57e4a6f` | 6 | 29 | PASS | Reference-only rerun; own baseline is full. |
| `5901ae3b` | QM5_10287 | XAUUSD.DWX | repaired canonical set | `c258e8dec51d` | 6 | - | PENDING | Existing replacement rerun; do not duplicate. |
| `ee8b7d55` | QM5_10771 | USDJPY.DWX | repaired canonical set | `276dcd73ead1` | 13 | 281 | FAIL_SOFT | Reference-only rerun; own baseline is full. |
| `49b55905` | QM5_10771 | XAUUSD.DWX | repaired canonical set | `d5accd9bb905` | 13 | 283 | FAIL_SOFT | Reference-only rerun; own baseline is full. |
| `c8d8c2c7` | QM5_10848 | GDAXI.DWX | repaired canonical set | `91062aeb4013` | 12 | - | PENDING | Existing replacement rerun; do not duplicate. |
| `169d5dda` | QM5_11132 | NDX.DWX | repaired canonical set | `f5abdb8a1fa2` | 9 | - | PENDING | Existing replacement rerun; do not duplicate. |
| `b429d45f` | QM5_1230 | XAUUSD.DWX | repaired canonical set | `9f62953bcf96` | 10 | 113 | FAIL_SOFT | Reference-only rerun; own baseline is full. |
| `7aaf7760` | QM5_9573 | NDX.DWX | repaired canonical set | `5ee58f6fc883` | 10 | - | PENDING | Existing replacement rerun; do not duplicate. |
| `8646a920` | QM5_9573 | USDCHF.DWX | repaired canonical set | `8211a6582630` | 10 | 169 | FAIL_SOFT | Reference-only rerun; own baseline is full. |
| `b280892a` | QM5_11196 | XAUUSD.DWX | historical canonical set | `1b0a80e1cf9c` | 0 | 656 | INVALID | First empty baseline; its first rerun addressed DSR declaration but reused the empty file. |
| `60f98a58` | QM5_11015 | EURUSD.DWX | historical canonical bytes | `72e9a371f800` | 0 | 122 | INVALID | Successor `34d0e1ba` used 11 explicit params; it ended INFRA_FAIL for the separate `q08_degenerate_neighborhood_baseline` class. No duplicate empty-set rerun. |
| `906b7644` | QM5_11179 | XAUUSD.DWX | historical canonical set | `a9503fe8a40e` | 0 | 753 | INVALID | New governed replacement prepared; append-only command requires review. |
| `a79887e3` | QM5_11196 | XAUUSD.DWX | historical canonical set | `1b0a80e1cf9c` | 0 | 656 | INVALID | Successor `9ec3b856` used governed set `7cc424d2...` and completed PASS. |
| `2cdb6a16` | QM5_10928 | XAUUSD.DWX | historical canonical set | `6a148b04f660` | 0 | 39 | INVALID | New governed replacement prepared; append-only command requires review. |

## Producer repair

The July fallback already prevents a missing card from producing a new empty
set when the EA exposes `strategy_*` inputs. This change closes the remaining
producer contract explicitly:

- any environment now throws
  `SETFILE_DECLARED_STRATEGY_PARAMS_MISSING` before writing when declared
  strategy inputs would materialize as zero assignments (the earlier guard
  covered only LIVE);
- optional `-VersionTag` accepts only `sYYYYMMDD-NNN`, creates that governed
  versioned filename, and
  refuses to overwrite an existing version; and
- the unchanged LIVE-specific zero-parameter guard still protects genuinely
  parameterless live output. Q08.5 thresholds and verdict logic are untouched.

Two create-only outputs were produced by the governed generator:

| EA | Replacement | Strategy params | SHA-256 |
|---|---|---:|---|
| QM5_11179/XAUUSD | `framework/EAs/QM5_11179_ft001-ema-ha/sets/QM5_11179_ft001-ema-ha_XAUUSD.DWX_M5_backtest_s20260907-001.set` | 10 | `2feb770d23934ee4e2bec219350577e7119cb15a7dbd19d702c7789379493484` |
| QM5_10928/XAUUSD | `framework/EAs/QM5_10928_grimes-yoyo-break/sets/QM5_10928_grimes-yoyo-break_XAUUSD.DWX_M30_backtest_s20260907-001.set` | 14 | `b11f79a849689ba642e0d94b42d7fea1f45640be958c31c531ef05fff648f8e5` |

Path-specific `.gitattributes -text` rules preserve their byte identity. The
historical canonical files and all existing work-item verdicts remain
unchanged.

## Review-only commands

`rerun_commands.ps1` contains exactly two ready-to-run
`farmctl enqueue-backtest --append-only-rerun-of ... --replacement-setfile`
commands. They target `906b7644` and `2cdb6a16`, cite the exact Q07 PASS
predecessors, and pin the current EX5 hashes. The file was syntax-parsed and
both replacement bindings passed the farm controller's validator. It was not
executed. A replacement resolves only the empty-parameter lineage defect; it
does not pre-judge DSR or any other Q08 sub-gate.

## Verification

- `python tools/strategy_farm/audit_q08_empty_strategy_params.py --output .../lineage_audit.json`: 18 sealed rows, 8 own INVALID verdicts, 10 references, 2 prepared/not enqueued.
- `python -m pytest tools/strategy_farm/tests/test_gen_setfile.py -q`: 11 passed.
- Generator replay: both versioned sets contain exactly the source-declared
  strategy inputs (10/10 and 14/14); a repeated versioned write is rejected.
- `_replacement_setfile_binding(...)`: PASS for both set/path/header/hash
  identities.
- PowerShell parser: `rerun_commands.ps1` has zero syntax errors.
- LF/byte checks and scoped `git diff --check`: PASS (recorded at commit).

No production enqueue, terminal process, scheduler, `T_Live`, AutoTrading,
registry file, stored verdict, or historical set was changed.
