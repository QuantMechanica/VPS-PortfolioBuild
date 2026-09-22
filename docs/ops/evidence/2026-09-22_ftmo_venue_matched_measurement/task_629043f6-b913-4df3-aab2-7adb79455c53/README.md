# FTMO/Darwinex venue-cost fidelity — D2g6 matched measurement

- Router task: 629043f6-b913-4df3-aab2-7adb79455c53
- Decision authority: OWNER-DEC-FTMO-FINAL-MEGA-20260921
- Evidence boundary: read-only venue measurement and financed simulation diagnostic
- Verdict: **PARTIAL_MEASURED / REVIEW**
- Measurement window: 2026-09-18T00:00:00Z through 2026-09-22T04:15:00Z

## Decision

The dual-venue collector produced 2,290 unique exact-minute FTMO/Darwinex bid/ask
matches. USDJPY, USDCAD, GBPUSD, and the EURUSD shadow each clear the required
minimum of 60 minutes, three sessions, and nonzero 21Z coverage. XAUUSD has 420
matched minutes over three sessions but both venues were closed during the sampled
21Z window, so its spread charge remains **UNMEASURED**. It is absent from the
numeric spread table; the observed non-21Z delta is not substituted.

Five natural D2g6 FTMO trade deals were recoverable from 2026-09-18 onward. Every
deal has request price, fill price, broker-server and normalized UTC time, symbol,
side, volume, order, position, and magic in the append-only ledger. USDJPY has one
entry and one exit and measures at 0.00 USD/lot round trip. USDCAD has two entries
and one exit and measures at 4.06396828 USD/lot round trip. GBPUSD, XAUUSD, and the
EURUSD shadow have no natural D2g6 deal in the window, so their slippage remains
**UNMEASURED** and is absent from the numeric table.

The financed D2g6 simulation was rerun with only eligible measured values. Its
P_FIRST_NET_FTMO_PAYOUT_LCB is **0.8619**, versus the zero-additional-charge
financed reference of 0.8762, a delta of **-0.0143 (-1.43 percentage points)**.
Unconditional modeled t80 moves from business day 929 to 998, or from diagnostic
calendar day 1300 to 1397: **+69 business days / +97 diagnostic calendar days**.

This is a partial measured-charge sensitivity, not a complete venue-adjusted
headline. XAUUSD spread and GBPUSD/XAUUSD slippage are still unmeasured. The
missing keys receive no incremental simulator charge and are not represented as
measured zeros. No current-state headline was published.

## Exact-minute spread result

The collector takes the first complete bid/ask quote in each real UTC minute after
independently normalizing each venue's broker-wall epoch. Both running terminals
inferred server-minus-UTC = +3 hours. Only the intersection of normalized minute
keys is published to spread_matched.csv.

| Symbol | Matched minutes | Sessions | 21Z minutes | p50 FTMO-DXZ bps | p90 FTMO-DXZ bps | Applied RT bps |
|---|---:|---:|---:|---:|---:|---:|
| USDJPY | 470 | 4 | 50 | -0.25351635 | 0.12762833 | 0.12762833 |
| XAUUSD | 420 | 3 | 0 | -0.11462730 | 0.04603203 | UNMEASURED |
| USDCAD | 456 | 4 | 36 | -0.14293065 | 0.03563808 | 0.03563808 |
| GBPUSD | 470 | 4 | 50 | -0.22456295 | 0.14951706 | 0.14951706 |
| EURUSD shadow | 474 | 4 | 54 | -0.17423120 | 0.14807585 | 0.14807585 |

The charge rule is max(0, p90(FTMO spread bps - Darwinex spread bps)). Eligibility
requires at least 60 exact matched minutes, at least three named sessions, and at
least one 21Z minute. A numeric zero is emitted only when that rule measures a
non-positive p90; it never denotes missing data.

## D2g6 request-to-fill slippage

| Symbol | Deals | Entry / exit | p50 bps | p90 bps | p50 USD/lot | p90 USD/lot | Applied RT USD/lot |
|---|---:|---:|---:|---:|---:|---:|---:|
| USDJPY | 2 | 1 / 1 | 0.00000000 | 0.00000000 | 0.00000000 | 0.00000000 | 0.00000000 |
| USDCAD | 3 | 2 / 1 | 0.21425052 | 0.38533296 | 2.13893068 | 3.85007522 | 4.06396828 |
| GBPUSD | 0 | 0 / 0 | UNMEASURED | UNMEASURED | UNMEASURED | UNMEASURED | UNMEASURED |
| XAUUSD | 0 | 0 / 0 | UNMEASURED | UNMEASURED | UNMEASURED | UNMEASURED | UNMEASURED |
| EURUSD shadow | 0 | 0 / 0 | UNMEASURED | UNMEASURED | UNMEASURED | UNMEASURED | UNMEASURED |

