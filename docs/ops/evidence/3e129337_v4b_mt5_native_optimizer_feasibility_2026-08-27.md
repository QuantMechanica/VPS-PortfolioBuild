# V4b MT5-native optimizer feasibility — preflight stop

**Verdict:** `NOT_REPRODUCIBLE_AS_SPECIFIED`
**Execution:** `NO_MT5_LAUNCH`

The exact commissioned experiment cannot be encoded by the current, hash-bound EA. The fail-closed preflight therefore stopped before creating or launching a terminal profile. T1–T10, T_Live, the queue, and the farm database were untouched.

## Acceptance result

| Criterion | Result |
|---|---|
| Exact prototype protocol/configs | PASS: exact binary-preserving decomposition emitted in the JSON artifact |
| Native pass versus cold receipt | DEVIATION: 0 native passes; 15 authenticated cold receipts inventoried in CSV |
| Feasibility verdict + adapter design | PASS: drop-in replacement rejected; bounded alternative specified |
| Durable evidence | PASS: Markdown + JSON protocol + CSV comparison |

## Why the requested one-input/154-value run has no exact config

The 2019 ledger contains **155** cells: one neutral baseline plus 77 BUY and 77 SELL hypotheses. The current EA exposes six directional inputs (`opt_pp_buy1..3`, `opt_pp_sell1..3`); one input cannot express both directions.

The predicate IDs are also sparse: 3 through 100 contains 98 integer values but only 77 valid predicates. A naive start/step/stop range would run 21 invalid INIT configurations per side.

A new signed `arm_index` input could map 154 values, but compiling it would change the sealed EX5 `d96c7435d66cd16bb8ad778f53abcbb51e81a37628dd29a925208ce4550417d5`. It could no longer be an exact reproduction of the existing cold receipts.

## Exact binary-preserving alternative (not run)

Use slow complete search (`Optimization=1`) in eight jobs, each varying one directional input over one contiguous valid-ID segment, plus one separate baseline. Remote and cloud agents are disabled. The full INI and setfile bytes for every job are embedded in the protocol JSON.

| Job | Input | Range | Passes |
|---|---|---:|---:|
| buy_003_060 | `opt_pp_buy1` | 3..60 step 1 | 58 |
| buy_077_084 | `opt_pp_buy1` | 77..84 step 1 | 8 |
| buy_087_094 | `opt_pp_buy1` | 87..94 step 1 | 8 |
| buy_098_100 | `opt_pp_buy1` | 98..100 step 1 | 3 |
| sell_003_060 | `opt_pp_sell1` | 3..60 step 1 | 58 |
| sell_077_084 | `opt_pp_sell1` | 77..84 step 1 | 8 |
| sell_087_094 | `opt_pp_sell1` | 87..94 step 1 | 8 |
| sell_098_100 | `opt_pp_sell1` | 98..100 step 1 | 3 |

Total: 154 valid optimizer passes + one standalone baseline = 155 configurations. This changes orchestration shape but not strategy mechanics or the binary.

## Cold-reference inventory versus native-pass side

Cold receipts available at snapshot: **15**. Distinct cold EX5 hashes: **1**. Native passes: **0**, because preflight refused the non-representable experiment. The CSV records every cold value/hash and its proposed native job, with native fields explicitly null—never fabricated.

| Cold arm | Trades | PF | Net | Max DD | Native comparison |
|---|---:|---:|---:|---:|---|
| NONE 000 | 37 | 1.14 | 3360.56 | 10001.29 | NOT RUN |
| BUY 003 | 36 | 1.19 | 4386.55 | 8975.3 | NOT RUN |
| BUY 004 | 37 | 1.14 | 3360.56 | 10001.29 | NOT RUN |
| BUY 005 | 37 | 1.14 | 3360.56 | 10001.29 | NOT RUN |
| BUY 006 | 37 | 1.14 | 3360.56 | 10001.29 | NOT RUN |
| BUY 007 | 36 | 1.19 | 4406.43 | 8955.42 | NOT RUN |
| BUY 009 | 36 | 1.19 | 4406.43 | 8955.42 | NOT RUN |
| BUY 010 | 37 | 1.14 | 3360.56 | 10001.29 | NOT RUN |
| BUY 011 | 35 | 1.25 | 5432.42 | 8041.08 | NOT RUN |
| BUY 008 | 37 | 1.14 | 3360.56 | 10001.29 | NOT RUN |
| BUY 012 | 37 | 1.14 | 3360.56 | 10001.29 | NOT RUN |
| BUY 013 | 33 | 1.3 | 6358.73 | 8041.08 | NOT RUN |
| BUY 014 | 37 | 1.14 | 3360.56 | 10001.29 | NOT RUN |
| BUY 015 | 37 | 1.14 | 3360.56 | 10001.29 | NOT RUN |
| BUY 016 | 37 | 1.09 | 2260.18 | 11101.67 | NOT RUN |

## Evidence-adapter design and hard gap

A future reviewed prototype can hash-bind each XML row to: EX5/MQ5/include closure, ledger, exact tester INI, optimization setfile, custom-history manifest, agent allowlist, MT5 build, date/model/seed, direction, predicate ID, and the canonical cell key. The adapter can map aggregate XML columns such as trades, profit, profit factor, drawdown, Sharpe and the optimized input into an append-only candidate receipt.

That is not yet a DL-089 cell receipt. The standard optimization report does not supply a per-pass closed-trade list, entry trading days, the cold HTML report bytes, the authenticated logger sample, or the real-tick marker. `entry_trading_days` is load-bearing for the sealed frequency floor. Cache/XML aggregates therefore cannot replace cold receipts field-for-field.

Closing the gap requires either (a) EA-side frame instrumentation, which changes the binary and demands fresh parity evidence, or (b) individual cold replay of each selected pass, which forfeits most of the claimed 154-cell speedup. A Phase-2 proposal should first choose that governance tradeoff, then wait for at least 20 authenticated cold references before any parity claim.

## Effort estimate for a revised Phase 2

- 0.5–1 day: reviewed disposable-profile launcher, unique agent ports, sealed agent allowlist, cache hygiene and exact-PID/job containment.
- 1–2 days: eight-job XML/cache adapter and append-only candidate receipts.
- 1–2 days: authenticated entry-day/trade-list channel plus tests.
- 1 day after reference availability: ≥20-cell field/trade parity and repeated complete-run determinism check.

## Authoritative MT5 contract used

- [MetaTrader 5 platform-start configuration](https://www.metatrader5.com/en/terminal/help/start_advanced/start) defines `Optimization=1` as slow complete search, `Model=4` as real ticks, XML optimization reports, and the local/remote/cloud switches.
- [MetaTester and remote agents](https://www.metatrader5.com/en/terminal/help/algotrading/metatester) documents agent isolation and the absence of EA Print/trade-operation journal messages on remote agents.
- [MQL5 optimization-report analysis](https://www.mql5.com/en/articles/5436) documents the aggregate XML pass fields and optimized-parameter columns.

## Safety proof

- `launch_performed=false`; refusal: `ONE_INPUT_154_VALUE_CONTRACT_NOT_REPRESENTABLE_BY_CURRENT_BINARY`.
- Database connection: URI `mode=ro` + `PRAGMA query_only=ON`.
- No terminal process was started; no worker, queue, verdict, policy file, T_Live, or AutoTrading state was changed.
- Generated setfiles preserve `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and never raise `qm_news_stale_max_hours` above 336.
