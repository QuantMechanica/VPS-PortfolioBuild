# Terminal reservation at claim time

Date: 2026-07-27  
Router task: `a4cb6cc1-5e42-4a2e-94f9-4544826ecad4`  
Verdict: PASS

## Verified diagnosis

The diagnosis in the task brief was correct.

- The legacy capacity control is `D:\QM\strategy_farm\state\disabled_terminals.txt`, read by `disabled_mt5_terminals()` and applied when computing the terminals that should have workers (`tools/strategy_farm/farmctl.py:285-300`).
- The normal worker claim transaction starts at `claim_atomic()` (`tools/strategy_farm/terminal_worker.py:960`). Before this change it had no check of that file or any expiring reservation state, so an already-running worker could continue claiming from a deep queue.
- This left no safe supported way to hold a terminal after its current item without stopping its worker. No worker or T1-T10 terminal was stopped during this change.

## Mechanism

Reservations are stored atomically in:

`D:\QM\strategy_farm\state\terminal_reservations.json`

An operator creates a reservation with:

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py reserve-terminal T6 --by "<operator>" --minutes 60 --reason "<purpose>"
```

The default is 60 minutes. An operator can release it early with:

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py release-terminal T6
```

The parser and commands are at `tools/strategy_farm/farmctl.py:15568-15575` and
`tools/strategy_farm/farmctl.py:15821-15827`.

The worker still adopts, finishes, or safely releases any item it already owns. Only
after the existing-item handling does it consult the live reservation. A live
reservation returns `claimed=false`, `reason=terminal_reserved`, leaves the pending
row untouched, and emits a flushed JSON event named
`terminal_reservation_claim_declined`
(`tools/strategy_farm/terminal_worker.py:1056-1067`). The worker remains alive and
idles normally.

## Expiry and fail-open behaviour

Each reservation records `reserved_by`, `reason`, `created_at_utc`, and `until_utc`.
Readers ignore expired entries. Malformed, unreadable, or invalid reservation data
returns no live reservations, so claim admission fails open rather than starving the
queue (`tools/strategy_farm/farmctl.py:303-337`). A new write or explicit release
also prunes expired entries. Writes use a same-directory temporary file followed by
an atomic replace.

## Visibility

- `farmctl mt5-slots` now returns `terminal_reservations`, including terminal,
  reserver, purpose, and expiry (`tools/strategy_farm/farmctl.py:12098-12107`).
- The canonical cockpit reads the same state. Reserved idle terminals render as red
  `R` cells, their hover title shows who/until/reason, and the fleet label reports
  the reservation count (`tools/strategy_farm/render_cockpit.py:1937-1963`).
- A terminal that is still completing its current item remains visually active; the
  reservation metadata remains available in `mt5-slots` and takes effect before its
  next claim.

## Focused verification

Executed from `C:\QM\repo` without stopping workers, launching terminals, changing
AutoTrading, or interrupting any backtest:

```text
python -m unittest tools.strategy_farm.tests.test_terminal_worker_atomic_claim
Ran 53 tests in 23.689s
OK

python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/terminal_worker.py tools/strategy_farm/render_cockpit.py
PASS

python tools/strategy_farm/farmctl.py reserve-terminal --help
PASS

python tools/strategy_farm/farmctl.py mt5-slots
PASS; terminal_reservations: []

git diff --check -- <four changed Python files>
PASS
```

The added tests prove that a live reservation declines and logs a claim while leaving
the work item pending, and that an expired reservation is ignored and the item is
claimed normally. The full atomic-claim suite verifies unreserved claim semantics.

