# QM5_20292 FX carry-unwind stale-binary recovery and CPU stop

Date: 2026-08-18 Europe/Berlin  
Branch: `agents/board-advisor`  
Farm claim: `39f7a994-e3ca-42f5-bc5b-9125b71d04cc`

## Outcome

`QM5_20292_fx-carry-unwind` received a source-preserving strict rebuild after
the second Q02 attempt paired the repaired MQ5 with the unchanged original
EX5. The current binary therefore contains both the already-reviewed host-leg
trade-manager repair and the current framework's corrected W1 calendar key.

No Q02 successor was enqueued and no tester was launched. The immediate
capacity check measured `99, 100, 100, 100, 100` percent CPU (99.8% average,
100% peak) with T1, T2, T4, T5, T6, and T9 running governed tests. The G0
authorization and paced-fleet mission both require a stop at that ceiling.
This artifact is rebuilt and reproducible, but it is not claimed to trade,
pass Q02, or be ready for a deeper gate.

## Selection and collision control

The refreshed approved-card backlog contained no buildable low-frequency
diversity card with preallocated active magic rows; the available fresh rows
were either already owned, non-diverse, or mechanically unsuitable. The
genuine diverse Q02-Q03 infrastructure census then resolved to this six-cross
FX basket: it has an OWNER-approved Tier-A source, six registered magics, no
economic verdict or deeper phase, no open work item, and no competing task.

The farm claim was acquired under
`manual:codex:agents/board-advisor:QM5_20292:q02-stale-binary-zero-trades-recovery:20260817T225054Z`
after an atomic collision recheck. Its consistent pre-claim backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20292_q02_stale_binary_claim_20260817T225054Z.sqlite`

`PRAGMA quick_check` returned `ok` for that backup.

## Bound zero-trade evidence

Both immutable Q02 summaries describe `AUDCHF.DWX`, D1, Model 4, one run over
2018-07-02 through 2022-12-31. Both had a real-tick marker, completed cleanly,
passed OnInit, and reported zero trades with `MIN_TRADES_NOT_MET`.

| Work item | Summary SHA-256 | MQ5 SHA-256 | EX5 SHA-256 | Setfile SHA-256 | Result |
|---|---|---|---|---|---|
| `774accb9-8957-44df-9da8-156134610f74` | `8478fcb7e42af7d6ea645d9827574f852663769c3dee4d3ad2a417e2e22ce511` | `57857e1bb6b4718cb85da48c6eefef0137508d8d3e85b1b519712a639c464407` | `504702992f2fa36617c9a2de24923aab9366bb7f989183907dfada33bbf92c1c` | `31907eecc45e419393c92ee0ba765d0fcf473ed86e428987835aad27ee7ff279` | `DRAFT_DEFECT`, 0 trades |
| `e0afb922-fa1f-4b39-ab6f-ec7c6b757d5d` | `9687296ae99f37471a0591058abcd0e6d476a7424922283490c004c96af64ffe` | `845f638d46b66968705f6ee4226d28fd078f699f96425551b0536f4c39481199` | `504702992f2fa36617c9a2de24923aab9366bb7f989183907dfada33bbf92c1c` | `fcaac8c0208b540bfaf3f9e62390cbd379db87598fadb8f2257b3752d23abb92` | `DRAFT_DEFECT`, 0 trades |

The second row's MQ5 is the current source created by commit
`25131422ac72c5437df7c276acb3df735e488a15` (`fix(qm): route QM5_20292 host
leg through TM`), but its EX5 is byte-for-byte the original August 12 binary.
That commit did not contain an EX5. The second Q02 run therefore could not have
executed the source identity it recorded. This is an artifact/setup defect and
is sufficient to invalidate that zero-trade result as evidence about the
repaired implementation.

The evidence does not establish that stale identity was the sole cause of all
zero trades. The structured logger contains initialization, warm-up, equity,
and Friday-close events but no authenticated entry-attempt or order event.
Signal reachability and order acceptance remain unmeasured.

## Minimal repair

- Strategy MQ5 is unchanged at
  `845f638d46b66968705f6ee4226d28fd078f699f96425551b0536f4c39481199`.
- Strictly rebuilt EX5 changed from 388,244 bytes / `50470299...` to 413,056
  bytes / `614d5b7adb051a4d1a51acbbd78b733ad8ccfcb6fa56aa78835de471a4eb9e6c`.
- The build checker refreshed only the generated `build_hash` header in the
  six leg setfiles and the logical basket setfile. The logical RISK_FIXED
  setfile is now
  `8a1cee7c2c76d9dfde076227459bcec07b12138c8ff03bf8c637be95d6ce3d8d`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, D1 cadence,
  thresholds, selected legs, stops, exits, symbol universe, and news axes are
  unchanged. No strategy mechanic was relaxed.

## Verification

- `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings. Compile log:
  `C:\QM\repo\framework\build\compile\20260817_225256\QM5_20292_fx-carry-unwind.compile.log`
  (SHA-256 `222c25b4e10984339896d0f47f751cc6f0393e8d1238bc6e764161582e850c41`).
- `validate_spec_doc.py`: PASS, 1/1.
- `validate_build_guardrails.py`: PASS, no findings.
- `build_check.ps1 -SkipCompile`: PASS, 0 failures and four reviewed static
  advisories; report
  `D:\QM\reports\framework\21\build_check_20260817_225416.json`
  (SHA-256 `95f3c1380b2a7864c47b1e93df1579e82fd905203108ad55a7b7f0b6704b8540`).
- Calendar-key, magic-resolver binary-search, and host-slot magic static tests:
  13 passed.
- The generic symbol-scope check reports the seven signal-only majors as not
  present in `basket_symbols`. They are explicitly declared in the manifest's
  `signal_symbols`, and the bound run logged `BASKET_WARMUP` with all seven
  loaded. No new symbol reference or manifest edit was made in this repair.

One build advisory remains an important proof gap rather than a permitted code
change: the approved rule fails closed when fewer than two targets expose
comparable positive swap metadata. The repository's swap baseline still marks
the target runtime snapshot as pending. A read-only DEV1 metadata probe timed
out before returning values; the terminal started by that probe was stopped,
and no order or tester run occurred. Removing the swap gate or inventing static
carry directions would change the authorized mechanics and is explicitly
forbidden. The next governed Q02 run must therefore establish both runtime
metadata viability and actual entry density.

## Zero-trade recovery disposition

| EA | Bound run | First proven defect | Repair | Compile | Entry events | Trades | Remaining gap |
|---|---|---|---|---|---:|---:|---|
| `QM5_20292` | `e0afb922-fa1f-4b39-ab6f-ec7c6b757d5d`, AUDCHF.DWX D1, 2018-07-02..2022-12-31 | Setup/artifact identity: post-fix MQ5 recorded beside unchanged pre-fix EX5 | Source-preserving strict rebuild against current framework; generated set hashes refreshed | PASS, 0/0 | Not authenticated in predecessor; no new run allowed at CPU ceiling | 0 in predecessor; no new run | Fresh append-only logical Q02, runtime swap-metadata proof, entry/order evidence, then economics and Q04 |

## Safety boundary

No T_Live path, AutoTrading state, portfolio gate, deploy manifest, live
manifest, portfolio admission, or unrelated EA was touched. No tester terminal
was manually dispatched or stopped. The compile helper performed its standard
include sync to configured non-live compile targets; the isolated DEV1 process
launched by the read-only metadata probe was terminated after its timeout.
