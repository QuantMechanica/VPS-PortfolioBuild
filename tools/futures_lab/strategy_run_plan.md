# Frozen strategy runner: binding made before economic results

2026-09-22. OWNER-authorized implementation via root; task
`b86d2fbd-574d-4024-af9a-2e48ff84beb9`. This implementation does not approve a
strategy, provider, purchase, payout, G0, or live operation.

The byte-pinned preregistration is
`a91938e318e7ce5948a9b87949ae22b27af1ea3491f3d4723880385d123bea02`.
It contains two hypotheses, five arms, four periods and three scenarios: exactly
60 frozen trial cells. The five arms remain separate; the ES/NQ signal never
provides an executable MES/MNQ stop price. The unused sixth slot is not enabled.

## Pre-economic interpretation bindings

These resolve unspecified mechanics before reading results, without changing
strategy thresholds, arm identities, costs or evaluation criteria.

- Exchange-time buckets are `[minute, minute+60s)`. Last-trade action-T events
  retain receive/sequence/source order; same timestamps and repeated sequence
  numbers are not collapsed when the original record order resolves the tie.
  An arriving event can finalize an earlier bucket only after its own trade has
  been processed. Availability is that receive timestamp, never backdated to a
  nominal close. A trade for an already finalized bucket invalidates the session;
  no hindsight repair, forward-filled empty minute, or late-event deletion.
- A signal may trade only on a later event, at or after its actual availability
  plus the frozen scenario latency. Fresh quotes are required (`max_quote_age=0`),
  so no new staleness tuning parameter is introduced. Entry eligibility must also
  remain strictly before the frozen entry-window end.
- The first five complete minute bars define each instrument's own range.
  Strict ORB close comparisons, one attempt, no reentry. Missing cash minute
  coverage is `DATA_INVALID`; missing trades are not fabricated as flat bars.
- For the failed-break hypothesis, the excursion bar counts as bar one of the
  fifteen. Confirmation on bar fifteen is allowed; expiration consumes the sole
  attempt. No restart from a later excursion. Opposite excursions observed through
  confirmation are ambiguous; future bars cannot retroactively cancel an entry.
  Confirmation must be inside the range, including the required one-tick inset
  on the breached boundary. Stops include the confirming bar's extreme.
- The midpoint target is a marketable exit trigger, including half-tick midpoints;
  it is not a limit order filled merely because a trade touched a target. Stops
  likewise trigger from the executable liquidation side. Both wait the frozen
  latency and use the first later eligible quote with adverse slippage.
- Fixed-$100 sizing projects commissions and both slippage sides for the whole
  quantity. Select the largest affordable integer quantity, capped at two. Sizing
  uses the un-slipped entry quote so entry slippage is charged exactly once.
  Inadequate visible size does not silently change the chosen risk quantity.
- Submit the mandatory flatten at 15:55 New York; it may execute on an eligible
  quote at or after 15:55 plus latency. A position not confirmed flat by 15:59:30
  invalidates the session. No synthetic fill at the stop, midpoint or session close.
- Mark every valid liquidation-side BBO, including the entry event, with full
  round-trip commission and adverse liquidation slippage. Drawdown breaches are
  sticky despite subsequent recovery. All percentages use the frozen $50,000
  research account reference. The runner exposes balance, high watermark and
  sticky halt so a multi-session caller carries them forward.
- Arms and scenarios are separate counterfactual research accounts, each with at
  most one position. Their profits are never summed as an executable portfolio.
  A shared-account arbitration policy is not invented. All selected comparisons
  are retained, including no-signal, missing-data, roll, risk and news rows.
- News includes the boundary of each ±30-minute interval: an event at 09:00 New
  York touches 09:30 and excludes the session; 08:30 NFP alone does not. A refreshed,
  hashed historical extraction may satisfy the 168-hour bundle-age check; the
  historical event date is not falsely interpreted as the extraction timestamp.
  Missing vendor coverage means whole-session exclusion, never an empty calendar.

