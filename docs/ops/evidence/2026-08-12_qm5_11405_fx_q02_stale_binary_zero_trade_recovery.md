# QM5_11405 FX Q02 stale-binary zero-trade recovery — 2026-08-12

## Outcome

Rebuilt the approved `QM5_11405_carter-tf11-adx-weak-prevday-breakout-h1`
source refresh that had never reached the canonical EX5, sealed all six
RISK_FIXED setfiles to the rebuilt artifact, and append-only enqueued one
EURUSD.DWX H1 Q02 canary.

No strategy threshold, entry/exit rule, risk value, symbol, or timeframe was
changed in this recovery. The historical zero-trade and infrastructure rows
remain unchanged. This is a Q02 handoff, not a claim that the strategy is
trade-capable or qualified.

## Selection and coordination

- Priority 1 was exhausted: every currently approved card already had an EA
  directory.
- The selected priority-2 sleeve is FX, structural, approximately weekly
  (`50` expected trades/year/symbol), and sourced from Thomas Carter's published
  *20 Trend Following Systems* (2014), Strategy #11.
- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11405_carter-tf11-adx-weak-prevday-breakout-h1.md`
  with `g0_status: APPROVED` and R1-R4 PASS.
- Registry identity: EA ID `11405`; six active magic rows for EURUSD, GBPUSD,
  USDJPY, AUDUSD, USDCAD, and USDCHF.
- Farm claim: `144842fb-51cc-41bb-89c1-0c0d19da49d3`, assigned to
  `codex:agents/board-advisor` after an atomic recheck found no active work row
  or competing claim for this EA.
- Pre-claim DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11405_q02_stale_binary_claim_20260812T131510Z.sqlite`.

## Bound failure and first failed layer

The six-symbol Q02 cohort was classified as a shared draft defect after every
enqueued symbol produced zero trades. The exact EURUSD lineage used for this
append-only recovery is:

- predecessor work item: `9ed36345-c357-4bb8-855d-141bf0ddd76a`;
- status/verdict: `done / DRAFT_DEFECT`;
- bound interval: `2022-07-01` through `2022-12-31`;
- symbol/timeframe: `EURUSD.DWX / H1`;
- reason: `Q02_ALL_ENQUEUED_SYMBOLS_ZERO_TRADES`;
- bound MQ5 SHA-256:
  `4bb52c2103a2a50583842f626cd18eaf7d4fb721d3e0e3bc7b30d6ea4d503300`;
- bound EX5 SHA-256:
  `26fa2d71778c26bfdf330785e93035b024caa4fe55f7ff26bd3f36cccf8870a9`;
- bound setfile SHA-256:
  `f1881953257783807102c4875737ca5fd85fac6325542ec0b70cb851017c4348`;
- retained summary:
  `D:\QM\reports\work_items\9ed36345-c357-4bb8-855d-141bf0ddd76a\QM5_11405\20260803_124840\summary.json`;
- retained summary SHA-256:
  `15fa81bdb38c247f1349f69f05288b112f89b82ac5588da34a9f2d74744ae72d`.

An additional exact EURUSD attempt,
`0a9c36d7-2284-4434-be2c-a56f0e369777`, exhausted cold-cache retries with
`NO_HISTORY`. The decisive setup defect for the recovery was artifact drift:
commit `f725241f72fa39582e400a74b011fa4a592c9b09` committed a card-faithful source
refresh after the Q02 cohort, but the canonical 248,018-byte EX5 still predated
that source. Therefore no later run had executed the refreshed implementation.

## Repair and validation

The already committed source refresh was compiled without further MQ5 edits.
The standard strict build gate also replaced each setfile's pending build marker
with its sealed build hash.

- current MQ5 SHA-256:
  `574869f49bb672ecddb7a61afcbc4cfe3ba4e7f556ea6e9171360f8874b61ec4`;
- rebuilt EX5 SHA-256:
  `ae2ad03c0aa544f54a91ecb8831a8aaf2ea1ebe2c4897e69393924960f2c0f8a`;
- rebuilt EX5 size: `373604` bytes;
- EURUSD RISK_FIXED setfile SHA-256:
  `0493732ef3d0288702c92ede91fd8ef7eb3f99c8b34216210ecb5781da68dddf`;
- risk binding: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- `build_check.ps1`: PASS, 0 failures, 0 warnings;
- `compile_one`: PASS, 0 errors, 0 warnings;
- build-check report:
  `D:\QM\reports\framework\21\build_check_20260812_131610.json`;
- compile log:
  `C:\QM\repo\framework\build\compile\20260812_131610\QM5_11405_carter-tf11-adx-weak-prevday-breakout-h1.compile.log`.

The canonical append-only Q02 guard previously accepted repaired
`INFRA_FAIL` and stale `PASS` rows but not a hash-proven repaired
`DRAFT_DEFECT`. The guard now accepts `DRAFT_DEFECT` only through the same
terminal-row, evidence-file, current-artifact hash, fixed-risk, exact-identity,
and deduplication checks. The successor records
`repaired_draft_defect_rerun=true`; it does not relabel the predecessor.

Focused regression result:

```text
python -m pytest tools/strategy_farm/tests/test_candidate_repair_enqueue.py -q
30 passed in 11.26s
```

## Append-only Q02 handoff

- successor work item: `e45eaecd-0530-475d-8795-d6b3b9790a9f`;
- initial state: `pending`;
- exact predecessor: `9ed36345-c357-4bb8-855d-141bf0ddd76a`;
- symbol/timeframe: `EURUSD.DWX / H1`;
- expected EX5 SHA-256:
  `ae2ad03c0aa544f54a91ecb8831a8aaf2ea1ebe2c4897e69393924960f2c0f8a`;
- expected MQ5 SHA-256:
  `574869f49bb672ecddb7a61afcbc4cfe3ba4e7f556ea6e9171360f8874b61ec4`;
- expected setfile SHA-256:
  `0493732ef3d0288702c92ede91fd8ef7eb3f99c8b34216210ecb5781da68dddf`;
- enqueue path: `farmctl.append_only_exact_row_rerun`;
- manual dispatch: not performed.

At the capacity check, T4, T6, and T10 were running factory work. The canary was
left to the paced dispatcher; no local smoke was started. `T_Live` was observed
only by the read-only slot scan and was not touched. AutoTrading, the portfolio
gate, and the live manifest were not touched.

## Zero-trades recovery record

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_11405 | `9ed36345` EURUSD.DWX H1, 2022-07-01..2022-12-31 | Card-faithful source refresh existed only as MQ5; canonical EX5 and run bindings were stale | Strict rebuild, six setfile build seals, guarded append-only DRAFT_DEFECT recovery enqueue | PASS, 0 errors / 0 warnings | Pending Q02 | Pending Q02 | Must produce a valid artifact-bound Q02 report with plausible trades, then pass all later gates including Q04 |

