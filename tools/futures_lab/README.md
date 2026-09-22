# QuantMechanica Futures Lab

Independent offline preparation lane. Existing MT5 strategy archives, identities and verdicts remain intact. This lab has no account credentials or order connection.

## Installed technical baseline

- Runtime: `D:/QM/venvs/futures_lab/Scripts/python.exe` (CPython 3.11).
- Data and scratch: `D:/QM/futures_lab/`.
- Evidence: `D:/QM/reports/research/futures_pivot_20260922/`.
- Engine: NautilusTrader 1.221.0, pinned specifically for existing Windows/Python 3.11. This is not the newest stable release. Do not mix 2.x documentation with these APIs.
- All 15 dependency wheels are pinned by version and SHA256 in `requirements-win-py311.lock`; installation uses `--only-binary=:all: --require-hashes`.

```powershell
D:/QM/venvs/futures_lab/Scripts/python.exe -m pip check
python -B -m unittest discover -s tools/futures_lab -p test_prop_risk.py -v
```

## Local credential and price quote

After personal Databento registration, open `Set-DatabentoKey.ps1` through the
prepared desktop shortcut under the same Windows user as the research worker
(`qm-admin`). Its masked input stores only a CurrentUser-DPAPI encrypted blob in
`D:/QM/futures_lab/private/databento.dpapi`, outside Git and Drive, with a private
directory ACL. No key belongs in chat, command arguments, or persistent environment
variables. Same-user processes and Windows administrators remain trusted.

`quote_databento.py` is limited to free symbology and metadata methods on the fixed
Databento historical host. It rejects redirects, partial resolution, unknown
prices, malformed counts and breached cost/storage caps. A quote never downloads
data or establishes purchase authorization, credit balance, licensing, or actual
local decoded-data size.

```powershell
python -B tools/futures_lab/quote_databento.py --output D:/QM/reports/research/futures_pivot_20260922/databento_quote_new.json
python -B -m unittest discover -s tools/futures_lab -p 'test_*.py' -v
```

At preparation, 28 checks passed: 10 risk diagnostics, 16 offline metadata-client
tests, and 2 real Windows DPAPI tests using synthetic input. Authenticated requests
remain dependent on the user completing local account/key setup.

## Risk-path diagnostic

`prop_risk.py` processes NET USD balance and marked-to-market equity; closed daily profit alone is insufficient. Session labels must be supplied from the dated provider calendar; timestamps require UTC offsets, and each session must close flat. Invalid or incomplete inputs fail rather than silently inventing missing data.

It tests two independent trail mechanisms, a capped loss floor, a sampled intraday breach, real trade-day markers and a configurable best-day/net-profit ratio. A breach remains recorded after recovery. Micro sizing includes a specified fee and adverse ticks and returns zero when the risk budget cannot fit one contract.

The payout diagnostic distinguishes account debit, cash received after the entered split, external fees and remaining room to an unchanged loss floor. It **does not certify provider payout eligibility**, settlement, legal status, account transitions, commissions or a paid evaluation's rules. The built-in example is explicitly unbound; dated firm-specific contracts are still required.

An evaluation input must end at the chosen evaluation boundary. The diagnostic continues inspecting every supplied point after the first conditions-met timestamp; a later breach yields FAILED for that whole supplied path. Funded-phase transitions require a separately bound profile. Equal timestamps are rejected: an event adapter must retain exchange sequence/equity extrema, never silently drop duplicate-time events.

CSV columns:

```text
timestamp,session,balance,equity,end_of_session,traded,flat
2026-09-01T14:00:00+00:00,2026-09-01,50000,49500,false,true,false
2026-09-01T20:00:00+00:00,2026-09-01,50200,50200,true,true,true
```

Boolean fields are exactly `true` or `false`. Balance and equity must already include commissions and fees; do not subtract them a second time. Currency conversion and taxation are outside this USD diagnostic. No deposits, withdrawals or multi-currency cashflows are allowed inside the evaluation input; inspect proposed payouts separately.

## Economic validation remains separate

Official fixtures and a deliberate one-trade smoke test prove a code path, not an edge. Before a real strategy trial: acquire licensed single-contract MES/MNQ data, hash inputs, freeze contract mapping/rolls/session calendar and fills, bind actual fees, preregister a small candidate set, and simulate the complete evaluation-to-payout path. Verify final signals and order lifecycle on the chosen provider's permitted execution platform.

First candidates should be few: one source-derived cash-session ORB, one deliberately distinct failed-breakout/reversion hypothesis, and matched no-signal controls. Day-flat versions of overnight systems are new hypotheses; do not relabel a Monday-to-Tuesday edge as an unchanged day-trading strategy.

Track prior CFD research as part of selection history. Replaying futures over an
already studied CFD market period is not automatically an untouched market
holdout: the underlying index paths are related. Distinguish a newly held-out
instrument dataset from genuinely unseen market periods and prospective paper
observations.

## Storage

Keep canonical git state outside Google Drive. Avoid downloading a full-exchange MBO history. Request price, record count and byte estimate before each data purchase; process one contract/day at a time. Retain at least the existing 60 GiB Factory reserve on D: and stop new data acquisition if the reserve would be threatened.
