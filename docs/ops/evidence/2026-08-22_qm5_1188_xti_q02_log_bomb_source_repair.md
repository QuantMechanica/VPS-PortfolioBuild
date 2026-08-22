# QM5_1188 XTI Q02 log-bomb source repair

## Outcome

`QM5_1188_qp-oil-negshock-rebound` has a same-lineage implementation repair for
its XTI Q02 log bomb. The approved D1 negative-shock rebound mechanic is
unchanged. Static build gates pass, but the repaired source is **not Q02-ready**
because the live-factory compile policy does not currently authorize replacing
this EA's existing bound binary. No stale-binary Q02 row was enqueued.

This was the highest-value structural diversity repair available after the
approved build backlog was screened. The card frontmatter is `g0_status:
APPROVED` with R1-R4 `PASS`, cites the named Quantpedia source lineage
`7ede58dd-d184-5099-9d48-7a65de230853`, and defines a deterministic D1 oil-shock
reversal with no ML, grid, martingale, averaging, or adaptive thresholds.

## Coordination

- active repair task: `72386dac-85bf-4d8a-9677-f3a308b7eed9`
- claim key: `QM5_1188:XTIUSD.DWX:Q02_LOG_BOMB_IMPLEMENTATION_REPAIR`
- branch: `agents/board-advisor`
- canonical farm DB quick check before the claim: `ok`
- open QM5_1188 work items at claim: `0`
- competing active QM5_1188 agent tasks at claim: `0`

Two screened candidates were released without repository changes before this
claim: the first QM5_1188 claim stopped at the governed force-rebuild gate, and
QM5_12538 was rejected because its indicator-stack construction was weaker than
the mission's structural-only preference.

## Bound failure

The immutable source row is
`1b17085a-0620-44a5-9ef1-623a6eed7a67` (`Q02`, `INFRA_FAIL`). Its retained
summary is:

`D:/QM/reports/work_items/1b17085a-0620-44a5-9ef1-623a6eed7a67/QM5_1188/20260728_174907/summary.json`

The T4 real-tick/model-4 run requested `2018.07.02` through `2022.12.31` on
`XTIUSD.DWX` D1. It was killed after the tester journal reached 14.51 GB, above
the 4 GB safety cap. The report was zero bytes, `oninit_failure_detected=false`,
and the terminal verdict was `LOG_BOMB;INCOMPLETE_RUNS`, so this is an
infrastructure/setup failure rather than strategy evidence.

Original bound identity:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `048891ef1246dbd59e64ed7d82ac05ff9d9a1c7bfcc784218ec24446adf2c1cd` |
| EX5 | `fa84f80b84756ffeb6df0fd56d1ea3d55bb42cd10626780e84b5c731946d6885` |
| XTI backtest set | `602d669479b5441ba38f59c74596fe37cb381f48d4ab057fefe6caea5b202875` |

## First failed layer and root cause

The first failed layer is the setup symbol route. The EA treated the preferred
WTI route and alternate Brent route as mandatory basket legs:

1. `Strategy_NoTradeFilter()` called `Strategy_SelectSymbols()` on every XTI
   tick.
2. `Strategy_SelectSymbols()` selected both `XTIUSD.DWX` and `XBRUSD.DWX`.
3. `XTIUSD.DWX` is present in `dwx_symbol_matrix.csv` and has D1 history for
   2017-2025 on T1-T10. `XBRUSD.DWX` is absent from both the symbol matrix and
   history-range registry.
4. The unavailable alternate therefore blocked the valid XTI route and caused
   an unbounded unknown-symbol journal stream on every real tick.

This is the same deterministic implementation class already repaired in the
neighboring independent oil-proxy EAs. It does not require changing the card's
market hypothesis or signal economics.

## Repair

- Initialization now resolves and selects only the active chart symbol.
- The per-tick no-trade filter no longer selects the unavailable alternate.
- XTI and XBR remain independent card routes with their existing magic slots;
  neither registry row was changed.
- D1 strategy series work and the D1 hold exit now run behind the existing
  framework new-bar gate. The EA has no intrabar strategy management, so this
  preserves its behavior while bounding series access.
- The current explicit `QM_FrameworkTrackOpenPositionMae()` lifecycle hook runs
  before any `OnTick()` early return.

No shock threshold, ATR percentile, stop, hold period, position sizing, symbol
universe, setfile parameter, live template, or registry value changed.

## Verification and compile disposition

- `git diff --check`: PASS
- `build_gate_hardening.py`: PASS, one MQ5 scanned, zero failures/warnings
- `validate_build_guardrails.py`: PASS, six files checked, zero findings
- repaired MQ5 SHA-256:
  `9463ee9b20752e1cedc774e3b554058c338641cfd2ff05f2b00cbca11ed63cb9`
- retained EX5 SHA-256:
  `fa84f80b84756ffeb6df0fd56d1ea3d55bb42cd10626780e84b5c731946d6885`
- retained fixed-risk XTI set SHA-256:
  `602d669479b5441ba38f59c74596fe37cb381f48d4ab057fefe6caea5b202875`

`build_check.ps1` correctly refused an ad-hoc compile while live factory
terminals were running and directed the work to `farmctl enqueue-compile`.
The governed enqueue then refused this existing identity with exactly:

- `EX5_ALREADY_PRESENT`
- `WORK_ITEMS_EXIST`
- `BOUND_SETFILE_HASH_EXISTS`
- `force_rebuild_authorized=false`

`farmctl compile-status` reports `NOT_ENQUEUED`. This is a governance hold, not
a compiler finding. The capacity check showed two managed testers active (below
the seven-tester ceiling); no terminal or tester was launched, stopped, or
restarted.

Because the repaired MQ5 and retained EX5 now intentionally differ, the
zero-trades recovery contract forbids rerunning the old binary. No compile PASS,
trade-capable claim, Q02 PASS, or strategy verdict is asserted.

## Required governed continuation

1. Grant a scoped existing-identity force-rebuild authority for `QM5_1188` that
   the COMPILE_EA classifier recognizes; do not bypass the classifier.
2. Enqueue and consume the compile through:

   ```powershell
   python tools/strategy_farm/farmctl.py enqueue-compile QM5_1188_qp-oil-negshock-rebound
   ```

3. Require strict compile/build-check PASS and bind the new EX5 plus the fixed
   risk XTI setfile.
4. Append one authenticated rerun of the immutable failed row:

   ```powershell
   python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_1188 --phase Q02 --append-only-rerun-of 1b17085a-0620-44a5-9ef1-623a6eed7a67 --rerun-reason "same-lineage XTI symbol-route log-bomb repair; current governed binary" --expected-current-ex5-sha256 <NEW_EX5_SHA256>
   ```

## Recovery table

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
| --- | --- | --- | --- | --- | ---: | ---: | --- |
| QM5_1188 / XTI D1 | `1b17085a-...` | Per-tick selection of absent independent XBR alternate caused a 14.51 GB log bomb and blocked XTI | Current-symbol-only initialization, bounded D1 path, explicit MAE hook | Governed force-rebuild authorization required; not enqueued | Not observable; report absent | Not observable; report absent | Compile, exact artifact binding, authenticated Q02 rerun, then all downstream empirical gates |

No T_Live file, AutoTrading state, portfolio gate, deploy manifest, or live
manifest was touched.