## Actual implementation and economic boundary

`strategy_runner.py` provides `load_frozen`, `trade_bars`, `FrozenSignal`,
`policy_outcome`, `fixed_risk_size`, `run_session_reference`, and `readiness_plan`.
It consumes `replay_adapter.ReplayEvent` and its side-correct `QuoteGate`. Source
prices are integer billionths; accounting uses Decimal. All schema/contract/time
identities are explicit. Config bytes and its parsed object are hash-pinned.

The executor is a deterministic offline **reference**, not a completed
NautilusTrader 1.221.0 strategy. Synthetic outputs are `MECHANICAL_SYNTHETIC`;
real eligible 2019 inputs are `DEVELOPMENT_REFERENCE_DIAGNOSTIC`. Both keep
`frozen_trial_result_status=NOT_RUN` and `economic_success_certified=false`.
The observed-status June calendar is allowed only for this explicitly limited
reference diagnostic and remains distinct from a complete official holiday
archive. Current news reconstruction is also not a point-in-time archive.

Development tests do not have to wait for April 2027. Only the prospective
holdout is embargoed until 2027-04-01. Provider fee contracts and native live
platform parity are required for later operational claims, not descriptive
development with the three frozen research cost scenarios.

## Minimum scoped data and remaining machine-actionable work

For June 2019 MES development, the raw contracts are MESM9 before the June17
cutover and MESU9 after it; June17 is excluded. ES signal comparison additionally
needs ESM9/ESU9 trade events of matching expiry. MES MBP-1 action-T inputs require
an explicit trade-completeness assumption/proof. Definitions must establish raw
symbols, expiry, multiplier5, tick0.25, USD and availability. MES status must seed
continuous trading before the first quote and cover later transitions. Do not
acquire MNQ/NQ until MES technical checks pass; MES profitability is not that gate.

Use full event MBP-1 for executable micro fills, definitions and status; trade data
for the mini signal. OHLCV alone can support a named bar-screen diagnostic but
cannot substitute for these frozen execution inputs or prove marked-equity risk.
Only dates actually being tested need complete historical calendar/news inputs.
No purchase or dataset acquisition is performed by this runner.

`readiness_plan()` emits concrete requirements for licensed input bindings,
definitions/roll, official sessions, news, event/status ordering, native Nautilus
parity and a pre-result append-only trial ledger. These are not automatically
marked satisfied by a Python boolean. `SessionPolicy` is an internal integration
record for a caller that has verified its upstream evidence, not a public proof
validator or economic certification API.

The June harness records an immutable pre-result plan containing all 20 weekdays
times three MES arms times all three scenarios: 180 session rows. Every selected
raw file, source manifest, calendar/news artifact and implementation source is
hash-bound before any economic result is read. Subsequent execution receipts
never overwrite that plan or a prior result. No bootstrap/validation/holdout PASS
is calculated from this bounded development-month diagnostic.

Before economic execution, independent review found and resolved two implementation
defects: a truncated quote stream could otherwise look like zero-profit NO_SIGNAL,
and an unresolved open position could otherwise return the original balance.
Confirmed-but-unexecutable signals now invalidate the account path; every invalid
path has unknown ending balance and remains blocked on subsequent sessions. Raw
DBN BAD_TS_RECV/MAYBE_BAD_BOOK/SNAPSHOT and unbound flag bits fail signal ingestion;
ES trades-only inputs check trade quality without inventing a BBO.

Dry-run readiness command (exclusive output; new filename required on rerun):

```powershell
& D:\QM\venvs\futures_lab\Scripts\python.exe -B tools/futures_lab/strategy_runner.py --development-day 2019-06-06 --as-of 2026-09-22
```

Tests:

```powershell
& D:\QM\venvs\futures_lab\Scripts\python.exe -B -m unittest discover -s tools/futures_lab -p test_strategy_runner.py -v
```