Market-order request price is the executable bid/ask no more than two seconds
before order setup. Pending-order request price is the terminal's native submitted
trigger/limit price. Signed adverse movement is retained in the ledger; the
round-trip simulator charge is max(0, entry p90 USD/lot) plus max(0, exit p90
USD/lot), and requires at least one measured entry and exit.

slippage_daily_summary.json exposes n, p50, and p90 in both bps and USD/lot at:

    symbols.<symbol>.daily_by_utc_hour.<YYYY-MM-DD>.<HH>

## Financed D2g6 rerun

Run contract: financed six-sleeve D2g6 roster; 40,000 block-bootstrap paths; seed
20260921; 20-business-day blocks; 1,008-business-day horizon per stage; the same
fixed 2019-01-22 through 2025-11-21 book window as the reference. The measured
per-symbol JSON files were passed through the simulator's mutually exclusive
per-symbol flags.

| Quantity | Reference | Partial measured charges | Delta |
|---|---:|---:|---:|
| P_FIRST_NET_FTMO_PAYOUT | 0.8913 | 0.8748 | -0.0165 |
| P_FIRST_NET_FTMO_PAYOUT_LCB | 0.8762 | **0.8619** | **-0.0143** |
| P_CHALLENGE_PASS | 0.9565 | 0.9461 | -0.0104 |
| Unconditional t80, business day | 929 | 998 | +69 |
| Unconditional t80, diagnostic calendar day | 1300 | 1397 | +97 |
| t80 LCB | 0.8013 | 0.8003 | -0.0010 |
| Expected progress, USD/business day | 27.503667 | 26.164422 | -1.339245 |

Across the fixed historical window, applied measured spread drag is USD
1,982.993954 and applied measured slippage drag is USD 406.219029. These are
re-costing totals over the source window, not a forecast cash invoice.

Reproduction command:

    python tools/strategy_farm/ftmo/book_sim.py
      --roster docs/ops/evidence/2026-09-21_ftmo_book_sim_v2_financed/d2g6_roster_financed.json
      --financed-streams D:/QM/reports/book_evolution/2026-W38/ftmo/fable_alt_rosters_20260918/deployable2/streams_fin_full/QM/q08_trades
      --financing-manifest D:/QM/reports/book_evolution/2026-W38/ftmo/fable_alt_rosters_20260918/deployable2/manifest_fin_full.json
      --spread-bps-rt-by-symbol spread_bps_rt_by_symbol.json
      --slippage-usd-per-lot-rt-by-symbol slippage_usd_per_lot_rt_by_symbol.json
      --out book_sim_measured_partial.json
      --n-paths 40000 --horizon 1008 --block-len 20 --seed 20260921
      --as-of 2026-09-22T04:15:00Z

book_sim_flags.json binds the exact flag files, coverage state, partial-result
semantics, baseline, and deltas in machine-readable form.

## Read-only collection and cadence

Collection attached sequentially to the already-running, identity-pinned
terminals:

- FTMO PID 11756, login masked as *******732, server FTMO-Demo, build 6182.
- Darwinex PID 10168, login masked as *******541, server Darwinex-Live, build 6182.

The guard requires exactly one process at each configured executable before
attachment and proves that the process set is unchanged after initialization. It
enumerates full process image paths through Win32 and has no optional-package
dependency in the scheduled Python environment. The
collector has no order, terminal-start, terminal-control, or AutoTrading API
surface. Its state records orders_sent=0, terminal_control_actions=0, and
autotrading_touched=false for both venues.

The collector is wired as an observational sidecar into the existing
QM_FTMO_TrialPulse scheduled task. That task already executes the canonical
C:/QM/repo/tools/strategy_farm/ftmo_trial_pulse.py every PT30M. Each pulse requests
a 45-minute overlapping window; append-key deduplication makes repeated collection
idempotent. Collection errors add an observational warning and do not alter
money-control state. No scheduled task, terminal, roster, risk, T_Live, or
AutoTrading setting was changed.

The fixed backfill was executed twice after clock normalization. The second pass,
and the final reporting pass after the summary enhancement, each returned
new_spread_rows=0 and new_slippage_rows=0.

## Evidence and provenance

