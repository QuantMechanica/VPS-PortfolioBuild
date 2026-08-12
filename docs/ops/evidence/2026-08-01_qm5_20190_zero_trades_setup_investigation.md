# QM5_20190 Q02 Zero-Trades Setup Investigation

Date: 2026-08-01 (Europe/Berlin)

EA: `QM5_20190_oilbench-cal`

Work item: `ec5fd9b7-8923-498f-a9fd-0a29d8a31d4c`

Classification: `INFRA_FAIL / SETUP_DATA_MISSING`

Observed database verdict: `ZERO_TRADES`

Recovery action: none; no rerun is valid without a venue-tradable Brent route.

## Outcome

The Q02 report is structurally valid, but it cannot evaluate the strategy.
The tester log reports `symbol XBRUSD.DWX does not exist` twice, while the EA
logger records basket warm-up `requested=2`, `loaded=1`, `skipped=1`. The run
therefore stops at the setup layer. Zero trades are not a profitability,
density, or rejection result for the approved mechanic.

The candidate manifest and work-item payload both named the correct two
symbols. The actual defect is the carrier route: the canonical venue model
states that Brent is not in the DXZ `.DWX` universe, and neither
`dwx_symbol_matrix.csv` nor `dwx_symbol_history_ranges.csv` contains
`XBRUSD.DWX`. A local magic row or legacy EA directory did not establish data
availability or live tradability.

No threshold, entry, exit, stop, holding period, symbol, or economic rule was
changed. No manual smoke test, tester launch, or requeue was performed.

## Bound Execution Identity

| Field | Observed value |
|---|---|
| Terminal | non-live `T9` |
| Actual window | `2018.07.02` through `2022.12.31` |
| Host / timeframe | `XTIUSD.DWX` / D1 |
| Model | 4, real-ticks marker present |
| Expert | `QM\\QM5_20190_oilbench-cal` |
| Source/deployed EX5 SHA-256 | `9c6fc99b43cd92f51733692d15a42f25c5aa0cb44399dd23965fd0c212cccbe9`, exact match and stable |
| Run-time MQ5 SHA-256 | `969300b98025ffda6e8248060f4ddac31d83fea86ae6bd4964582e6ce4de5e01` |
| Source/deployed setfile SHA-256 | `d7427282e21cd669e99c2b22c66574c48171a7fd04470a61caec46c03bd04977`, exact match and stable |
| Runner SHA-256 | `c08a5d219aad37135ebc17b477f770fb147dc589f992da8ef27c26acf1a5ef2d` |
| Report | valid HTML, 32,486 bytes, zero trades |
| Initialization | tester initialized; no OnInit failure |

The run used the exact logical-basket setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The work-item payload contained
the manifest path, `basket_symbol_count=2`, and both `XTIUSD.DWX` and
`XBRUSD.DWX`; this rules out a missing manifest leg.

## Layer Classification

### 1. Harness: PASS

- The report exists and is nonempty.
- Model 4 and the real-ticks marker are present.
- The source and deployed EX5 hashes match and stayed stable.
- The source and deployed setfile hashes match and stayed stable.
- The actual tester window, symbol, timeframe, terminal, report, log, and
  runner identity are bound in `summary.json`.

### 2. Setup: FAIL

- Tester log lines 64-65: `symbol XBRUSD.DWX does not exist`.
- EA event `BASKET_WARMUP`: two requested, one loaded, one skipped.
- The logger contains no attempt, signal, entry, order, or trade event.
- `XBRUSD.DWX` is absent from the canonical symbol matrix and history-range
  registry.
- `venue_cost_model.json` explicitly records `dwx_symbol: null`, no DXZ cost
  contract, and an availability gap for Brent.

The first failed layer is therefore `SETUP_DATA_MISSING`. Entry-hook, order,
and economic layers are not reached and must not be interpreted.

There is a second setup concern to resolve with any future route: the host
history begins `2017.10.02`, while this run ends in 2022 and the card requires
at least five prior same-calendar observations. Only the last few decision
months could possibly warm up even if Brent had equivalent history, so the
25-trade Q02 minimum cannot be assumed satisfiable without a deliberately
validated history/window contract.

## Cohort Context

A read-only database query found 42 EAs whose latest Q02 row names Brent
directly or in basket payload. Thirty-eight remain pending; four have terminal
rows, including this candidate. The completed cohort is below the historical
five-member escalation threshold, but the canonical venue declaration and
direct tester reproduction already prove a deterministic shared setup defect.
No bulk queue, registry, or work-item mutation was made.

## Repair Decision

No same-lineage repair is currently available inside the approved execution
contract. A valid Brent recovery would require all of the following before a
rerun:

1. OWNER authorization for a venue-tradable Brent carrier, not merely a
   research-only alias;
2. custom-symbol definition and broker-time/DST validation where applicable;
3. synchronized history that precedes the Q02 decision window by at least the
   five-year minimum;
4. a bound commission, spread, financing, and live symbol-mapping contract;
5. a capacity-safe paced requeue of the unchanged logical basket.

Changing the carrier to XTI alone, XTI/XNG, or another commodity changes the
market hypothesis and requires a new approved card variant. Importing only
historical Brent data would not make the sleeve eligible for the DXZ live book.

## Required Recovery Deliverable

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| `QM5_20190` | T9, Model 4, XTI D1, 2018-07-02 to 2022-12-31, work item `ec5fd9b7-8923-498f-a9fd-0a29d8a31d4c` | `XBRUSD.DWX` absent; basket warm-up loaded 1/2; canonical DXZ route unavailable | None; blocked pending OWNER-authorized tradable Brent route or a new card variant | Q01 strict compile PASS; no post-repair compile because no repair | 0 | 0 | Brent route/history/costs, valid warm-up window, same-contract rerun, then all economic/OOS/correlation gates |

## Evidence Hashes

| Evidence | SHA-256 |
|---|---|
| `summary.json` | `f81f06b433c502d2e5b552815c18cf58e9b7b1bbc9e0a18180789ee9e7e52a20` |
| `logger_sample.jsonl` | `331c817a54052de90cd0dddc7e23ad293c4b6882cc931517c9bd94cbd6e10c85` |
| tester log `20260801.log` | `a687b33627e3cdfb7c9d6524ba79806484d7ebf8d722e1a098c7cf88690fa666` |
| `report.htm` | `26b5dc7043fcbff27d582e03cebcc1a936c5c33db5c0d6f5cd281b34083f15a5` |
| `tester.ini` | `67ab0bc34d28c4083327115a95b2eb03a2b7c2c3cf4a81751ef9f4b6d9031327` |
| `dwx_symbol_matrix.csv` | `e7844d9a18db8723db2b31d839581d0cc348140cf883200524a1af26d465821d` |
| `dwx_symbol_history_ranges.csv` | `9c03b9ece4e741e31559a5e9216a5ab8a5b6929c83ee5acf6d5d440df857c03f` |
| `venue_cost_model.json` | `7dfafe53749e5c45be0cb37568b6e3491c109f546fafaf799f6ea82efdb688d7` |

## Safety Boundary

The database verdict was not relabeled or deleted. No work item was requeued,
no terminal was started or stopped, and no custom symbol was introduced. No
live setfile, AutoTrading toggle, `T_Live` mutation, deploy manifest, T_Live
manifest, portfolio-gate change, portfolio admission, or correlation waiver
was created.
