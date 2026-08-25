# QM5_11214 Build Evidence — FX Source Ready, Compile Held

- Build task: `0252ecca-3c52-44e6-93ff-392bb0f97f2f`
- EA: `QM5_11214_ft-clucmay`
- Branch claim: `agents/board-advisor`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11214_ft-clucmay.md`
- MQ5 SHA-256: `a748222740fea5ddeb65cfcc8445359d7345123d0e4ea5c3a393d89a09cb7ea5`
- Outcome: `SOURCE_READY_COMPILE_HELD`

## Diversity selection and claim

The EA was absent from the repository except for its governed pending marker and
had no build task, work item, or active agent-task claim. It was selected from
the build-ready reservoir because its approved basket adds three major FX
instruments (`EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`) while retaining
`XAUUSD.DWX` only as a comparison sleeve. The card has R1–R4 PASS status and an
exact public source file and commit; the other build-ready forex candidate had
higher expected frequency, while the broader mixed-asset candidate carried a
weaker R1 warning.

The farm build task was created and atomically moved to `active` with branch
claim metadata. Its payload records the pre-claim SQLite backup at
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11214_claim_20260825T194633Z.sqlite`.

## Card implementation

The source mechanically implements the approved long-only M5 reversal:

- close below EMA(50) and below `0.985 ×` Bollinger(20, 2) lower band on typical price;
- signal-bar tick volume below 20 times the mean of the preceding 30 closed bars;
- market entry at the next tick with one position per symbol/magic enforced by the framework;
- ATR(14) × 1.5 stop capped to a maximum 5% price distance;
- positive spread capped at 6% of planned stop distance, while zero modeled spread remains valid;
- server-side 1% ROI target plus closed-bar Bollinger-middle recovery exit;
- central two-axis high-impact-news pause and framework Friday close;
- no ML, adaptive inputs, grid, martingale, trailing, pyramiding, or discretionary additions.

Four canonical M5 backtest setfiles were generated for active magic slots 0–3.
Each seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the approved strategy defaults.
Their `build_hash` remains `pending` until a governed compile completes.

## Focused verification

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py --max-news-stale-hours 336`: PASS, five files checked, zero findings.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero violations.
- Setfile contract assertion: PASS for four symbols, fixed risk, and slots 0–3.
- Registry preflight: active EA identity and four active magic rows; every symbol exists in `dwx_symbol_matrix.csv`.
- Forbidden direct-indicator/ML scan: no source findings; the only matches were skeleton comments.
- `git diff --check`: clean for the EA package.

## Compile and capacity boundary

The optional logger resolver was cancelled after it stalled while scanning the
smoke archive; process inspection proved that no `build_check.ps1` child had
started. The actual canonical `build_check.ps1` invocation then exited at its
factory interlock, before source validation or compilation, with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because `terminal64.exe` processes were
active. The contemporaneous `mt5-slots` snapshot showed eight terminal
processes, including governed pipeline work on T3 and T6–T10. No terminal,
AutoTrading setting, live manifest, or portfolio gate was touched.

The sanctioned `farmctl.py enqueue-compile QM5_11214_ft-clucmay` path was then
attempted. Both the initial call and one idempotent retry failed during database
schema verification with `sqlite3.OperationalError: database is locked`. A DB
query between attempts confirmed that no `COMPILE_EA` row existed, so there is
no duplicate or partial queue claim.

No `.ex5` was produced, smoke was not run, and Q02 was not enqueued. This is not
a Q01 PASS or a strategy verdict. The canonical build-result JSON was recorded
successfully; the farm task is now `blocked` with `fail_code=compile_error`, and
there are zero `COMPILE_EA` and zero Q02 work items for `QM5_11214`.

## Required next governed action

After the farm database is writable and compile capacity is admitted, enqueue
one `COMPILE_EA` item bound to the MQ5 hash above. The governed worker must
produce strict compile/build-check PASS evidence and seal the setfile build
hashes before the one-pass smoke, review, and Q02 enqueue can proceed.