| Artifact | SHA-256 |
|---|---|
| collector_state.json | 2e563468fb7f9f1546244e7b8514e8c0058cb592f9ae59282399e77488487286 |
| measurements.json | ee5f1f82500edb52533bf4b6e78234921f6051eef197e70d6bd71c83df3c82d2 |
| spread_matched.csv | 449163150e0343f9addc2bdaca52fb49a25e1f4461f4a53f75c81be4ae8f4bbc |
| slippage_ledger.jsonl | cf904963686a564984c73f3160de3f62c579c46a8f4ea84eb90ba5a98812e763 |
| slippage_daily_summary.json | db676a3de25f5b5617c33c6fbe66f7e6a96121e2d6f4c438f96f0de3b1741929 |
| spread_bps_rt_by_symbol.json | 74c69c4f3835ca701ed627aa31da5f510c61a67220e592bfe3085547af62e5c4 |
| slippage_usd_per_lot_rt_by_symbol.json | 72829bca21bb06bb247f41ab3a2a65f747e925e7c787a1c924381eddd54fa288 |
| book_sim_measured_partial.json | a81f65d56c0cc3cfaeaa05bd225fd6ca902d117a1705f4b92305741225b3999f |
| book_sim_flags.json | 98f54e90a4d4f07a413a53681ca34b51832f029a74d6899b4b95fe4ebb9cfaae |
| zero-additional-charge PAYOUT80 reference | fb25ec50555f5b94ce912b4c247ef14b57c371ac63d60c2bacd60d91a00aa708 |

The operational append-only matched-spread ledger remains at
D:/QM/reports/ftmo/venue_matched_measurement/task_629043f6-b913-4df3-aab2-7adb79455c53/v2_clock_normalized/spread_matched.jsonl;
its SHA-256 is c7e8fdeb869a731ec4efcfce700c7e00e62efb4b9ee9bf4bdc2291cc959e4b23.
The committed CSV contains the same 2,290 unique symbol-minute records.

Additional bindings:

- Canonical implementation/evidence tree: 395656a5e211ceee3340a2e26e940e64ffdfe4c9 on agents/board-advisor.
- Financed-stream manifest: 0d4b845c1dc39cb3af09f00a6cd240a0e861b1d1ca74d1cf0e2452573d830633.
- D2g6 roster: 35844a5524f922cf013f970b21d5b5c895d1d2a25b266f937d4696637072aaa1.
- Collector source: 592266adae82dfa122a9d2617dede24579218571a07079c047319fc741285dbd.
- Pulse source: 08fe031ae9c0c92ee5887e6d7b4b58effbfae51e79fab1a2fb788b1aeec0410b.
- Book simulator: d88a3e399dbd40d098b0f0c2faace521ae11edafc612d97d8258412785749ad5.
- First-passage engine: b2c56edf7327f5301eda5d1b5793cecf62466dd0e7db7052503f277af9ef6335.
- Partial-run input manifest: 008836074e85e97a99181d028c848b20fe4d13a1d18f2c7f5a198a662c25a16c.

## Verification

Focused verification:

    python -m pytest -q
      tools/strategy_farm/tests/test_ftmo_venue_matched_collector.py
      tools/strategy_farm/tests/test_ftmo_trial_pulse.py
      tools/strategy_farm/tests/test_ftmo_book_sim.py
      -p no:cacheprovider
    70 passed

    python -m py_compile
      tools/strategy_farm/ftmo/venue_matched_collector.py
      tools/strategy_farm/ftmo_trial_pulse.py
    PASS

CSV/ledger contract check: 2,290 spread rows = 2,290 unique symbol-minute
keys; 5 slippage rows = 5 unique deal tickets; zero rows lack the required
request price, fill, server time, symbol, side, or volume.

The exact Python 3.11 executable configured in QM_FTMO_TrialPulse independently
resolved the pre-existing FTMO/DXZ PIDs as 11756/10168 and completed the fixed
backfill with zero additions. This closes the optional-psutil warning exposed by
the first final-health probe.

## Remaining measurement gaps

- XAUUSD needs qualifying exact matches during the required 21Z session. The
  present closure is recorded as UNMEASURED, not as zero.
- GBPUSD and XAUUSD need natural D2g6 entry and exit fills before a per-symbol
  round-trip slippage charge can be stated.
- EURUSD is a requested shadow comparison but is not a D2g6 roster sleeve.

Until those gaps close, the 0.8619 LCB and +97-day t80 shift are a
partial-measured-cost sensitivity only.
