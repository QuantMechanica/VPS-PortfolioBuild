# Account / Portfolio Governor Dry-Run Evidence

Date: 2026-08-22

Router task: `5c02a347-e91c-44e3-b592-6dad7c6f4d81` (`SP-C1`)

## Verdict

PASS_DRY_RUN — the account-wide reconciliation and staged escalation design is
implemented with a dry-run-only evaluator. Fixture evidence proves that every
position is included independent of magic, account-value leverage and actual
stop loss are computed, stage 2 cannot flatten, and stage 3 requires a separate
hash-bound OWNER emergency policy. The live DD backstop now consumes a fresh
timer-driven account snapshot instead of a 20.6-hour-event-gap-compatible
3,000-minute observation tolerance.

The detailed v2 monitor is source-only and was not compiled, attached, or
deployed. The currently deployed v1 monitor has no detailed inventory arrays,
so the live evaluator correctly fails closed at stage 1. This evidence does not
authorize live cancellation, flattening, sizing, AutoTrading, or monitor
deployment.

## Measured freshness transition

Before the change, the scheduled guard's `2026-08-22T10:45:24Z` record used an
equity observation 2,055.4 minutes old:

```text
OK dd=2.8223% equity=98996.37 hwm=101871.44 threshold=10.00% wrapper_age_min=15.4 equity_age_min=2055.4
```

A manual `--dry-run` against the timer snapshot at `10:47:23Z` measured
`equity=99095.26`, `free_margin=99095.26`, and `snapshot_age_sec=4.5`. Dry-run
did not update state or write a signal.

The next ordinary scheduled invocation completed with result code 0. Its
persisted record at `2026-08-22T10:50:24Z` was:

```text
OK dd=2.7252% equity=99095.26 hwm=101871.44 threshold=10.00% source=account_snapshot snapshot_age_sec=5.2 free_margin=99095.26
```

The resulting guard state bound the correct account (`4000090541`), source
`account_snapshot`, observation `2026-08-22T10:50:19Z`, age `5.204` seconds,
equity/balance/free margin `99095.26`, high-water mark `101871.44`, and DD
`2.7252%`. `breached` remained false and the terminal-local
`portfolio_dd.signal` did not exist. The DD threshold stayed at 10%.

## Staged reconciliation proof

The focused fixture contains three simultaneous positions and two pending
orders:

- ticket 101, registered magic `111320000`;
- ticket 102, manual/unattributed magic `0`;
- ticket 103, deliberately unregistered magic `999`;
- pending tickets 201 and 202 with magics `0` and `999`.

All three positions are recognized. Derived values are gross leverage `1.75`,
net directional leverage `0.75`, planned account-currency loss at stop
`1750.00`, and currency-net buckets EUR `100000`, XAU `-50000`, NDX `25000`,
USD `-75000`.

The staged tests establish:

1. incomplete inventory produces level 1 with entry freeze only;
2. a hash-bound policy breach produces level 2, lists pending tickets 201/202,
   and lists no position for flattening;
3. only a second independently hash-bound, time-limited OWNER emergency policy
   tied to the trigger policy raises the plan to level 3 and lists tickets
   101/102/103;
4. every stage reports `actions_executed: []` and
   `execution_adapter_present: false`; and
5. policy hash mismatch fails closed.

The current live snapshot reported zero open positions and fresh account
values, but is the existing unversioned v1 shape. Running the evaluator against
it produced `ENTRY_FREEZE_UNCERTAINTY`: no positions/orders were presumed, no
threshold was invented, and no cancellation or flattening ticket was listed.
This is the intended boundary until the source-only v2 producer passes its
separate compile/deploy gate.

## Focused verification

Commands and results:

```text
python -m py_compile tools/strategy_farm/account_portfolio_governor.py tools/strategy_farm/live_book_dd_guard.py
PASS

python -m pytest tools/strategy_farm/tests/test_account_portfolio_governor.py tools/strategy_farm/tests/test_live_book_dd_guard.py -q -p no:cacheprovider
13 passed in 1.65s

python tools/strategy_farm/account_portfolio_governor.py --dry-run --expected-login 4000090541 --max-age-seconds 90
exit 0; level 1 ENTRY_FREEZE_UNCERTAINTY; actions_executed=[]

python tools/strategy_farm/live_book_dd_guard.py --dry-run
exit 0; fresh account_snapshot source; no signal write
```

Static monitor assertions verify direct `PositionsTotal` /
`PositionGetTicket` and `OrdersTotal` / `OrderGetTicket` enumeration, absence
of `MagicAllowed` filters, use of `OrderCalcProfit`, and the exact v2 schema.

No MetaTrader compiler or terminal was started. No T1-T10 or T_Live backtest
was interrupted. No live order, sizing, attachment, AutoTrading, or signal-file
mutation was performed.

## Changed files

- `framework/monitor/QM_AccountMonitor.mq5` (v1.10 source only)
- `tools/strategy_farm/account_portfolio_governor.py`
- `tools/strategy_farm/live_book_dd_guard.py`
- `tools/strategy_farm/tests/test_account_portfolio_governor.py`
- `tools/strategy_farm/tests/test_live_book_dd_guard.py`
- `docs/ops/ACCOUNT_PORTFOLIO_GOVERNOR_CONTRACT_2026-08-22.md`

The deployment boundary and policy schemas are normative in the companion
contract document. This artifact remains in REVIEW for Codex/OWNER close-out.
